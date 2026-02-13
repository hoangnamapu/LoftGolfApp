# Calendar Sync Test Plan (Loft Golf Studios)

## Purpose
Validate that the booking ↔ Google Calendar sync service works correctly for **both bays** and for the required change types: **create, update, cancel**.

This test plan is designed to be executed during Sprint 7 as implementation progresses. It is written so results can be recorded and shared with Loft for sign-off before any production cutover.

---

## Test Environment
### Google Cloud
- Project: **LoftGolfSchedule** (`loftgolfschedule`)
- Service Account: **USchedule Sync Bot**
  - `uschedule-sync-bot@loftgolfschedule.iam.gserviceaccount.com`
- Required access: service account has **Make changes to events** on:
  - **Loft Bay 1 Schedule (API)**
  - **Loft Bay 2 Schedule (API)**

### Calendars
- Bay 1 calendar: **Loft Bay 1 Schedule (API)**
- Bay 2 calendar: **Loft Bay 2 Schedule (API)**

### USchedule
- Use the Loft test account / environment configured for Bay 1 and Bay 2 resources.

### Observability Required
- Sync service logs must include:
  - direction (`USCHEDULE_TO_GCAL` / `GCAL_TO_USCHEDULE`)
  - action (`create` / `update` / `cancel`)
  - appointmentId, calendarId, eventId
  - error payload if failure

---

## Test Data Conventions
To keep testing organized:
- Create bookings with a recognizable label (example title format):
  - `TEST - <date> - Bay <1|2> - <case id>`
- Use a consistent duration (ex: 60 minutes) unless the case requires duration changes.

---

## Preconditions Checklist (Run Once)
1. Google Calendar API enabled in GCP project
2. Service account exists and key stored securely (not in GitHub)
3. Service account has calendar permissions on both Bay calendars
4. Sync service is running and reachable (local or deployed)
5. Mapping storage is available (db/table/collection) and writable

Record:
- Date tested:
- Environment (local / deployed):
- Tester:

---

## Test Cases

### A. USchedule → Google Calendar (Bay routing + CRUD)

#### A1. Create booking routes to correct calendar (Bay 1)
**Steps**
1. Create a new booking in USchedule for **Bay 1** (future time).
2. Wait for sync to process.

**Expected**
- A Google Calendar event appears on **Bay 1 (API)** calendar.
- No event appears on Bay 2 calendar.
- Sync logs show `USCHEDULE_TO_GCAL` + `create`.
- Mapping record created linking appointmentId ↔ eventId.

**Pass/Fail**
- Notes / Evidence (link screenshot/log line):

---

#### A2. Create booking routes to correct calendar (Bay 2)
Repeat A1 but for Bay 2.

**Expected**
- Event appears only on **Bay 2 (API)** calendar.

---

#### A3. Update booking time updates Google event (Bay 1)
**Steps**
1. Use a booking created in A1.
2. Change start time and end time in USchedule.
3. Wait for sync.

**Expected**
- Matching Google event time updates on Bay 1 calendar.
- No duplicate events created.
- Logs show `USCHEDULE_TO_GCAL` + `update`.

---

#### A4. Update booking details updates Google event (optional fields)
**Steps**
1. Update a descriptive field in USchedule (name/notes if mirrored).
2. Wait for sync.

**Expected**
- Google event title/description updates if the field is part of the mirrored payload.
- Logs show `update`.

---

#### A5. Cancel booking removes or cancels Google event (Bay 1)
**Steps**
1. Cancel a booking in USchedule.
2. Wait for sync.

**Expected**
- Google event is deleted OR marked cancelled (whichever is chosen in implementation).
- Mapping record marked canceled.
- Logs show `USCHEDULE_TO_GCAL` + `cancel`.

---

#### A6. Idempotency: repeat same update does not create duplicates
**Steps**
1. Trigger the same booking update twice (or replay webhook).
2. Wait for sync.

**Expected**
- Still only one event in calendar.
- Logs show update processed safely without duplication.

---

### B. Google Calendar → USchedule (Only Loft-managed events)

> These tests should be executed only after events contain the Loft-managed metadata (e.g., `uscheduleAppointmentId` in private extended properties). Manual events without metadata should be ignored.

#### B1. Edit Loft-managed event time updates USchedule booking (Bay 1)
**Steps**
1. Choose a Loft-managed Google event created by the service (from A1).
2. Edit the event’s start/end time in Google Calendar UI.
3. Wait for sync.

**Expected**
- USchedule appointment updates to the new time.
- Logs show `GCAL_TO_USCHEDULE` + `update`.
- No loop behavior (should not bounce changes repeatedly).

---

#### B2. Delete or cancel Loft-managed event cancels USchedule booking (Bay 1)
**Steps**
1. Choose a Loft-managed Google event created by the service.
2. Delete the event (or mark cancelled).
3. Wait for sync.

**Expected**
- USchedule appointment is canceled.
- Logs show `GCAL_TO_USCHEDULE` + `cancel`.

---

#### B3. Manual (non-managed) Google event is ignored
**Steps**
1. Create a brand new event directly in Bay 1 calendar (not created by the service).
2. Wait for sync.

**Expected**
- No USchedule booking is created or modified.
- Logs indicate event ignored (optional).

---

### C. Error / Recovery Cases

#### C1. Missing calendar permission yields clear error and no crash
**Steps**
1. Remove service account permissions from Bay 2 calendar temporarily.
2. Create Bay 2 booking in USchedule.

**Expected**
- Sync logs show permission error (403) with clear context.
- Service continues running and processes other events.
- On restoring permissions, reprocessing succeeds.

---

#### C2. Google API rate limit / transient failure retries
**Steps**
1. Trigger multiple booking updates quickly (5–10).
2. Observe handling.

**Expected**
- Service retries with backoff for 429/5xx.
- No duplicates created.
- Eventually consistent sync.

---

## Pass/Fail Criteria for Sprint Sign-off
Sprint sign-off requires:
- A1–A5 pass for both Bay 1 and Bay 2.
- Idempotency test A6 passes.
- If reverse sync is in scope for the sprint, B1–B3 must pass.
- Logs provide traceability for each sync action.

---

## Test Record Template
Use the following for each run:

- Date:
- Environment (local/deployed):
- Commit/PR:
- Tester:
- Results:
  - Bay 1: A1 A2 A3 A4 A5 A6 / B1 B2 B3
  - Bay 2: A1 A2 A3 A4 A5 A6 / B1 B2 B3
- Issues found:
- Next actions:
