const { fetchAppointments, fetchAvailability } = require("./uschedule");
const { getSnapshot, setSnapshot, deleteSnapshot, listSnapshotIds } = require("./store");
const {
  pollIntervalMs,
  uscheduleLocationId,
  uscheduleServiceId,
  uscheduleServiceLengthMin,
} = require("./config");

// StatusIDs from uSchedule (kept for booking payload shape).
const STATUS_CANCELED = [9, 10]; // canceled, rescheduled

// Cancellation detection.
// getapiappointments cannot tell active from cancelled (StatusID is always 0 on
// production and cancelled records are returned identically to active ones). So
// we use getavailability as the source of truth: if an appointment's slot shows
// as FREE/bookable, there is no active booking there and any synced event is stale.
// Times are compared as raw "YYYY-MM-DD" / "HH:mm" string slices to avoid timezone
// drift (uSchedule returns local times without an offset).
function dayKey(startTime) {
  return typeof startTime === "string" ? startTime.slice(0, 10) : null;
}
function hourKey(startTime) {
  return typeof startTime === "string" ? startTime.slice(11, 16) : null;
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
      // leave key unset -> isActive() returns true (assume active, never delete)
    }
  }
  return freeByUnitDay;
}

/**
 * Active = the appointment's slot is NOT free. If we have no availability data
 * for the slot (closed day, past date, or a failed fetch) we assume active so we
 * never delete an event we can't positively confirm was cancelled.
 */
function isActive(appt, freeByUnitDay) {
  if (appt.ResourceUnitID == null || !appt.StartTime) return true;
  const free = freeByUnitDay.get(`${appt.ResourceUnitID}|${dayKey(appt.StartTime)}`);
  if (!free) return true;
  return !free.has(hourKey(appt.StartTime));
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

async function runOnce(authKey, syncBooking) {
  const now = new Date();
  const start = new Date(now);
  start.setDate(start.getDate() - 1);
  const end = new Date(now);
  end.setDate(end.getDate() + 60);

  const appointments = await fetchAppointments(authKey, formatLocalDate(start), formatLocalDate(end));

  const bayAppointments = appointments.filter((a) => bayForAppointment(a) !== null);
  const seenIds = new Set(bayAppointments.map((a) => String(a.AppointmentID)));

  // Source of truth for active vs cancelled (see buildFreeSlotMap).
  const freeByUnitDay = await buildFreeSlotMap(authKey, bayAppointments);

  // Process each appointment from the API
  for (const appt of bayAppointments) {
    try {
      const bay = bayForAppointment(appt);
      const fp = fingerprint(appt);
      const snapshot = await getSnapshot(appt.AppointmentID);
      const active = isActive(appt, freeByUnitDay);

      if (!active) {
        // Cancelled — the slot is bookable again. Remove the event if we synced it.
        if (snapshot) {
          await syncBooking({
            id: String(appt.AppointmentID),
            bay,
            startISO: appt.StartTime,
            endISO: appt.EndTime,
            status: "CANCELED",
          });
          await deleteSnapshot(appt.AppointmentID);
          console.log(`[poller] removed cancelled appointment ${appt.AppointmentID} (slot free)`);
        }
        // Never synced and already cancelled — nothing to do.
      } else if (!snapshot) {
        // New active appointment
        await syncBooking(appointmentToBooking(appt, bay));
        await setSnapshot(appt.AppointmentID, { ...appt, fingerprint: fp });
        console.log(`[poller] created event for appointment ${appt.AppointmentID}`);
      } else if (snapshot.fingerprint === fp) {
        // No change — skip
      } else {
        // Active and details changed — update
        await syncBooking(appointmentToBooking(appt, bay));
        await setSnapshot(appt.AppointmentID, { ...appt, fingerprint: fp });
        console.log(`[poller] updated event for appointment ${appt.AppointmentID}`);
      }
    } catch (err) {
      console.error(`[poller] error processing appointment ${appt.AppointmentID}:`, err.message || err);
    }
  }

  // Cancel anything in Firestore that disappeared from the API response
  const knownIds = await listSnapshotIds();
  for (const id of knownIds) {
    if (!seenIds.has(id)) {
      try {
        const snapshot = await getSnapshot(id);
        if (snapshot) {
          const bay = bayForAppointment(snapshot);
          if (bay !== null) {
            await syncBooking({ id, bay, startISO: snapshot.StartTime, endISO: snapshot.EndTime, status: "CANCELED" });
          }
          await deleteSnapshot(id);
          console.log(`[poller] removed disappeared appointment ${id} from calendar`);
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
