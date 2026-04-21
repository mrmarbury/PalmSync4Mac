# Architecture Decision — Multi-Device Calendar Sync

> **ADP Stage**: ARCHITECT
> **Date**: 2026-04-20
> **Status**: Approved for BUILD

---

## 1. Problem

CalendarEvent stores `sync_to_palm_date` and `rec_id` as direct attributes — a 1:1 relationship with a single Palm device. Syncing to a second Palm overwrites the first device's state, breaking record references and update capability.

```
Current: CalendarEvent ──(1:1)──> Palm Device
Needed:  CalendarEvent ──(1:N)──> Palm Devices
```

## 2. Decision

Introduce `EkCalendarDatebookSyncStatus` as a join resource between `PalmUser` and `CalendarEvent`. Each row represents the sync state of one event on one device. Refactor workers to read/write sync state through this join resource instead of CalendarEvent directly.

### 2.1 Data Model

```
┌─────────────────────────────┐       ┌──────────────────────────────────────────┐       ┌─────────────────────────────┐
│       CalendarEvent         │       │    EkCalendarDatebookSyncStatus          │       │         PalmUser            │
├─────────────────────────────┤       ├──────────────────────────────────────────┤       ├─────────────────────────────┤
│ id              (PK, UUID)  │◄──FK──│ id                      (PK, UUID)      │──FK──►│ id              (PK, UUID)  │
│ apple_event_id  (unique)    │       │ palm_user_id            (FK, non-nil)   │       │ username        (unique)    │
│ source          (string)    │       │ calendar_event_id       (FK, non-nil)   │       │ user_id         (int)       │
│ title           (string)    │       │ rec_id                  (int, default 0)│       │ viewer_id       (int)       │
│ start_date      (datetime)  │       │ last_synced             (auto-utc_now)  │       │ last_sync_pc    (int)       │
│ end_date        (datetime)  │       │ last_synced_version     (int, default 0)│       │ successful_sync_date (int)  │
│ notes           (string?)   │       │ last_sync_success       (bool, def false)│      │ last_sync_date       (int)  │
│ url             (string?)   │       └──────────────────────────────────────────┘       └─────────────────────────────┘
│ location        (string?)   │
│ last_modified   (datetime)  │       Unique identity: {palm_user_id, calendar_event_id}
│ calendar_name   (string)    │
│ invitees        ([string]?) │
│ deleted         (bool)      │
│ version         (int)       │
│ ~~sync_to_palm_date~~       │       ← REMOVED (Contract 2)
│ ~~rec_id~~                  │       ← REMOVED (Contract 2)
└─────────────────────────────┘
```

### 2.2 Identity Model

- **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key)
- NOT `PilotUser.user_id` (Palm device integer) — PilotUser is input data from the device; PalmUser is the persistence identity
- PalmUser is upserted on `username` identity — same device always maps to same PalmUser row
- If device returns empty username, generate via `StringUtils.generate_random_string/1`

### 2.3 Execution Model

```
MainWorker (GenServer)
  │
  ├── :connect
  │     └── pilot_connect(port, timeout) → {client_sd, parent_sd}
  │
  ├── Pre-sync Queue
  │     ├── MiscWorker.time_sync()
  │     └── UserInfoWorker.pre_sync() → {:ok, palm_user_id} | {:error, reason}
  │           └── read_user_info → upsert PalmUser → return PalmUser.id
  │
  │  *** IF pre_sync FAILS: skip sync_queue, run post_sync, terminate ***
  │  *** palm_user_id injected as LAST arg into sync_queue MFAs ***
  │
  ├── Sync Queue (linear, continue-on-error)
  │     └── AppointmentWorker.sync_to_palm(client_sd, palm_user_id)
  │           ├── Query unsynced events via join table (palm_user_id filter)
  │           ├── For each: write_datebook_record → upsert join row
  │           └── Return :ok (errors logged, not fatal)
  │
  ├── Post-sync Queue
  │     ├── UserInfoWorker.post_sync()
  │     │     └── write_user_info → update sync date (NOT successful sync date on failure)
  │     └── end_of_sync(client_sd, 0)
  │
  └── :terminate
        └── pilot_disconnect(client_sd, parent_sd)
```

**Key rules:**
- Pre_sync failure is **fatal** — skip sync_queue, run post_sync for protocol cleanup, then terminate
- Sync_queue errors are **non-fatal** — log and continue to next worker
- Post_sync **always runs** — Palm protocol requires `dlp_EndOfSync`
- Workers run **linearly, sequentially** — no branching, no parallelism
- palm_user_id injected as **LAST argument** in MFA args

