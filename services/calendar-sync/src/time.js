const ARIZONA_TIME_ZONE = "America/Phoenix";

/**
 * Parse a uSchedule time string as Arizona time.
 *
 * uSchedule may return times without timezone info:
 * Example: "2026-05-09T13:30:00"
 *
 * Cloud Run usually runs in UTC. If Node parses that string directly,
 * it may treat it as server-local time instead of Arizona time.
 *
 * Arizona does not observe daylight saving time, so UTC-7 is stable.
 */
function parseArizonaTime(str) {
  if (!str) return null;

  let value = String(str).trim();

  // If the string already contains timezone info, do not modify it.
  const hasTimezone =
    value.endsWith("Z") || /[+-]\d{2}:\d{2}$/.test(value);

  if (!hasTimezone) {
    value = value + "-07:00";
  }

  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

module.exports = { ARIZONA_TIME_ZONE, parseArizonaTime };
