## Contract — AppointmentWorker.sync_to_palm

> **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key). NOT the Palm device's integer `user_id`. All contracts reference the UUID.

### Purpose
Rewrite sync logic to use the EkCalendarDatebookSyncStatus join table for querying unsynced events and recording sync results per device, instead of reading/writing directly on CalendarEvent.

### Inputs → Outputs

| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| palm_user_id | UUID | non-nil, references PalmUser.id. Received as LAST function argument after client_sd. | Events synced to Palm device | side effect | Join rows created/updated for every event attempted |
| client_sd | integer | valid NIF socket descriptor | Palm records written | side effect | dlp_WriteRecord called for each unsynced event |

### Invariants (MUST ALWAYS be true)
1. Every sync attempt (success OR failure) creates or updates a join row in EkCalendarDatebookSyncStatus
2. On successful write: join row gets `rec_id` from Palm, `last_sync_success: true`
3. On failed write: join row gets `rec_id: 0`, `last_sync_success: false`
4. Query logic (test matrix — 3 positive + 1 negative):
   - ✅ No join row exists for this palm_user_id → event included (new event)
   - ✅ Join row has rec_id=0 → event included (failed previous sync)
   - ✅ CalendarEvent.version > join.last_synced_version → event included (event updated since last sync)
   - ❌ CalendarEvent.version ≤ join.last_synced_version AND rec_id ≠ 0 → event EXCLUDED (already synced)
5. `palm_user_id` is received as argument — not queried from state or process dictionary

### Error cases

| Condition | Behavior |
|-----------|----------|
| NIF `open_db` returns `{:error, _}` | Create failed join rows for ALL pending events with `last_sync_success: false`, `rec_id: 0` (no db_handle = no writes possible). Return `{:error, :open_db_failed}`. |
| NIF `write_datebook_record` returns `{:error, _}` | Create join row with `last_sync_success: false`, `rec_id: 0`. Continue to next event. |
| NIF process crash (port death, dirty NIF segfault) | Let supervisor restart the worker. No join rows created — worker state is lost. |
| No unsynced events for this palm_user_id | Return `:ok` with no side effects |
| palm_user_id is nil | `{:error, :palm_user_id_required}` — Dialyzer spec + guard clause enforce non-nil |

### Integration points
- Depends on: `PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus` (read + create_or_update)
- Depends on: `PalmSync4Mac.Entity.EventKit.CalendarEvent` (read only — query unsynced events)
- Depends on: `PalmSync4Mac.Comms.Pidlp` NIF functions (open_db, write_datebook_record, close_db)
- Modifies: EkCalendarDatebookSyncStatus rows (create_or_update after each sync attempt)
- Emits: none
- MUST NOT modify: CalendarEvent.sync_to_palm_date or CalendarEvent.rec_id (these fields are removed)

### Prohibitions (MUST NEVER)
1. NEVER update CalendarEvent.sync_to_palm_date or rec_id — these fields are removed
2. NEVER skip creating a join row on sync failure — failures must be tracked
3. Unsynced query MUST be a single encapsulated function (e.g., `list_unsynced_for_device/2`). No alternative query paths for the same data. All queries filter by palm_user_id.
4. palm_user_id MUST be received as a function argument at every call site. NEVER obtain palm_user_id from process dictionary, Registry, Agent, or any global/shared state mechanism.
5. NEVER catch/suppress a process-crashing NIF failure — let the supervisor restart the worker. Only `{:error, _}` tuple returns are recoverable.
