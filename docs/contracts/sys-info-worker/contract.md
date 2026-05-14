# Contract Sheet — SysInfoWorker Infrastructure (Gate D-1)

**Feature**: SysInfoWorker — fetch device sysinfo during pre-sync, pass as context to sync workers
**GitHub**: [mrmarbury/PalmSync4Mac#27](https://github.com/mrmarbury/PalmSync4Mac/issues/27)
**ADP Stage**: SPECIFY → BUILD
**Date**: 2026-05-14

---

## 1. Goal

Create the infrastructure to fetch Palm device system info (`read_sysinfo` NIF) during pre-sync and pass the resulting `PilotSysInfo` struct as context to sync queue workers. This enables version-branching (Gate D-2, #25) and category mapping (Gate E, #26) without each worker calling `read_sysinfo` independently.

Also: move `PalmSync4Mac.Pilot.SyncWorkers` to `PalmSync4Mac.Pilot.Helper.SyncWorkers` — it's a helper for `DynamicSyncWorkerSup`, not a sync worker itself.

---

## 2. Architecture Decisions

### A1: SysInfoWorker mirrors UserInfoWorker pattern

SysInfoWorker is a GenServer that runs in `pre_sync_queue`, calls `Pidlp.read_sysinfo(client_sd)`, and returns `{:ok, sys_info}`. MainWorker collects this alongside `palm_user_id` and injects both into sync queue MFAs.

**Rationale**: Consistent with existing pre_sync architecture. UserInfoWorker reads user info → returns palm_user_id. SysInfoWorker reads sys info → returns sys_info. MainWorker injects both. No hidden coupling, no global state.

### A2: PilotSysInfo struct mirrors Unifex spec type

The Elixir struct `PalmSync4Mac.Comms.Pidlp.PilotSysInfo` uses the same field names and types as the `sys_info` type in `pidlp.spec.exs`. This is the same pattern as `PilotUser` mirroring the `pilot_user` spec type.

**Rationale**: Unifex auto-generates the struct from the spec at compile time, but we want an explicit module with `TypedStruct` for documentation, defaults, and nimble options — matching how `PilotUser` is defined.

### A3: No DB storage for sys_info

SysInfo is per-sync context only. There are no dates or flags to track. If device capability caching is needed later, we can add a `PalmSysInfo` Ash resource then.

**Rationale**: YAGNI. Storing sys_info now would require a migration, resource definition, and a relationship to PalmUser — all for no current consumer.

### A4: MainWorker injects both palm_user_id and sys_info as sync context

Rename `inject_palm_user_id/2` → `inject_sync_context/3`. Sync queue MFAs receive both `palm_user_id` and `sys_info` as the last two arguments. Post-sync queue remains unchanged (no injection).

**Rationale**: Workers need both values. `palm_user_id` identifies the device in the DB; `sys_info` carries device capabilities. Together they form the "sync context." Appending both as the last args is the simplest, most explicit approach — consistent with the existing `inject_palm_user_id` pattern.

### A5: SyncWorkers moves to Helper namespace

`PalmSync4Mac.Pilot.SyncWorkers` → `PalmSync4Mac.Pilot.Helper.SyncWorkers`. File moves from `lib/palmsync4mac/pilot/sync_workers.ex` to `lib/palmsync4mac/pilot/helper/sync_workers.ex`.

**Rationale**: `SyncWorkers` is a thin wrapper around `DynamicSupervisor.start_child/which_children/terminate_child`. It's not a sync worker itself — it's a helper for the dynamic supervisor. The `Pilot.Helper` namespace already contains `UserInfoHelper`, so `SyncWorkers` belongs there.

---

## 3. File Structure

```
lib/palmsync4mac/
├── comms/pidlp/
│   ├── pilot_sys_info.ex                    ← NEW: PilotSysInfo struct
│   ├── pilot_user.ex                        (unchanged)
│   └── ...
├── pilot/
│   ├── helper/
│   │   ├── sync_workers.ex                  ← MOVED from pilot/sync_workers.ex
│   │   ├── sys_info/
│   │   │   └── sys_info_helper.ex           ← NEW: read_sys_info wrapper
│   │   └── user_info/
│   │       └── user_info_helper.ex          (unchanged)
│   ├── sync_worker/
│   │   ├── appointment_worker.ex            ← UPDATED: receives sys_info arg
│   │   ├── main_worker.ex                   ← UPDATED: inject_sync_context
│   │   ├── sys_info_worker.ex               ← NEW: pre-sync worker
│   │   ├── user_info_worker.ex              (unchanged)
│   │   └── ...
│   └── ...

test/palmsync4mac/pilot/
├── helper/
│   └── sys_info/
│       └── sys_info_helper_test.exs         ← NEW
├── sync_worker/
│   ├── appointment_worker_test.exs          ← UPDATED: sys_info in test args
│   ├── main_worker_test.exs                 ← UPDATED: inject_sync_context
│   ├── sys_info_worker_test.exs             ← NEW
│   └── ...
```

Old file to DELETE: `lib/palmsync4mac/pilot/sync_workers.ex`

---

## 4. Components

### 4.1 PilotSysInfo struct

**Module**: `PalmSync4Mac.Comms.Pidlp.PilotSysInfo`

Fields mirror `pidlp.spec.exs` type `sys_info`:

| Field | Type | Default | Doc |
|-------|------|---------|-----|
| `rom_version` | `non_neg_integer()` | `0` | ROM version of the Palm OS. `0x05020000` = Palm OS 5.2 (CalendarDB threshold) |
| `locale` | `non_neg_integer()` | `0` | Device locale |
| `prod_id_length` | `non_neg_integer()` | `0` | Length of the product ID string |
| `prod_id` | `String.t()` | `""` | Product ID string (e.g., "Palm TX") |
| `dlp_major_version` | `non_neg_integer()` | `0` | DLP protocol major version |
| `dlp_minor_version` | `non_neg_integer()` | `0` | DLP protocol minor version |
| `compat_major_version` | `non_neg_integer()` | `0` | Compatibility major version |
| `compat_minor_version` | `non_neg_integer()` | `0` | Compatibility minor version |
| `max_rec_size` | `non_neg_integer()` | `0` | Maximum record size the device supports |

Uses `TypedStruct` with `TypedStructLens` and `TypedStructNimbleOptions` — same as `PilotUser`.

### 4.2 SysInfoHelper

**Module**: `PalmSync4Mac.Pilot.Helper.SysInfo.SysInfoHelper`

| Function | Signature | Returns |
|----------|-----------|---------|
| `read_sys_info/1` | `read_sys_info(client_sd)` | `{:ok, %PilotSysInfo{}}` or `{:error, reason}` |

Behavior:
- Calls `Pidlp.read_sysinfo(client_sd)`
- On `{:ok, _client_sd, sys_info_map}`: converts the map to `%PilotSysInfo{}` struct, returns `{:ok, struct}`
- On `{:error, _client_sd, _result, message}`: returns `{:error, message}`
- On `client_sd == -1`: returns `{:error, "Not connected to a Palm device?"}` (mirrors `UserInfoHelper` guard)

Pattern follows `UserInfoHelper.read_user_info/1` exactly.

### 4.3 SysInfoWorker

**Module**: `PalmSync4Mac.Pilot.SyncWorker.SysInfoWorker`

| Function | Signature | Returns |
|----------|-----------|---------|
| `start_link/1` | `start_link(worker_info \\ %__MODULE__{})` | GenServer.start_link result |
| `sync/0` | `sync()` | `{:ok, %PilotSysInfo{}}` or `{:error, reason}` |

Struct: `%__MODULE__{client_sd: -1, sys_info: %PilotSysInfo{}}`

Behavior:
- `sync/0`: calls `SysInfoHelper.read_sys_info(state.client_sd)`, stores result in state, returns it
- No DB write — sys_info is per-sync context only
- No post_sync — unlike UserInfoWorker, there's nothing to write back to the device

### 4.4 MainWorker injection change

**Before**: `inject_palm_user_id(mfas, palm_user_id)` → appends `palm_user_id` to each MFA's args
**After**: `inject_sync_context(mfas, palm_user_id, sys_info)` → appends `[palm_user_id, sys_info]` to each MFA's args

Example:
```elixir
# Before
{AppointmentWorker, :sync_to_palm, []}
→ {AppointmentWorker, :sync_to_palm, ["palm-user-uuid"]}

# After
{AppointmentWorker, :sync_to_palm, []}
→ {AppointmentWorker, :sync_to_palm, ["palm-user-uuid", %PilotSysInfo{rom_version: 0x05040000, ...}]}
```

`run_pre_sync` must now accumulate both `palm_user_id` (from `UserInfoWorker.pre_sync/1`) and `sys_info` (from `SysInfoWorker.sync/0`).

Both are injected as the LAST arguments. `palm_user_id` is always last-1, `sys_info` is always last. This preserves the existing `palm_user_id` position and adds `sys_info` after it.

### 4.5 AppointmentWorker adaptation

**Before**: `sync_to_palm(palm_user_id)` — 1 arg
**After**: `sync_to_palm(palm_user_id, sys_info)` — 2 args

The `sys_info` parameter is accepted but NOT consumed in Gate D-1. Gate D-2 (#25) will use it for version-branching. This contract only ensures the plumbing is in place.

### 4.6 SyncWorkers move

Old: `PalmSync4Mac.Pilot.SyncWorkers` at `lib/palmsync4mac/pilot/sync_workers.ex`
New: `PalmSync4Mac.Pilot.Helper.SyncWorkers` at `lib/palmsync4mac/pilot/helper/sync_workers.ex`

All references updated:
- `MainWorker` (alias + call sites)
- `main_worker_test.exs` (alias + patch call sites)

Module body unchanged — only namespace changes.

---

## 5. Invariants

| ID | Invariant |
|----|-----------|
| I1 | `SysInfoHelper.read_sys_info/1` returns `{:ok, %PilotSysInfo{}}` on success, `{:error, reason}` on failure |
| I2 | `rom_version` is a `non_neg_integer`. `0x05020000` = Palm OS 5.2 (CalendarDB threshold). `0x05040000` = Palm OS 5.4 (Palm TX) |
| I3 | `inject_sync_context/3` appends `[palm_user_id, sys_info]` as the last two args to each sync queue MFA |
| I4 | Pre-sync fails fast if **either** `UserInfoWorker.pre_sync/1` or `SysInfoWorker.sync/0` fails — skip sync_queue, run post_sync for protocol cleanup |
| I5 | Post-sync queue MFAs are NOT affected by `inject_sync_context` — no injection into post_sync |
| I6 | No DB persistence of `PilotSysInfo` — per-sync context only |
| I7 | `SyncWorkers` module lives under `PalmSync4Mac.Pilot.Helper` |
| I8 | `PilotSysInfo` field names and types match `pidlp.spec.exs` type `sys_info` |
| I9 | `palm_user_id` is always arg N-1, `sys_info` is always arg N (the last arg) in injected MFAs |

---

## 6. Error Cases

| Condition | Behavior |
|-----------|----------|
| `Pidlp.read_sysinfo` NIF fails | `{:error, message}` — pre-sync fails, sync_queue skipped |
| `client_sd == -1` in SysInfoHelper | `{:error, "Not connected to a Palm device?"}` |
| UserInfoWorker succeeds but SysInfoWorker fails | Pre-sync is fatal — skip sync_queue, run post_sync |
| SysInfoWorker succeeds but UserInfoWorker fails | Pre-sync is fatal — skip sync_queue, run post_sync |
| `sys_info` is nil after successful pre-sync | `{:error, :sys_info_missing}` — bug, not runtime condition |

---

## 7. Integration Points

| Component | Depends On | Modifies | Consumers |
|-----------|------------|----------|-----------|
| `PilotSysInfo` struct | `pidlp.spec.exs` type definitions | None | `SysInfoHelper`, `SysInfoWorker`, `AppointmentWorker` (D-2) |
| `SysInfoHelper` | `Pidlp.read_sysinfo/1` NIF | None | `SysInfoWorker` |
| `SysInfoWorker` | `SysInfoHelper.read_sys_info/1` | None (no DB) | `MainWorker` (pre_sync return) |
| `MainWorker.inject_sync_context/3` | `PilotSysInfo` struct, `palm_user_id` | `PilotSyncRequest.sync_queue` MFA args | All sync queue workers |
| `SyncWorkers` move | None | Module namespace | `MainWorker`, tests |

---

## 8. Prohibitions (MUST NEVER)

1. NEVER store `PilotSysInfo` in the database in this gate — no Ash resource, no migration
2. NEVER inject `sys_info` into `post_sync_queue` MFAs — post_sync doesn't need it
3. NEVER obtain `sys_info` from process dictionary, Registry, Agent, or any global/shared state — always function argument
4. NEVER call `Pidlp.read_sysinfo` from inside a sync worker (e.g., AppointmentWorker) — SysInfoWorker owns this in pre_sync
5. NEVER modify MFA module or function in `inject_sync_context` — only the args list
6. NEVER delete the old `sync_workers.ex` until the new one is committed and all references are updated
7. NEVER delete existing comments that are still valid

---

## 9. Test Coverage

### 9.1 SysInfoHelper tests

| Test | Invariant |
|------|-----------|
| `read_sys_info` returns `{:ok, %PilotSysInfo{}}` on NIF success | I1 |
| `read_sys_info` returns `{:error, message}` on NIF failure | I1 |
| `read_sys_info` returns `{:error, "Not connected..."}` when `client_sd == -1` | I1 |
| Returned struct fields match NIF response (field mapping) | I8 |

### 9.2 SysInfoWorker tests

| Test | Invariant |
|------|-----------|
| `sync/0` returns `{:ok, %PilotSysInfo{}}` when helper succeeds | I1 |
| `sync/0` returns `{:error, reason}` when helper fails | I1 |
| `sync/0` stores sys_info in state | — |

### 9.3 MainWorker injection tests

| Test | Invariant |
|------|-----------|
| `inject_sync_context` appends both `palm_user_id` and `sys_info` to MFA args | I3, I9 |
| `palm_user_id` is always before `sys_info` in args | I9 |
| Post-sync queue MFAs are unchanged | I5 |
| Pre-sync fails when SysInfoWorker fails | I4 |

### 9.4 SyncWorkers move tests

| Test | Invariant |
|------|-----------|
| All existing MainWorker tests pass with new `PalmSync4Mac.Pilot.Helper.SyncWorkers` alias | I7 |

### 9.5 AppointmentWorker adaptation tests

| Test | Invariant |
|------|-----------|
| Existing tests updated to pass `sys_info` as second arg to `sync_to_palm` | I3 |

---

## 10. Downstream Dependencies (NOT in this contract)

| Gate | How it uses PilotSysInfo |
|------|--------------------------|
| D-2 (#25) | `rom_version >= 0x05020000` → CalendarDB-PDat + `write_calendar_record`, else DatebookDB + `write_datebook_record`. Location appended to note in DateBook path. |
| E (#26) | Palm DB category slots mapping from Apple `calendar_name` |

---

## 11. Breaking Changes

1. `MainWorker.inject_palm_user_id/2` → `MainWorker.inject_sync_context/3` (renamed, new arg)
2. `AppointmentWorker.sync_to_palm/1` → `AppointmentWorker.sync_to_palm/2` (new `sys_info` arg)
3. `PalmSync4Mac.Pilot.SyncWorkers` → `PalmSync4Mac.Pilot.Helper.SyncWorkers` (namespace change)

---

## 12. Review Findings (2026-05-14)

**Status**: PENDING — engineer to review one by one before BUILD.

### 🔴 Issue 1: Unifex spec namespace conflict

`pidlp.spec.exs` line 27 uses bare `%PilotSysInfo{}` for the `sys_info` type. Unifex will auto-generate a struct at that bare name. If we also create `PalmSync4Mac.Comms.Pidlp.PilotSysInfo` manually, we get two incompatible structs.

**Fix**: Update `pidlp.spec.exs` to use `%PalmSync4Mac.Comms.Pidlp.PilotSysInfo{}` — same pattern as the `pilot_user` type (line 6, which already uses the full module path). Add this to the contract task list.

### 🔴 Issue 2: `run_pre_sync` accumulation mechanism unspecified

Current `run_pre_sync` uses `Enum.reduce_while` with a single-value accumulator and `is_binary` guard to extract `palm_user_id`. This:
- Cannot accumulate two values (`palm_user_id` + `sys_info`)
- The `{:ok, _}` clause (line 182-183) swallows non-binary returns — `{:ok, %PilotSysInfo{}}` would be silently discarded
- The guard `when is_binary(palm_user_id)` (line 179) would NOT match a `PilotSysInfo` struct

**Fix**: Rewrite with map accumulator:
```elixir
%{palm_user_id: nil, sys_info: nil}
```
Pattern-match on return struct type to populate the right key:
- `is_binary(value)` → `palm_user_id`
- `is_struct(value, PilotSysInfo)` → `sys_info`
- `:ok` or `{:ok, _}` (non-matching) → skip, continue

After reduce, validate both keys are non-nil. If either is nil, return `{:error, :palm_user_id_missing}` or `{:error, :sys_info_missing}`.

Add explicit design section to contract §4.4.

### 🟡 Issue 3: `SysInfoWorker.sync/0` naming convention

`UserInfoWorker` uses `pre_sync/1` and `post_sync/0`. `MiscWorker` uses `time_sync/0`. The contract calls SysInfoWorker's function `sync/0` — breaks the naming convention.

**Fix**: Rename to `pre_sync/0`. MFA in queue becomes `{SysInfoWorker, :pre_sync, []}`.

### 🟡 Issue 4: SysInfoWorker failure should be fatal — needs explicit decision

Contract I4 says pre-sync fails fast if either worker fails, but doesn't explain WHY. Without `rom_version`, AppointmentWorker can't version-branch. Falling back to DatebookDB would silently lose location data (DateBook v1 has no location field). This is a data loss scenario, not just a degradation.

**Fix**: Add invariant I4 rationale: "SysInfoWorker failure is fatal because `rom_version` is required for version-branching. Fallback to DatebookDB would silently lose location data."

### 🟡 Issue 5: `sync_test.ex` needs SysInfoWorker in pre_queue

`lib/palmsync4mac/pilot/sync_test.ex` defines the pre_sync_queue as `[MiscWorker.time_sync, UserInfoWorker.pre_sync]`. After D-1, it must also include `{SysInfoWorker, :pre_sync, []}`. Contract §3 file structure doesn't mention this file.

**Fix**: Add `sync_test.ex` to the file structure table as UPDATED.
