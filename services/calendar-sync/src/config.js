function must(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

module.exports = {
  port: process.env.PORT || 8080,
  syncKey: must("SYNC_API_KEY"),
  bay1CalendarId: must("BAY1_CALENDAR_ID"),
  bay2CalendarId: must("BAY2_CALENDAR_ID"),
  timeZone: process.env.TIME_ZONE || "America/Phoenix",
  firestoreCollection: process.env.FIRESTORE_COLLECTION || "bookingEventMap"
};
