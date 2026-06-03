const BASE = "https://clients.uschedule.com/api/loftgolfstudios";
const APP_KEY = "c9af66c8-7e45-41f8-a00e-8324df5d3036";

async function _post(path, body, authKey) {
  const headers = {
    "Content-Type": "application/json",
    "X-US-Application-Key": APP_KEY,
  };
  if (authKey) headers["X-US-AuthToken"] = authKey;

  const res = await fetch(`${BASE}/${path}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });

  if (res.status === 401) {
    const body = await res.text().catch(() => "");
    const err = new Error(`uSchedule 401 Unauthorized (${path}): ${body}`);
    err.status = 401;
    throw err;
  }
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`uSchedule ${path} HTTP ${res.status}: ${text}`);
  }
  return res.json();
}

/**
 * Gets an auth token by logging in with username and password.
 * @param {string} username
 * @param {string} password
 * @returns {Promise<string>} AuthKey
 */
async function login(username, password) {
  const data = await _post("validateuser", { UserName: username, Password: password });
  if (!data?.AuthKey) throw new Error("uSchedule validateuser response missing AuthKey");
  return data.AuthKey;
}

/**
 * Fetches all appointments for a date range using the admin API endpoint.
 * @param {string} authKey
 * @param {string} startDate  "MM/DD/YYYY"
 * @param {string} endDate    "MM/DD/YYYY"
 * @returns {Promise<object[]>}
 */
async function fetchAppointments(authKey, startDate, endDate) {
  const data = await _post("getapiappointments", { StartDate: startDate, EndDate: endDate }, authKey);
  return Array.isArray(data) ? data : [];
}

/**
 * Fetches the FREE (bookable) slots for a resource unit on a given day.
 *
 * uSchedule's getapiappointments cannot tell us whether an appointment was
 * cancelled (cancelled records are returned identically to active ones with
 * StatusID 0). getavailability does reflect cancellations: a cancelled slot
 * becomes bookable again. So a slot appearing here means there is no active
 * booking on that unit/time — any synced events there are stale.
 *
 * @param {string} authKey
 * @param {object} opts
 * @param {number} opts.locationId
 * @param {number} opts.resourceUnitId
 * @param {number} opts.serviceId
 * @param {string} opts.startDateISO   e.g. "2026-06-09T00:00:00"
 * @param {number} opts.serviceLength  minutes
 * @returns {Promise<object[]>} array of free slots: [{ StartTime, ResourceUnitID, ... }]
 */
async function fetchAvailability(authKey, { locationId, resourceUnitId, serviceId, startDateISO, serviceLength }) {
  const data = await _post(
    "getavailability",
    {
      LocationID: locationId,
      ResourceUnitID: resourceUnitId,
      ServiceID: serviceId,
      StartDate: startDateISO,
      ServiceLength: serviceLength,
    },
    authKey
  );
  return Array.isArray(data) ? data : [];
}

module.exports = { login, fetchAppointments, fetchAvailability };
