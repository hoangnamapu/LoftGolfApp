function must(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var: ${name}`);
  return v;
}

// "5523:35371,5524:42215" -> { 5523: 35371, 5524: 42215 }
function parseUnitServiceMap(raw) {
  const map = {};
  for (const pair of raw.split(",")) {
    const [unit, service] = pair.split(":").map((s) => Number(s.trim()));
    if (unit && service) map[unit] = service;
  }
  return map;
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
  // getavailability returns an EMPTY list when the ServiceID is not offered on
  // the resource unit, which makes that bay blind to cancellations. Each unit
  // must be queried with a service it actually offers: Bay 1 (5523) offers
  // 35371, Bay 2 "Golf Only" (5524) offers only 42215.
  uscheduleUnitServiceIds: parseUnitServiceMap(
    process.env.USCHEDULE_UNIT_SERVICE_MAP || "5523:35371,5524:42215"
  ),
  // uSchedule creates the appointment record the moment a customer starts
  // checkout and blocks the slot; the cart times out after 5 min if the
  // transaction is abandoned. Don't sync records younger than this grace
  // period so abandoned carts free their slot and get tombstoned first.
  holdGraceMin: Number(process.env.HOLD_GRACE_MIN || 10),
  // ...except bookings starting within this window go on the fast path so
  // door automations still fire for real walk-ins.
  urgentWindowMin: Number(process.env.URGENT_WINDOW_MIN || 30),
  // Even urgent bookings wait until the record outlives the 5-min cart
  // timeout, so an abandoned checkout never syncs ("sync at minute 6").
  urgentMinAgeMin: Number(process.env.URGENT_MIN_AGE_MIN || 6),
  pollIntervalMs: Number(process.env.POLL_INTERVAL_MS || 60_000),
  snapshotCollection: process.env.SNAPSHOT_COLLECTION || "appointmentSnapshots",
};