## 3. Build Order

Implementation must follow this strict sequence (each contract depends on prior contracts):

| Step | Contract | Module | What Changes | Depends On |
|------|----------|--------|-------------|------------|
| 1 | C1 | EkCalendarDatebookSyncStatus | Fix resource: rename `datebook_rec_id` → `rec_id`, remove redundant `palm_device_uuid`/`calendar_event_uuid`, set `last_synced_version` default 0 non-nil, set `last_synced` writable?: false | Nothing |
| 2 | C5 | UserInfoWorker | Convert `write_to_db!` → non-bang, return `{:ok, palm_user_id}`, upsert PalmUser on username identity | C1 (join table exists) |
| 3 | C3 | AppointmentWorker | Rewrite sync_to_palm to accept palm_user_id, query via join table, write join rows instead of CalendarEvent fields | C1 (join table), C5 (palm_user_id available) |
| 4 | C4 | MainWorker | Extract palm_user_id from pre_sync result, inject into sync_queue MFA args | C5 (pre_sync returns palm_user_id) |
| 5 | C2 | CalendarEvent | Remove `sync_to_palm_date`, `rec_id`, `:set_synced_to_palm` action; remove `rec_id` from create_or_update accept | C3 (AppointmentWorker no longer uses these fields) |

Violating this order breaks existing sync functionality.

## 4. Key Architectural Decisions

### 4.1 NIF Failure Taxonomy (Decision 1)

| Failure Type | Detection | Behavior |
|---|---|---|
| **Recoverable** — `{:error, _}` tuple return | NIF returns error tuple | Create/update join row with `last_sync_success: false, rec_id: 0`. Continue to next event. |
| **Unrecoverable** — process crash (segfault, port death) | Supervisor detects dead process | Let supervisor restart worker. No join rows created — worker state is lost. |

### 4.2 Post-sync on Failure (Decision 2)

When pre_sync fails:
- Post_sync **always runs** — Palm protocol requires `dlp_EndOfSync`
- Post_sync updates `last_sync_date` (sync date)
- Post_sync does **NOT** update `successful_sync_date` — this only updates on success

### 4.3 palm_user_id Injection (Decision 3)

- palm_user_id is injected as the **LAST argument** in MFA args
- Example: `{AppointmentWorker, :sync_to_palm, [client_sd, palm_user_id]}`
- Post_sync queue MFAs are **NOT modified** — they don't need palm_user_id

### 4.4 Unsynced Event Query (Contract 3, Decision 14)

Single encapsulated function `list_unsynced_for_device/2` with 4-case test matrix:

| Case | Condition | Included? |
|------|-----------|-----------|
| New event | No join row for this palm_user_id | ✅ Yes |
| Previously failed | Join row has rec_id=0 | ✅ Yes |
| Updated event | CalendarEvent.version > join.last_synced_version | ✅ Yes |
| Already synced | CalendarEvent.version ≤ join.last_synced_version AND rec_id ≠ 0 | ❌ No |

### 4.5 EkCalendarDatebookSyncStatus Fixes (Contract 1)

Current state → Required changes:
- `datebook_rec_id` → `rec_id` (rename)
- Remove `palm_device_uuid` and `calendar_event_uuid` (redundant — belongs_to provides FKs)
- `last_synced_version`: change to `default(0)`, `allow_nil?(false)` (0 = initial, never synced)
- `last_synced`: already has `writable?: false` ✓
- Ensure unique identity `:unique_device_event` on `{palm_user_id, calendar_event_id}` ✓

### 4.6 UserInfoWorker Changes (Contract 5)

- Replace `write_to_db!` (bang) with non-bang version returning `{:ok, _}` | `{:error, _}`
- Return value: `{:ok, palm_user_id}` — MainWorker extracts PalmUser.id from the upserted PalmUser
- If `read_user_info` NIF fails: return `{:error, reason}`, do NOT create PalmUser
- If device returns empty username: generate via `StringUtils.generate_random_string/1`, upsert on that

## 5. NIF Boundary

### Existing NIFs (sufficient for this cycle)

| NIF | Used By | Status |
|-----|---------|--------|
| `pilot_connect` | MainWorker | ✓ Working |
| `pilot_disconnect` | MainWorker | ✓ Working |
| `read_user_info` | UserInfoWorker | ✓ Working |
| `write_user_info` | UserInfoWorker | ✓ Working |
| `open_db` | AppointmentWorker | ✓ Working |
| `close_db` | AppointmentWorker | ✓ Working |
| `write_datebook_record` | AppointmentWorker | ✓ Working |
| `end_of_sync` | (unused — must be wired) | ✓ Exists |
| `set_sys_date_time` | MiscWorker | ✓ Working |

