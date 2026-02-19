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
  if (String(bay) === "2") return bay2CalendarId;
  throw new Error(`Unknown bay: ${bay}`);
}

app.get("/health", (_, res) => res.json({ ok: true }));

/**
 * booking payload example:
 * {
 *   "id": "12345",
 *   "bay": 1,
 *   "startISO": "2026-02-19T15:00:00-07:00",
 *   "endISO": "2026-02-19T16:00:00-07:00",
 *   "customerName": "Test Customer",
 *   "notes": "Sprint 7 test",
 *   "status": "ACTIVE" // or "CANCELED"
 * }
 */
app.post("/sync/uschedule", requireKey, async (req, res) => {
  try {
    const booking = req.body;
    if (!booking?.id || !booking?.bay || !booking?.startISO || !booking?.endISO) {
      return res.status(400).json({ error: "missing required fields" });
    }

    const calendarId = calendarForBay(booking.bay);
    const appointmentId = String(booking.id);

    const existing = await getMapping(appointmentId);

    // Cancel flow
    if (String(booking.status).toUpperCase() === "CANCELED") {
      if (existing?.eventId) {
        await deleteEvent(existing.calendarId, existing.eventId);
      }
      await deleteMapping(appointmentId);
      return res.json({ ok: true, action: "cancel", appointmentId });
    }

    // Create or update
    const eventBody = toEvent(booking, timeZone);

    if (!existing?.eventId) {
      const created = await createEvent(calendarId, eventBody);
      await setMapping(appointmentId, {
        calendarId,
        eventId: created.id
      });
      return res.json({ ok: true, action: "create", appointmentId, eventId: created.id });
    } else {
      // If bay changed, you can choose to move events; for MVP we’ll just patch in place
      const updated = await patchEvent(existing.calendarId, existing.eventId, eventBody);
      await setMapping(appointmentId, {
        calendarId: existing.calendarId,
        eventId: existing.eventId
      });
      return res.json({ ok: true, action: "update", appointmentId, eventId: updated.id });
    }
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "server_error", detail: String(err.message || err) });
  }
});

app.listen(port, () => console.log(`calendar-sync listening on ${port}`));
