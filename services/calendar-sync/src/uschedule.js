const BASE = "https://beta.uschedule.com/api/loftgolfstudios";
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
 * Gets an auth token by impersonating a user via the app key — no password needed.
 * @param {string} email  e.g. "booking@loftgolfstudios.com"
 * @returns {Promise<string>} AuthKey
 */
async function impersonate(email) {
  const data = await _post("impersonateuser", { FieldName: "username", Value: email });
  if (!data?.AuthKey) throw new Error("uSchedule impersonate response missing AuthKey");
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

module.exports = { impersonate, fetchAppointments };