### No new NIFs needed for this ADP cycle

This cycle is **Mac→Palm write-only sync** (same direction as current implementation, just multi-device aware). The missing read NIFs (`dlp_ReadRecordById`, `dlp_ReadRecordByIndex`, `dlp_ReadNextModifiedRec`, `dlp_DeleteRecord`) are needed for **bidirectional sync** (future ADP cycle).

### Known NIF bugs to fix during BUILD

1. **Debug printf statements** in pidlp.c (lines 613-626) — must be removed
2. **Memory leak in write_datebook_record** — strdup'd strings and exception list never freed
3. **Double open_conduit** — `pilot_connect` already calls `dlp_OpenConduit`; separate NIF could cause double-call

## 6. Test Strategy

### Per-Contract Tests

| Contract | Key Tests | Traceability |
|----------|----------|-------------|
| C1 | Upsert creates row, unique identity prevents duplicates, rec_id defaults to 0, last_synced auto-timestamped, last_synced_version defaults to 0 | Contract invariants 1-5 |
| C5 | read_user_info failure returns error, PalmUser upserted on username, empty username generates random, returns palm_user_id | Contract error cases + invariants 1-3 |
| C3 | 4-case unsynced query matrix, join row created on success, join row created on failure, NIF open_db failure creates failed rows for all pending | Contract invariants 1-5 + error cases |
| C4 | palm_user_id injected as last arg, pre_sync failure skips sync_queue, post_sync unchanged, empty sync_queue handled | Contract invariants 1-4 + error cases |
| C2 | Fields removed from CalendarEvent, no code references removed fields, apple_event_id identity preserved, version auto-increment preserved | Contract invariants 1-5 + error cases |

### Test Infrastructure

- **Patch library** for NIF mocking (`Patch.mock(Pidlp, :read_user_info, ...)`)
- **Ash domain tests** for resource operations
- **Integration test** via `integration-check.md` template
- **Verification report** via `verification-report.md` template

## 7. Migration Strategy

### Database Migrations

1. **Contract 1**: Generate migration for EkCalendarDatebookSyncStatus schema changes (rename column, drop columns, alter column defaults). Run `mix ash_sqlite.generate_migrations` then `mix ash_sqlite.migrate`.
2. **Contract 2**: Generate migration to drop `sync_to_palm_date` and `rec_id` columns from `calendar_event` table. Must run AFTER AppointmentWorker rewrite is verified.

### Data Migration

Before dropping CalendarEvent's `sync_to_palm_date` and `rec_id`:
- Existing sync data should be migrated to EkCalendarDatebookSyncStatus rows
- If no existing PalmUser exists for the synced device, one must be created
- This migration is part of Contract 2's integration test requirement

## 8. Constraints

All constraints from AGENTS.md and contracts apply:

- Palm encoding: ALWAYS ISO-8859-1 via codepagex, NEVER UTF-8
- TM struct: tm_mon 0-11, tm_year = years since 1900
- rec_id = 0 means "new record" — Palm assigns actual ID on write
- `{:ok, result}` / `{:error, reason}` tuples — never raise on expected errors
- No process dictionary for palm_user_id — function argument at every call site
- Workers run linearly, sequentially
- Pre_sync failure is fatal; sync_queue errors are non-fatal
- Post_sync always runs (Palm protocol requirement)

## 9. Out of Scope

- Bidirectional sync (Palm → Mac)
- Conflict resolution for simultaneous edits
- Phoenix LiveView UI
- NIF additions for record reading/deletion
- CalendarDB-PDat support (using DatebookDB for now)
- Multiple calendar sources

## 10. Risks

| Risk | Mitigation |
|------|------------|
| EkCalendarDatebookSyncStatus resource has bugs in current state | Contract 1 fixes all known issues; thorough test coverage |
| MainWorker MFA injection changes runtime behavior | Contract 4 tested in isolation; post_sync queue verified unchanged |
| Removing CalendarEvent fields breaks unknown consumers | Contract 2 runs LAST; grep for all references before migration |
| Data loss during migration from CalendarEvent fields | Integration test seeds data, runs migration, verifies join table |
| NIF memory leaks cause VM instability over time | Fix write_datebook_record leak during BUILD; monitor in VERIFY |
