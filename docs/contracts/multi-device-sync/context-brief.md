## Context Brief — Multi-Device Calendar Sync

### Target
Transition CalendarEvent-to-Palm sync from 1:1 (single device) to 1:N (multiple devices) via a join table.

### Existing code
- `lib/palmsync4mac/entity/event_kit/calendar_event.ex`: Ash resource with `sync_to_palm_date` and `rec_id` attributes (1:1 problem)
- `lib/palmsync4mac/entity/sync_status/ek_calendar_datebook_sync_status.ex`: Ash resource (exists but not wired up, missing `rec_id`, wrong field names)
- `lib/palmsync4mac/pilot/sync_worker/appointment_worker.ex`: Sync logic queries CalendarEvent directly for `sync_to_palm_date`, writes rec_id back to CalendarEvent
- `lib/palmsync4mac/pilot/sync_worker/main_worker.ex`: Orchestrator, runs pre_sync/sync/post_sync queues via MFA tuples
- `lib/palmsync4mac/pilot/sync_worker/user_info_worker.ex`: Reads Palm user info, upserts PalmUser — does NOT return palm_user_id
- `lib/palmsync4mac/pilot/pilot_sync_request.ex`: TypedStruct with sync queues — no palm_user_id field
- `docs/design/calendar_event_design.md`: Pre-ADP design doc with proposed data model, sync logic, worker architecture, bidirectional future

### Conventions to follow
- Ash resources: `uuid_primary_key`, snake_case attributes, domain-based organization
- Error tuples: `{:ok, result}` / `{:error, reason}` — never raise on expected errors
- NIF calls: always handle `{:error, _}` returns, never let NIF errors crash the VM
- Testing: ExUnit with Patch library for NIF mocking, Mox for external deps
- Naming: `create_or_update` actions for upserts, unique identities for upsert targets
- MFA pattern: `{Module, :function, args}` tuples in sync queues

### Hard constraints
- Palm encoding: ISO-8859-1 via codepagex, NEVER UTF-8
- TM struct: tm_mon 0-11, tm_year = years since 1900
- rec_id = 0 means "new record" — Palm assigns actual ID on write
- NIF safety: proper error handling in C code, no VM crashes
- pilot-link resource cleanup: sockets, DB handles, pi_buffer, malloc'd strings
- `palm_viewer_id` in config.exs identifies this client to Palm device
- Socket descriptors (`client_sd`, `parent_sd`) kept across NIF calls

### Type definitions
- **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key). NOT the Palm device's integer `user_id` (`PilotUser.user_id`). All contracts reference the UUID. The Palm device identifies users by username; PalmSync4Mac identifies them by the UUID assigned on upsert.

### Out of scope
- Bidirectional sync (Palm → Mac)
- Conflict resolution for simultaneous edits on Mac and Palm
- Phoenix LiveView UI
- Sync status UI or reporting dashboard
- Multiple calendar sources (currently only Apple Calendar via EventKit)

### Build order
Implementation must follow this sequence (each contract depends on prior contracts):

1. **Contract 1** — EkCalendarDatebookSyncStatus resource (join table must exist before workers write to it)
2. **Contract 5** — UserInfoWorker.pre_sync (must return user_info with palm_user_id available before MainWorker can extract it)
3. **Contract 3** — AppointmentWorker.sync_to_palm (must use join table before CalendarEvent fields are removed)
4. **Contract 4** — MainWorker MFA injection (injects palm_user_id extracted from user_info into sync_queue args)
5. **Contract 2** — CalendarEvent modifications (remove sync fields LAST, after all consumers are rewritten)

Violating this order breaks existing sync functionality.
