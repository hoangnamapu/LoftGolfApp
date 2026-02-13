# Calendar Sync Service Architecture (Loft Golf Studios)

## Purpose
Provide a Loft-owned, always-on sync service that keeps **Loft bookings** and **Google Calendar** aligned for **Bay 1** and **Bay 2**, even when the iOS app is closed.

This document describes the backend architecture and the data/flow rules that Sprint 7 implementation should follow.

---

## Goals
- **USchedule → Google Calendar**
  - Create / update / cancel a booking in USchedule and reflect it on the correct Bay calendar.
- **Google Calendar → USchedule**
  - If a Loft-created event is edited or cancelled in Google Calendar, apply the same change back to the corresponding USchedule booking.
- Support **multiple bays** by routing to the correct calendar.
- Loft-owned credentials and infrastructure (not tied to a student/personal account).
- Keep **Home Assistant** unchanged (it can keep reading the same calendars as it does today).

---

## Non-goals (for initial implementation)
- Converting arbitrary manual Google Calendar events into bookings automatically.
- Complex conflict resolution (double edits, time collisions) beyond a simple “last write wins” rule.
- Full audit UI inside the iOS app (we will log via backend first).

---

## Key Resources
### Google Cloud
- **Project:** LoftGolfSchedule (`loftgolfschedule`)
- **Service Account:** USchedule Sync Bot  
  `uschedule-sync-bot@loftgolfschedule.iam.gserviceaccount.com`

### Calendars
- **Bay 1 Calendar:** Loft Bay 1 Schedule (API)
- **Bay 2 Calendar:** Loft Bay 2 Schedule (API)

The service account must have **Make changes to events** permission on both calendars.

---

## High-level System Components
1. **iOS Booking App (Swift / Xcode)**
   - Creates/updates/cancels bookings via USchedule API.
   - Does not store Google service keys.

2. **Sync Service (Backend)**
   - Runs continuously (recommended: Cloud Run).
   - Owns Google Calendar API credentials (service account).
   - Owns USchedule API credentials (server-side).
   - Handles inbound triggers and performs sync actions.

3. **USchedule API**
   - Source of truth for bookings (recommended).
   - Provides booking data (start/end time, bay/resource, customer info, status).

4. **Google Calendar API**
   - Holds mirrored events per bay calendar.
   - Receives changes from USchedule and sends change notifications back to the service.

5. **Storage (lightweight DB)**
   - Stores mapping between USchedule bookings and Google events.
   - Stores sync state and last processed change tokens.
   - Options: Firestore / Cloud SQL / SQLite-equivalent on hosted service (Cloud SQL recommended if scaling).

---

## Data Model (Minimum)
### BookingEventMap
- `uscheduleAppointmentId` (string, primary identifier)
- `googleCalendarId` (Bay 1 or Bay 2)
- `googleEventId` (string)
- `lastSyncedAt` (timestamp)
- `lastSource` (enum: `USCHEDULE` | `GCAL`)
- `version` or `etag` (optional, for concurrency)
- `status` (ACTIVE | CANCELED)

### Google Event Metadata
When creating Google events, embed identifiers so we can recognize “Loft-managed” events:
- `extendedProperties.private.uscheduleAppointmentId = "<id>"`
- `extendedProperties.private.loftSyncManaged = "true"`
- Optional: `extendedProperties.private.bay = "1"|"2"`

This prevents the service from trying to sync unrelated manual events.

---

## Sync Rules
### Source of Truth
- Default: **USchedule is the source of truth**.
- Google Calendar edits are accepted **only for Loft-managed events** (events containing the embedded appointment ID).

### Loop Prevention
Each sync write should stamp a source marker and update `lastSource`:
- If the service applies an update to Google because of a USchedule change, record `lastSource=USCHEDULE`.
- If a Google change notification arrives immediately afterward, ignore it if:
  - it matches the last write window and/or
  - the `etag`/timestamp indicates no meaningful change.
  
Practical rule (simple and effective):
- Ignore inbound changes that occur within **N seconds** (ex: 5–10s) of our own write *for the same appointment/event*, unless the content truly differs.

### Routing (Bay Selection)
Determine target calendar from the booking’s **bay/resource**:
- Bay 1 booking → Bay 1 calendar ID
- Bay 2 booking → Bay 2 calendar ID
This mapping should be centralized in config.

---

## Flow A: USchedule → Google Calendar
**Trigger options (choose based on USchedule capabilities):**
1) Webhook from USchedule (ideal)
2) Polling USchedule changes every X minutes (fallback)

**Process**
1. Receive booking change (create/update/cancel).
2. Determine bay → calendar ID.
3. Look up `BookingEventMap` by `uscheduleAppointmentId`.
4. If no map exists (new booking):
   - Create Google event on the bay calendar.
   - Store mapping.
5. If map exists (update):
   - Patch Google event (time/details).
6. If cancelled:
   - Delete/cancel Google event and mark mapping canceled.

**Idempotency**
- If the service receives the same change twice, it should not duplicate events.
- Always key off `uscheduleAppointmentId` and existing mapping.

---

## Flow B: Google Calendar → USchedule
**Trigger**
- Use Google Calendar **watch** (push notifications) for each bay calendar.
- The service receives notifications and then performs an incremental sync using sync tokens.

**Process**
1. Notification received for Calendar X (Bay 1 or Bay 2).
2. Fetch changed events since last sync (using sync token).
3. For each changed event:
   - Only process if `loftSyncManaged=true` AND `uscheduleAppointmentId` exists.
   - If event time changed → call USchedule update.
   - If event canceled/deleted → call USchedule cancel.
4. Update `BookingEventMap` and sync tokens.

**Safety**
- If a user edits an event but removes metadata, treat it as “not managed” and do not sync back.

---

## Failure Handling & Retries
- Use exponential backoff for API errors (429, 5xx).
- Log failures with:
  - appointment ID
  - calendar ID
  - event ID
  - error payload
- Dead-letter pattern (optional): store failed sync tasks for manual replay.

---

## Security
- Service account JSON key must never be committed to Git.
- Use environment secrets:
  - Cloud Run Secret Manager (recommended)
- Principle of least privilege:
  - Calendar access limited to the two bay calendars.
- USchedule credentials stored server-side only.

---

## Deployment (Recommended)
- **Cloud Run** service with HTTPS endpoint(s):
  - `/webhook/uschedule` (if USchedule supports webhooks)
  - `/webhook/gcal` (Google push notifications)
  - `/health` (basic health check)
- Optional:
  - Cloud Scheduler to refresh watch channels if needed
  - Firestore / Cloud SQL for storage

---

## Observability
- Structured logs for each sync action:
  - `action=create|update|cancel`
  - `direction=USCHEDULE_TO_GCAL|GCAL_TO_USCHEDULE`
  - ids: appointmentId, calendarId, eventId
- Basic metrics:
  - sync success rate
  - error rate by endpoint
  - queue/retry counts

---

## Open Questions (Track in Taiga)
- Does USchedule provide webhooks for booking changes, or do we poll?
- What booking fields should be mirrored into Google event title/description?
- How should we handle overlapping bookings or time conflicts detected in Google Calendar?
- What is the preferred cancellation behavior in Google Calendar:
  - delete the event, or mark it canceled?

---

## Minimal Validation Checklist (for Sprint 7)
Bay 1 and Bay 2 must each pass:
- Create booking in USchedule → event appears on correct bay calendar.
- Update booking time → Google event updates.
- Cancel booking → Google event removed or canceled.
- Edit Loft-managed Google event time → USchedule updates.
- Delete/cancel Loft-managed Google event → USchedule cancels.
