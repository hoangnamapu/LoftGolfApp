const { fetchAppointments, fetchAvailability } = require("./uschedule");
const { getSnapshot, setSnapshot, deleteSnapshot, listSnapshotIds } = require("./store");
const { parseArizonaTime } = require("./time");
const {
  pollIntervalMs,
  uscheduleLocationId,
  uscheduleServiceId,
  uscheduleServiceLengthMin,
  holdGraceMin,
  urgentWindowMin,
} = require("./config");

// StatusIDs from uSchedule (kept for booking payload shape).
const STATUS_CANCELED = [9, 10]; // canceled, rescheduled

// ---- Cancellation detection ----
//
// getapiappointments cannot tell active from cancelled: StatusID is always 0
// on production, cancelled records are returned identically to active ones,
// and dead records stay in the response forever. uSchedule also creates the
// appointment record the moment a customer STARTS checkout (blocking the slot
// for ~15 min), so records exist for transactions that were never completed.
//
// We therefore derive per-record life state from three signals:
//   1. getavailability — a FREE slot means no active booking is there
//      (confirmed over 2 consecutive ticks before acting, since a single
//      flaky response must not permanently delete a real booking);
//   2. overlap dedupe — a bay holds one live booking at a time, so among
//      overlapping records only the newest CreatedDate can be live;
//   3. tombstones — once a record is deemed dead its snapshot is kept with
//      syncState "cancelled" so it can never be re-created, even when its
//      slot later reads occupied again (someone else's hold or re-booking,
//      or the slot aging into availability's blind window).
//
// Times are compared as raw "YYYY-MM-DD" / "HH:mm" string slices to avoid
// timezone drift (uSchedule returns local times without an offset).

function dayKey(startTime) {
  return typeof startTime === "string" ? startTime.slice(0, 10) : null;
}
function hourKey(startTime) {
  return typeof startTime === "string" ? startTime.slice(11, 16) : null;
}

function isTombstoned(snapshot) {
  return Boolean(snapshot?.syncState && snapshot.syncState !== "active");
}

/**
 * For every (ResourceUnitID, day) pair that has appointments, fetch the free
 * slots once and return Map<"unitId|YYYY-MM-DD", Set<"HH:mm">>.
 */
async function buildFreeSlotMap(authKey, appts) {
  const pairs = new Map();
  for (const a of appts) {
    if (a.ResourceUnitID == null || !a.StartTime) continue;
    const day = dayKey(a.StartTime);
    const key = `${a.ResourceUnitID}|${day}`;
    if (!pairs.has(key)) pairs.set(key, { unitId: a.ResourceUnitID, day });
  }

  const freeByUnitDay = new Map();
  for (const [key, { unitId, day }] of pairs) {
    try {
      const slots = await fetchAvailability(authKey, {
        locationId: uscheduleLocationId,
        resourceUnitId: unitId,
        serviceId: uscheduleServiceId,
        startDateISO: `${day}T00:00:00`,
        serviceLength: uscheduleServiceLengthMin,
      });
      const free = new Set();
      for (const s of slots) {
        if (s && typeof s.StartTime === "string" && dayKey(s.StartTime) === day) {
          free.add(hourKey(s.StartTime));
        }
      }
      freeByUnitDay.set(key, free);
    } catch (err) {
      if (err.status === 401) throw err; // let the poller re-authenticate
      console.error(`[poller] availability fetch failed for ${key}:`, err.message || err);
      // leave key unset -> slot unverifiable -> assume occupied, never delete
    }
  }
  return freeByUnitDay;
}

/**
 * True only when availability POSITIVELY reports the slot as bookable.
 * Missing data (past slots, same-day lead-time cutoff, failed fetch) returns
 * false so we never delete an event we can't confirm was cancelled.
 */
function isSlotFree(appt, freeByUnitDay) {
  if (appt.ResourceUnitID == null || !appt.StartTime) return false;
  const free = freeByUnitDay.get(`${appt.ResourceUnitID}|${dayKey(appt.StartTime)}`);
  if (!free) return false;
  return free.has(hourKey(appt.StartTime));
}

// Raw string comparison is safe: uSchedule timestamps share one local format.
function overlaps(a, b) {
  if (!a.StartTime || !a.EndTime || !b.StartTime || !b.EndTime) return false;
  return a.StartTime < b.EndTime && b.StartTime < a.EndTime;
}

