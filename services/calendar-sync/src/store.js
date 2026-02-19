// In-memory mapping for local smoke tests (no Firestore needed).
// Note: mapping resets if the server restarts.

const map = new Map();

async function getMapping(appointmentId) {
  return map.get(String(appointmentId)) || null;
}

async function setMapping(appointmentId, data) {
  map.set(String(appointmentId), data);
}

async function deleteMapping(appointmentId) {
  map.delete(String(appointmentId));
}

module.exports = { getMapping, setMapping, deleteMapping };
