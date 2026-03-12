const { Firestore } = require("@google-cloud/firestore");

const db = new Firestore();
const COLLECTION = process.env.FIRESTORE_COLLECTION || "bookingEventMap";

function docRef(appointmentId) {
  return db.collection(COLLECTION).doc(String(appointmentId));
}

async function getMapping(appointmentId) {
  const snap = await docRef(appointmentId).get();
  return snap.exists ? snap.data() : null;
}

async function setMapping(appointmentId, data) {
  await docRef(appointmentId).set(
    { ...data, updatedAt: new Date().toISOString() },
    { merge: true }
  );
}

async function deleteMapping(appointmentId) {
  await docRef(appointmentId).delete();
}

// ---- Appointment snapshots (change detection for poller) ----

const SNAPSHOT = process.env.SNAPSHOT_COLLECTION || "appointmentSnapshots";

function snapRef(appointmentId) {
  return db.collection(SNAPSHOT).doc(String(appointmentId));
}

async function getSnapshot(appointmentId) {
  const snap = await snapRef(appointmentId).get();
  return snap.exists ? snap.data() : null;
}

async function setSnapshot(appointmentId, data) {
  await snapRef(appointmentId).set(
    { ...data, snapshotUpdatedAt: new Date().toISOString() },
    { merge: true }
  );
}

async function deleteSnapshot(appointmentId) {
  await snapRef(appointmentId).delete();
}

async function listSnapshotIds() {
  const result = await db.collection(SNAPSHOT).select().get();
  return result.docs.map((d) => d.id);
}

module.exports = { getMapping, setMapping, deleteMapping, getSnapshot, setSnapshot, deleteSnapshot, listSnapshotIds };