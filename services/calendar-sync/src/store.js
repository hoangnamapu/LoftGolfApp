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

module.exports = { getMapping, setMapping, deleteMapping };