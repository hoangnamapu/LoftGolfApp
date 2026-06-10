const { fetchAppointments, fetchAvailability } = require("./uschedule");
const { Firestore } = require("@google-cloud/firestore");
const { getSnapshot } = require("./store");
const { ARIZONA_TIME_ZONE, parseArizonaTime } = require("./time");
const {
  uscheduleLocationId,
  uscheduleServiceId,
  uscheduleServiceLengthMin,
} = require("./config");

const db = new Firestore();

/**
 * Whether an appointment's slot shows as FREE/bookable, which means it was
 * cancelled (getapiappointments cannot tell us this — see poller.js). Uses a
 * per-run cache keyed by "unitId|YYYY-MM-DD" to avoid repeat calls. On any error
 * or missing data, returns false (assume active) so we never suppress a real
 * reminder just because the availability lookup failed.
 */
async function isSlotCancelled(authKey, appt, cache) {
  const unitId = appt.ResourceUnitID;
  const rawStartTime = appt.StartTime;
  if (unitId == null || typeof rawStartTime !== "string") return false;

  const day = rawStartTime.slice(0, 10);
  const hour = rawStartTime.slice(11, 16);
  const key = `${unitId}|${day}`;

  let free = cache.get(key);
  if (!free) {
    try {
      const slots = await fetchAvailability(authKey, {
        locationId: uscheduleLocationId,
        resourceUnitId: unitId,
        serviceId: uscheduleServiceId,
        startDateISO: `${day}T00:00:00`,
        serviceLength: uscheduleServiceLengthMin,
      });
      free = new Set(
        slots
          .filter((s) => s && typeof s.StartTime === "string" && s.StartTime.slice(0, 10) === day)
          .map((s) => s.StartTime.slice(11, 16))
      );
      cache.set(key, free);
    } catch (err) {
      console.error("[reminder] availability check failed", { key, error: err.message || String(err) });
      return false;
    }
  }
  return free.has(hour);
}

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

  // Per-run cache of free slots so cancelled appointments don't trigger reminders.
  const availabilityCache = new Map();

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
      // Production (clients.uschedule.com) returns StatusID 0 for normal active
      // bookings; only 9/10 (canceled/rescheduled) should be skipped here.
      const CANCELED_STATUS_IDS = [9, 10];
      if (CANCELED_STATUS_IDS.includes(statusId)) {
        console.log("[reminder] Skipping appointment because it is canceled/rescheduled", {
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

      // Skip records the poller has tombstoned (cancelled, superseded by a
      // newer booking on the same slot, or an abandoned checkout hold). The
      // slot check below can't catch dead records whose slot is occupied by
      // the superseding booking — the tombstone can.
      const snapshot = await getSnapshot(appointmentId);
      if (snapshot?.syncState && snapshot.syncState !== "active") {
        console.log("[reminder] Skipping appointment because it is tombstoned", {
          appointmentId,
          syncState: snapshot.syncState,
        });
        continue;
      }

      // Skip cancelled appointments — getapiappointments still returns them, so
      // confirm via availability that the slot is actually still booked.
      if (await isSlotCancelled(authKey, appt, availabilityCache)) {
        console.log("[reminder] Skipping appointment because its slot is free (cancelled)", {
          appointmentId,
          customerId,
          rawStartTime,
        });
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