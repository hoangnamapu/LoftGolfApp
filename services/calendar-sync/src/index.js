const express = require("express");
const { port, syncKey, bay1CalendarId, bay2CalendarId, timeZone } = require("./config");
const { getMapping, setMapping, deleteMapping } = require("./store");
const { toEvent, createEvent, patchEvent, deleteEvent } = require("./gcal");

const app = express();
app.use(express.json({ limit: "1mb" }));

function requireKey(req, res, next) {
  const key = req.header("x-sync-key");
  if (!key || key !== syncKey) return res.status(401).json({ error: "unauthorized" });
  next();
}

function calendarForBay(bay) {
  if (String(bay) === "1") return bay1CalendarId;
  if (String(bay) === "2") {
    if (!bay2CalendarId) throw new Error("Bay 2 is not configured (BAY2_CALENDAR_ID not set)");
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
  } else {
    const updated = await patchEvent(existing.calendarId, existing.eventId, eventBody);
    await setMapping(appointmentId, { calendarId: existing.calendarId, eventId: existing.eventId });
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
    return res.status(500).json({ error: "server_error", detail: String(err.message || err) });
  }
});

app.listen(port, () => {
  console.log(`calendar-sync listening on ${port}`);
  const { startPoller } = require("./poller");
  startPoller(syncBooking);
});
