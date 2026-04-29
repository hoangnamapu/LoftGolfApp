const { impersonate, fetchAppointments } = require("./uschedule");
const { Firestore } = require("@google-cloud/firestore");
const { uscheduleImpersonateEmail, pollIntervalMs } = require("./config");

const db = new Firestore();

function formatLocalDate(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(date.getMonth() + 1)}/${pad(date.getDate())}/${date.getFullYear()}`;
}

async function sendFCMNotification(fcmToken, title, body) {
  const { GoogleAuth } = require("google-auth-library");
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;

  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await client.request({
    url,
    method: "POST",
    data: {
      message: {
        token: fcmToken,
        notification: { title, body },
      },
    },
  });
  return res.data;
}

async function runReminderOnce(authKey) {
  const now = new Date();
  const start = new Date(now);
  const end = new Date(now);
  end.setDate(end.getDate() + 2);

  const appointments = await fetchAppointments(
    authKey,
    formatLocalDate(start),
    formatLocalDate(end)
  );

  for (const appt of appointments) {
    try {
      if (appt.StatusID !== 1) continue;
      if (!appt.StartTime || !appt.CustomerID) continue;

      const startTime = new Date(appt.StartTime);
      const minutesUntilStart = (startTime - now) / 1000 / 60;

      if (minutesUntilStart < 55 || minutesUntilStart > 65) continue;

      const docRef = db.collection("fcm_tokens").doc(String(appt.CustomerID));
      const snap = await docRef.get();
      if (!snap.exists) {
        console.log(`[reminder] No FCM token for customer ${appt.CustomerID}`);
        continue;
      }

      const { fcmToken } = snap.data();
      if (!fcmToken) continue;

      await sendFCMNotification(
        fcmToken,
        "Your session starts in 1 hour!",
        "Get ready for your golf simulator session at Loft Golf Studios."
      );

      console.log(`[reminder] Sent reminder to customer ${appt.CustomerID} for appointment ${appt.AppointmentID}`);
    } catch (err) {
      console.error(`[reminder] Error processing appointment ${appt.AppointmentID}:`, err.message || err);
    }
  }
}

function startReminder(getAuthKey) {
  async function tick() {
    try {
      const authKey = await getAuthKey();
      await runReminderOnce(authKey);
    } catch (err) {
      console.error("[reminder] tick error:", err.message || err);
    }
    setTimeout(tick, 60_000);
  }
  tick();
}

module.exports = { startReminder };