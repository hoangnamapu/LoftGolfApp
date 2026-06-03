function must(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

module.exports = {
  port: process.env.PORT || 8080,
  syncKey: must("SYNC_API_KEY"),
  bay1CalendarId: must("BAY1_CALENDAR_ID"),
  bay2CalendarId: process.env.BAY2_CALENDAR_ID || null,
  timeZone: process.env.TIME_ZONE || "America/Phoenix",
  firestoreCollection: process.env.FIRESTORE_COLLECTION || "bookingEventMap",
  uscheduleUsername: must("USCHEDULE_IMPERSONATE_EMAIL"),
  uschedulePassword: must("USCHEDULE_PASSWORD"),
  // Account-level IDs for the getavailability cancellation check (stable per account).
  uscheduleLocationId: Number(process.env.USCHEDULE_LOCATION_ID || 11274),
  uscheduleServiceId: Number(process.env.USCHEDULE_SERVICE_ID || 35371),
  uscheduleServiceLengthMin: Number(process.env.USCHEDULE_SERVICE_LENGTH || 60),
  pollIntervalMs: Number(process.env.POLL_INTERVAL_MS || 60_000),
  snapshotCollection: process.env.SNAPSHOT_COLLECTION || "appointmentSnapshots",
};
