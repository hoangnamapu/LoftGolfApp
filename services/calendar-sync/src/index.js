const express = require("express");
const {
  port,
  syncKey,
  bay1CalendarId,
  bay2CalendarId,
  timeZone,
  uscheduleImpersonateEmail,
} = require("./config");

const { getMapping, setMapping, deleteMapping } = require("./store");
const { toEvent, createEvent, patchEvent, deleteEvent } = require("./gcal");
const { impersonate } = require("./uschedule");
const { startReminder, runReminderOnce } = require("./reminder");

const app = express();
app.use(express.json({ limit: "1mb" }));

function requireKey(req, res, next) {
  const key = req.header("x-sync-key");
  if (!key || key !== syncKey) {
    return res.status(401).json({ error: "unauthorized" });
  }
  next();
}

function calendarForBay(bay) {
  if (String(bay) === "1") return bay1CalendarId;
  if (String(bay) === "2") {
    if (!bay2CalendarId) {
      throw new Error("Bay 2 is not configured (BAY2_CALENDAR_ID not set)");
    }
    return bay2CalendarId;
  }
  throw new Error(`Unknown bay: ${bay}`);
}

/**
 * Core sync logic shared by the POST endpoint and the poller.
 * Idempotent: safe to call multiple times with the same booking data.
 */
async function syncBooking(booking) {
  const calendarId = calendarForBay(booking.bay);
  const appointmentId = String(booking.id);
  const existing = await getMapping(appointmentId);

  if (String(booking.status).toUpperCase() === "CANCELED") {
    if (existing?.eventId) {
      await deleteEvent(existing.calendarId, existing.eventId);
    }
    await deleteMapping(appointmentId);
    return { action: "cancel", appointmentId };
  }

  const eventBody = toEvent(booking, timeZone);

  if (!existing?.eventId) {
    const created = await createEvent(calendarId, eventBody);
    await setMapping(appointmentId, { calendarId, eventId: created.id });
    return { action: "create", appointmentId, eventId: created.id };
  } else if (existing.calendarId !== calendarId) {
    // Bay changed — delete the event from the old calendar and create in the new one
    await deleteEvent(existing.calendarId, existing.eventId);
    const created = await createEvent(calendarId, eventBody);
    await setMapping(appointmentId, { calendarId, eventId: created.id });
    console.log(
      `[sync] appointment ${appointmentId} moved from calendar ${existing.calendarId} to ${calendarId}`
    );
    return { action: "move", appointmentId, eventId: created.id };
  } else {
    const updated = await patchEvent(
      existing.calendarId,
      existing.eventId,
      eventBody
    );
    await setMapping(appointmentId, {
      calendarId: existing.calendarId,
      eventId: existing.eventId,
    });
    return { action: "update", appointmentId, eventId: updated.id };
  }
}

app.get("/health", (_, res) => res.json({ ok: true }));

/**
 * Manual override endpoint — still fully functional.
 * booking payload: { id, bay, startISO, endISO, customerName?, notes?, status }
 */
app.post("/sync/uschedule", requireKey, async (req, res) => {
  try {
    const booking = req.body;

    if (!booking?.id || !booking?.bay || !booking?.startISO || !booking?.endISO) {
      return res.status(400).json({ error: "missing required fields" });
    }

    const result = await syncBooking(booking);
    return res.json({ ok: true, ...result });
  } catch (err) {
    console.error(err);
    return res.status(500).json({
      error: "server_error",
      detail: String(err.message || err),
    });
  }
});

/**
 * Reminder endpoint for Cloud Scheduler.
 *
 * Recommended production flow:
 * Cloud Scheduler calls this endpoint every 1 minute.
 *
 * Required header:
 * x-sync-key: same value as SYNC_KEY
 */
app.post("/tasks/reminders", requireKey, async (req, res) => {
  try {
    const authKey = await impersonate(uscheduleImpersonateEmail);
    await runReminderOnce(authKey);

    return res.json({
      ok: true,
      action: "reminder_check_completed",
    });
  } catch (err) {
    console.error("[reminder] task endpoint error:", err.message || err);

    return res.status(500).json({
      ok: false,
      error: "reminder_task_failed",
      detail: String(err.message || err),
    });
  }
});

app.listen(port, () => {
  console.log(`calendar-sync listening on ${port}`);

  const { startPoller } = require("./poller");

  // Single shared auth token with promise lock — ensures only one
  // impersonateuser call is in flight at a time even when poller and
  // reminder both call getAuthKey() simultaneously on startup.
  let sharedAuthKey = null;
  let authKeyPromise = null;

  async function getAuthKey() {
    if (sharedAuthKey) return sharedAuthKey;
    if (!authKeyPromise) {
      authKeyPromise = impersonate(uscheduleImpersonateEmail)
        .then(key => {
          sharedAuthKey = key;
          authKeyPromise = null;
          console.log("[auth] authenticated with uSchedule");
          return key;
        })
        .catch(err => {
          authKeyPromise = null;
          throw err;
        });
    }
    return authKeyPromise;
  }

  function clearAuthKey() {
    sharedAuthKey = null;
    authKeyPromise = null;
  }

  startPoller(syncBooking, getAuthKey, clearAuthKey);
  startReminder(getAuthKey);
});