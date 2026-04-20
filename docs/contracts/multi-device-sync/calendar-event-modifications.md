## Contract — CalendarEvent Modifications

> **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key). NOT the Palm device's integer `user_id`. All contracts reference the UUID.

### Purpose
Remove per-device sync state from CalendarEvent. These fields move to EkCalendarDatebookSyncStatus join table. CalendarEvent becomes device-agnostic — it represents an Apple Calendar event, not its sync status with any particular Palm.

### Inputs → Outputs

| Change | Type | Constraint |
|--------|------|------------|
| Remove `sync_to_palm_date` attribute | attribute removal | No code may reference this field after migration |
| Remove `rec_id` attribute | attribute removal | No code may reference this field after migration |
| Remove `:set_synced_to_palm` action | action removal | No code may call this action after migration |
| Remove `rec_id` from `:create_or_update` accept list | accept list change | create_or_update no longer accepts rec_id |

### Invariants (MUST ALWAYS be true)
1. All other CalendarEvent attributes remain untouched (id, apple_event_id, source, title, start_date, end_date, notes, url, location, last_modified, calendar_name, invitees, deleted, version) — VERIFY: diff CalendarEvent attribute list against pre-migration snapshot; only `sync_to_palm_date` and `rec_id` may differ
2. `:create_or_update` action still works — upserts on `apple_event_id` identity
3. `apple_event_id` unique identity is preserved
4. `version` auto-increment is preserved
5. No data loss — existing `sync_to_palm_date` and `rec_id` values are migrated to EkCalendarDatebookSyncStatus before removal. VERIFY: integration test that seeds CalendarEvent with sync_to_palm_date + rec_id, runs migration, verifies join table has migrated data.

### Error cases

| Condition | Behavior |
|-----------|----------|
| Code references removed field after migration | VERIFY stage must grep all .ex/.exs files for `sync_to_palm_date`, `rec_id` (in CalendarEvent context), and `:set_synced_to_palm`. Compile errors catch direct attribute access; grep catches dynamic key access |
| Migration runs before AppointmentWorker rewrite | VERIFY stage must grep all .ex/.exs files for `sync_to_palm_date`, `rec_id` (in CalendarEvent context), and `:set_synced_to_palm` — any reference found blocks migration |

### Integration points
- Depends on: migration must run AFTER AppointmentWorker is rewritten (or AppointmentWorker breaks)
- Modifies: `calendar_event` SQLite table (column removal via migration)
- Consumers: `AppointmentWorker` (currently reads sync_to_palm_date and writes rec_id — must be rewritten first)
- Consumers: `CalendarEventWorker` (calls `:create_or_update` — must no longer pass rec_id)

### Prohibitions (MUST NEVER)
1. NEVER store per-device sync state on CalendarEvent — use EkCalendarDatebookSyncStatus
2. NEVER remove attributes that are not explicitly listed above (verified by Invariant 1 snapshot diff)
3. NEVER change the `apple_event_id` unique identity (verified by Invariant 3 test)
4. NEVER change the `version` auto-increment behavior (verified by Invariant 4 test)