function isNewer(a, b) {
  const ac = a.CreatedDate || "";
  const bc = b.CreatedDate || "";
  if (ac !== bc) return ac > bc;
  return Number(a.AppointmentID) > Number(b.AppointmentID);
}

/**
 * A bay can hold only one live booking at a time, so among records that
 * overlap on the same unit only the newest can be live — a newer record can
 * only exist because the older one died (cancelled or abandoned checkout).
 * Returns the Set of superseded (dead) AppointmentIDs as strings.
 */
function findSupersededIds(appts) {
  const superseded = new Set();
  const byUnit = new Map();
  for (const a of appts) {
    if (a.ResourceUnitID == null) continue;
    if (!byUnit.has(a.ResourceUnitID)) byUnit.set(a.ResourceUnitID, []);
    byUnit.get(a.ResourceUnitID).push(a);
  }
  for (const list of byUnit.values()) {
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        if (!overlaps(a, b)) continue;
        const dead = isNewer(a, b) ? b : a;
        superseded.add(String(dead.AppointmentID));
      }
    }
  }
  return superseded;
}

function bayForAppointment(appt) {
  const name = appt.ResourceName || "";
  if (name.includes("Bay 1")) return 1;
  if (name.includes("Bay 2")) return 2;
  return null;
}

function fingerprint(appt) {
  return JSON.stringify({
    StatusID: appt.StatusID,
    StartTime: appt.StartTime ?? null,
    EndTime: appt.EndTime ?? null,
    ResourceName: appt.ResourceName ?? null,
    Description: appt.Description ?? null,
  });
}

function appointmentToBooking(appt, bay) {
  const isCanceled = STATUS_CANCELED.includes(appt.StatusID);
  return {
    id: String(appt.AppointmentID),
    bay,
    startISO: appt.StartTime,
    endISO: appt.EndTime,
    customerName: appt.CustomerName ?? null,
    notes: appt.Description ?? null,
    status: isCanceled ? "CANCELED" : "ACTIVE",
  };
}

