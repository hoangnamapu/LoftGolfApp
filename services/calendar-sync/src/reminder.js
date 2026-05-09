const { fetchAppointments } = require("./uschedule");
const { Firestore } = require("@google-cloud/firestore");

const db = new Firestore();

const ARIZONA_TIME_ZONE = "America/Phoenix";

// ---- Helpers ----

function formatArizonaDate(date) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: ARIZONA_TIME_ZONE,
    month: "2-digit",
    day: "2-digit",
    year: "numeric",
  }).formatToParts(date);

  const get = (type) => parts.find((p) => p.type === type)?.value;

  return `${get("month")}/${get("day")}/${get("year")}`;
}

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

async function sendFCMNotification(fcmToken, title, body) {
  const { GoogleAuth } = require("google-auth-library");

  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const client = await auth.getClient();

  const projectId =
    process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;

  if (!projectId) {
    throw new Error(
      "Missing GCLOUD_PROJECT or GOOGLE_CLOUD_PROJECT environment variable"
    );
  }

  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const res = await client.request({
    url,
    method: "POST",
    data: {
      message: {
        token: fcmToken,
        notification: {
          title,
          body,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      },
    },
  });

  return res.data;
}

// ---- Core logic ----

async function runReminderOnce(authKey) {
  const now = new Date();

  const start = new Date(now);
  const end = new Date(now);
  end.setDate(end.getDate() + 2);

  const startDate = formatArizonaDate(start);
  const endDate = formatArizonaDate(end);

  console.log("[reminder] Running reminder check", {
    now: now.toISOString(),
    startDate,
    endDate,
  });

  const appointments = await fetchAppointments(authKey, startDate, endDate);

  console.log("[reminder] Appointments fetched", {
    count: Array.isArray(appointments) ? appointments.length : 0,
  });

  if (!Array.isArray(appointments)) {
    console.warn("[reminder] fetchAppointments did not return an array", {
      appointmentsType: typeof appointments,
    });
    return;
  }

  for (const appt of appointments) {
    try {
      const appointmentId = appt.AppointmentID;
      const customerId = appt.CustomerID;
      const statusId = appt.StatusID;
      const rawStartTime = appt.StartTime;

      console.log("[reminder] Checking appointment", {
        appointmentId,
        customerId,
        statusId,
        rawStartTime,
      });

      // Only process active appointments.
      // If sponsor testing still fails, verify that active uSchedule bookings really use StatusID === 1.
      if (statusId !== 1) {
        console.log("[reminder] Skipping appointment because StatusID is not 1", {
          appointmentId,
          statusId,
        });
        continue;
      }

      if (!rawStartTime || !customerId) {
        console.log(
          "[reminder] Skipping appointment because StartTime or CustomerID is missing",
          {
            appointmentId,
            customerId,
            rawStartTime,
          }
        );
        continue;
      }

      const startTime = parseArizonaTime(rawStartTime);

      if (!startTime) {
        console.warn("[reminder] Could not parse StartTime", {
          appointmentId,
          rawStartTime,
        });
        continue;
      }

      const minutesUntilStart = (startTime.getTime() - now.getTime()) / 1000 / 60;

      console.log("[reminder] Appointment timing", {
        appointmentId,
        customerId,
        rawStartTime,
        parsedStartTime: startTime.toISOString(),
        now: now.toISOString(),
        minutesUntilStart: Number(minutesUntilStart.toFixed(1)),
      });

      // Send notification when appointment starts in around 1 hour.
      // Window is 55 to 65 minutes to tolerate scheduler delay.
      if (minutesUntilStart < 55 || minutesUntilStart > 65) {
        continue;
      }

      // ---- Deduplication ----
      const sentRef = db
        .collection("appointment_reminders_sent")
        .doc(String(appointmentId));

      const sentSnap = await sentRef.get();

      if (sentSnap.exists) {
        console.log("[reminder] Reminder already sent, skipping", {
          appointmentId,
          customerId,
        });
        continue;
      }

      // ---- Look up FCM token ----
      const tokenDocRef = db.collection("fcm_tokens").doc(String(customerId));
      const tokenSnap = await tokenDocRef.get();

      if (!tokenSnap.exists) {
        console.log("[reminder] No FCM token document for customer", {
          appointmentId,
          customerId,
          expectedFirestoreDoc: `fcm_tokens/${customerId}`,
        });
        continue;
      }

      const tokenData = tokenSnap.data() || {};
      const fcmToken = tokenData.fcmToken;

      if (!fcmToken) {
        console.log("[reminder] fcmToken field is empty", {
          appointmentId,
          customerId,
          expectedFirestoreDoc: `fcm_tokens/${customerId}`,
        });
        continue;
      }

      console.log("[reminder] Sending FCM reminder", {
        appointmentId,
        customerId,
      });

      const fcmResult = await sendFCMNotification(
        fcmToken,
        "Your session starts in 1 hour!",
        "Get ready for your golf simulator session at Loft Golf Studios."
      );

      // ---- Mark as sent to prevent duplicate reminders ----
      await sentRef.set({
        appointmentId: String(appointmentId),
        customerId: String(customerId),
        rawStartTime,
        parsedStartTime: startTime.toISOString(),
        sentAt: Firestore.Timestamp.now(),
        fcmResult,
      });

      console.log("[reminder] Sent reminder successfully", {
        appointmentId,
        customerId,
        fcmResult,
      });
    } catch (err) {
      console.error("[reminder] Error processing appointment", {
        appointmentId: appt?.AppointmentID,
        customerId: appt?.CustomerID,
        error: err.message || String(err),
      });
    }
  }
}

// ---- Poller ----
// This still works for local testing.
// For production on Cloud Run, Cloud Scheduler calling runReminderOnce()
// is more reliable than depending on this setTimeout loop.

function startReminder(getAuthKey) {
  async function tick() {
    try {
      const authKey = await getAuthKey();
      await runReminderOnce(authKey);
    } catch (err) {
      console.error("[reminder] tick error:", err.message || String(err));
    }

    setTimeout(tick, 60_000);
  }

  tick();
}

module.exports = {
  startReminder,
  runReminderOnce,
};