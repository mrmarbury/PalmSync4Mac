## Contract — EkCalendarDatebookSyncStatus

> **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key). NOT the Palm device's integer `user_id`. All contracts reference the UUID.

### Purpose
Join table tracking per-device sync state for each calendar event. Replaces the 1:1 `sync_to_palm_date`/`rec_id` fields on CalendarEvent with a 1:N relationship.

### Inputs → Outputs

| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| palm_user_id + calendar_event_id + rec_id + last_synced_version + last_sync_success | create_or_update args | palm_user_id: non-nil UUID, calendar_event_id: non-nil UUID, last_synced_version: default 0, non-nil — 0 = initial value, no version change synced yet | upserted EkCalendarDatebookSyncStatus | struct | Row exists with unique {palm_user_id, calendar_event_id} |

### Invariants (MUST ALWAYS be true)
1. Each {palm_user_id, calendar_event_id} pair has exactly ONE row (unique identity enforced by Ash)
2. `rec_id` defaults to 0 — means "not yet written to device"
3. `last_synced` is auto-set to `DateTime.utc_now()` on every create or update (never manually set) (schema-enforced via `writable?: false` — no app-level test needed)
4. `last_sync_success` defaults to `false` — must be explicitly set to `true` on successful write
5. Unique identity `:unique_device_event` on {palm_user_id, calendar_event_id} guarantees no duplicate rows can exist — upsert conflict is impossible by construction

### Error cases

| Condition | Behavior |
|-----------|----------|
| palm_user_id is nil | `{:error, _}` — Ash validation failure |
| calendar_event_id is nil | `{:error, _}` — Ash validation failure |

### Integration points
- Depends on: `PalmSync4Mac.Entity.Device.PalmUser` (palm_user_id references PalmUser.id)
- Depends on: `PalmSync4Mac.Entity.EventKit.CalendarEvent` (calendar_event_id references CalendarEvent.id)
- Modifies: `ek_calendar_datebook_sync_status` SQLite table
- Emits: none

### Prohibitions (MUST NEVER)
1. NEVER allow duplicate rows for the same {palm_user_id, calendar_event_id} pair
2. NEVER store per-device sync state on CalendarEvent — it lives here
3. NEVER manually set `last_synced` — it is always auto-timestamped
4. NEVER add redundant UUID attributes (e.g., `palm_device_uuid`, `calendar_event_uuid`) — the `belongs_to` relationships provide `palm_user_id` and `calendar_event_id` FKs