// uSchedule getapiappointments expects "MM/DD/YYYY"
function formatLocalDate(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(date.getMonth() + 1)}/${pad(date.getDate())}/${date.getFullYear()}`;
}

/**
 * Remove the calendar event (no-op if none was ever created) and keep the
 * snapshot as a tombstone so the record can never be re-created.
 */
async function cancelAndTombstone(appt, bay, syncBooking, reason) {
  const id = appt.AppointmentID;
  await syncBooking({
    id: String(id),
    bay,
    startISO: appt.StartTime,
    endISO: appt.EndTime,
    status: "CANCELED",
  });
  await setSnapshot(id, {
    ...appt,
    syncState: "cancelled",
    cancelledAt: new Date().toISOString(),
    pendingCancelTicks: 0,
  });
  console.log(`[poller] removed appointment ${id} — ${reason}`);
}

async function runOnce(authKey, syncBooking) {
  const now = new Date();
  const start = new Date(now);
  start.setDate(start.getDate() - 1);
  const end = new Date(now);
  end.setDate(end.getDate() + 60);

  const appointments = await fetchAppointments(authKey, formatLocalDate(start), formatLocalDate(end));

  const bayAppointments = appointments.filter((a) => bayForAppointment(a) !== null);
  const seenIds = new Set(bayAppointments.map((a) => String(a.AppointmentID)));

  const superseded = findSupersededIds(bayAppointments);
  const freeByUnitDay = await buildFreeSlotMap(authKey, bayAppointments);

  for (const appt of bayAppointments) {
    try {
      const id = appt.AppointmentID;
      const bay = bayForAppointment(appt);
      const snapshot = await getSnapshot(id);

      // Dead records stay dead — no resurrection, no further writes.
      if (isTombstoned(snapshot)) continue;

      // Deterministic death: a newer overlapping record exists on this bay.
      if (superseded.has(String(id))) {
        await cancelAndTombstone(appt, bay, syncBooking, "superseded by newer record");
        continue;
      }

      // Availability-based death: require 2 consecutive free readings so one
      // flaky response can't permanently delete a real booking.
      if (isSlotFree(appt, freeByUnitDay)) {
        const pending = (snapshot?.pendingCancelTicks || 0) + 1;
        if (pending >= 2) {
          await cancelAndTombstone(appt, bay, syncBooking, "slot free (confirmed)");
        } else {
          await setSnapshot(id, { ...appt, pendingCancelTicks: pending });
          console.log(`[poller] slot free for appointment ${id} — awaiting confirmation`);
        }
        continue;
      }

      // Slot occupied (or unverifiable) — record presumed live.
      if (snapshot?.pendingCancelTicks) {
        await setSnapshot(id, { ...snapshot, pendingCancelTicks: 0 });
      }

      const fp = fingerprint(appt);
      const hasEvent = Boolean(snapshot?.fingerprint);

      if (!hasEvent) {
        const startTime = parseArizonaTime(appt.StartTime);
        const createdTime = parseArizonaTime(appt.CreatedDate);

        // Slots already underway or past are operationally useless to sync
        // and are the main stuck-phantom vector (availability can no longer
        // report them free). Tombstone so we stop re-evaluating every tick.
        if (startTime && startTime.getTime() <= now.getTime()) {
          await setSnapshot(id, {
            ...appt,
            syncState: "expired_unsynced",
            pendingCancelTicks: 0,
          });
          console.log(`[poller] skipping appointment ${id} — start time already passed, never synced`);
          continue;
        }

        // Imminent bookings sync immediately so door automations fire for
        // real walk-ins, accepting rare last-minute phantoms.
        const urgent =
          startTime && startTime.getTime() - now.getTime() <= urgentWindowMin * 60_000;

        // Otherwise wait out uSchedule's checkout hold: abandoned
        // transactions free their slot within ~15 min and get tombstoned
        // above without an event ever being created.
        if (
          !urgent &&
          createdTime &&
          now.getTime() - createdTime.getTime() < holdGraceMin * 60_000
        ) {
          console.log(`[poller] deferring appointment ${id} — within checkout-hold grace period`);
          continue;
        }

        await syncBooking(appointmentToBooking(appt, bay));
        await setSnapshot(id, {
          ...appt,
          fingerprint: fp,
          syncState: "active",
          pendingCancelTicks: 0,
        });
        console.log(`[poller] created event for appointment ${id}${urgent ? " (urgent)" : ""}`);
      } else if (snapshot.fingerprint === fp) {
        // No change — skip
      } else {
        await syncBooking(appointmentToBooking(appt, bay));
        await setSnapshot(id, {
          ...appt,
          fingerprint: fp,
          syncState: "active",
          pendingCancelTicks: 0,
        });
        console.log(`[poller] updated event for appointment ${id}`);
      }
    } catch (err) {
      console.error(`[poller] error processing appointment ${appt.AppointmentID}:`, err.message || err);
    }
  }

  // Snapshots whose records left the API window: remove any live event, then
  // drop the doc (this is also how tombstones are eventually garbage-collected).
  const knownIds = await listSnapshotIds();
  for (const id of knownIds) {
    if (!seenIds.has(id)) {
      try {
        const snapshot = await getSnapshot(id);
        if (snapshot) {
          if (!isTombstoned(snapshot)) {
            const bay = bayForAppointment(snapshot);
            if (bay !== null) {
              await syncBooking({ id, bay, startISO: snapshot.StartTime, endISO: snapshot.EndTime, status: "CANCELED" });
            }
            console.log(`[poller] removed disappeared appointment ${id} from calendar`);
          }
          await deleteSnapshot(id);
        }
      } catch (err) {
        console.error(`[poller] error removing disappeared appointment ${id}:`, err.message || err);
      }
    }
  }

  console.log(`[poller] tick complete — checked ${bayAppointments.length} appointments`);
}

function startPoller(syncBooking, getAuthKey, clearAuthKey) {
  async function tick() {
    try {
      const authKey = await getAuthKey();
      await runOnce(authKey, syncBooking);
    } catch (err) {
      if (err.status === 401) {
        console.warn("[poller] 401 error, re-authenticating next tick:", err.message);
        clearAuthKey();
      } else {
        console.error("[poller] tick error:", err.message || err);
      }
    }
    setTimeout(tick, pollIntervalMs);
  }

  // Start immediately on boot
  tick();
}

module.exports = { startPoller };
