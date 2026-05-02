const { impersonate, fetchAppointments } = require("./uschedule");
const { getSnapshot, setSnapshot, deleteSnapshot, listSnapshotIds } = require("./store");
const { uscheduleImpersonateEmail, pollIntervalMs } = require("./config");

// Active StatusIDs from uSchedule
const STATUS_ACTIVE = 1;
const STATUS_CANCELED = [9, 10]; // canceled, rescheduled

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

  // Process each appointment from the API
  for (const appt of bayAppointments) {
    try {
      const bay = bayForAppointment(appt);
      const fp = fingerprint(appt);
      const snapshot = await getSnapshot(appt.AppointmentID);

      if (!snapshot) {
        // New appointment
        if (appt.StatusID === STATUS_ACTIVE) {
          await syncBooking(appointmentToBooking(appt, bay));
          await setSnapshot(appt.AppointmentID, { ...appt, fingerprint: fp });
          console.log(`[poller] created event for appointment ${appt.AppointmentID}`);
        }
        // If already canceled on first sight, nothing to do
      } else if (snapshot.fingerprint === fp) {
        // No change — skip
      } else {
        // Something changed
        if (STATUS_CANCELED.includes(appt.StatusID)) {
          await syncBooking(appointmentToBooking(appt, bay));
          await deleteSnapshot(appt.AppointmentID);
          console.log(`[poller] canceled event for appointment ${appt.AppointmentID}`);
        } else {
          await syncBooking(appointmentToBooking(appt, bay));
          await setSnapshot(appt.AppointmentID, { ...appt, fingerprint: fp });
          console.log(`[poller] updated event for appointment ${appt.AppointmentID}`);
        }
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

function startPoller(syncBooking) {
  let authKey = null;

  async function tick() {
    try {
      if (!authKey) {
        authKey = await impersonate(uscheduleImpersonateEmail);
        console.log("[poller] authenticated with uSchedule");
      }
      await runOnce(authKey, syncBooking);
    } catch (err) {
      if (err.status === 401) {
        console.warn("[poller] 401 error, re-authenticating next tick:", err.message);
        authKey = null;
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
