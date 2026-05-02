const { google } = require("googleapis");

const SCOPES = ["https://www.googleapis.com/auth/calendar"];

async function getCalendarClient() {
  const auth = new google.auth.GoogleAuth({ scopes: SCOPES });
  const authClient = await auth.getClient();
  return google.calendar({ version: "v3", auth: authClient });
}

function toEvent(booking, timeZone) {
  // booking: { id, bay, startISO, endISO, customerName, notes, status }
  const appointmentId = String(booking.id);

  return {
    summary: `${booking.customerName || "Customer"}`,
    description: [
      `Loft-managed booking`,
      `uSchedule appointmentId: ${appointmentId}`,
      booking.notes ? `Notes: ${booking.notes}` : null
    ].filter(Boolean).join("\n"),
    start: { dateTime: booking.startISO, timeZone },
    end: { dateTime: booking.endISO, timeZone },
    extendedProperties: {
      private: {
        loftSyncManaged: "true",
        uscheduleAppointmentId: appointmentId,
        bay: String(booking.bay)
      }
    }
  };
}

async function createEvent(calendarId, event) {
  const cal = await getCalendarClient();
  const res = await cal.events.insert({ calendarId, requestBody: event });
  return res.data; // includes id
}

async function patchEvent(calendarId, eventId, eventPatch) {
  const cal = await getCalendarClient();
  const res = await cal.events.patch({
    calendarId,
    eventId,
    requestBody: eventPatch
  });
  return res.data;
}

async function deleteEvent(calendarId, eventId) {
  const cal = await getCalendarClient();
  await cal.events.delete({ calendarId, eventId });
}

module.exports = { toEvent, createEvent, patchEvent, deleteEvent };
