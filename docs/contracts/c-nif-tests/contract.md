# Contract Sheet — C NIF Tests with Mocked Device Calls

**Feature**: Gate B for sync-from-palm (#16)
**GitHub**: [mrmarbury/PalmSync4Mac#21](https://github.com/mrmarbury/PalmSync4Mac/issues/21)
**ADP Stage**: SPECIFY → BUILD
**Date**: 2026-05-14

---

## 1. Goal

Create C-level unit tests for `pidlp.c` that mock the pilot-link API so all 13 NIF functions + 3 helper functions can be exercised without real hardware. The test harness must be ready for the 3 new read-record NIFs arriving in #16.

---

## 2. Architecture Decisions

### A1: Test Framework — Unity

**Unity** (ThrowTheSwitch): single-header + single-source C test framework. Zero external dependencies, widely used in embedded and NIF testing. Provides `TEST_ASSERT_*` macros, `setUp`/`tearDown` lifecycle, test runner generation via Ruby script (optional — hand-written runner is fine for <50 tests).

**Rationale**: Minimal footprint, no CMake/config required, single compilation unit. Alternative (cmocka) is more complex for no added benefit at this scale.

### A2: Mock Strategy — Link-Time Substitution (Option C from context brief)

Create a mock `libpisock` implementation (`c_src/mocks/pisock_mocks.c`) that provides stubs for all 21 pilot-link API functions used by pidlp.c. Tests compile pidlp.c normally but link against the mock library instead of real `libpisock.a`.

**Rationale**: Option A (mock headers) requires maintaining parallel header files that duplicate pilot-link struct definitions. Option C (link-time substitution) lets us:
- Include the REAL pilot-link headers (struct definitions stay in sync with pilot-link)
- Only provide mock function BODIES (no struct re-definitions needed)
- Detect signature mismatches at link time (mock function signature differs from real header → link error)
- Works with the existing Bundlex compilation (no pidlp.c changes needed for test compilation)

**Revised from context brief**: Option A was initially recommended but upon deeper analysis, Option C is superior because:
1. Pilot-link structs (`struct SysInfo`, `struct PilotUser`, `struct Appointment`, `CalendarEvent_t`, `pi_buffer_t`) are complex and version-sensitive — maintaining parallel mock headers is fragile
2. Link-time mock catches signature drift automatically
3. pidlp.c compiles against REAL headers → no risk of struct layout mismatch

**Exception for test-unreachable types**: `pi_buffer_t` is an opaque type in pilot-link. For the mock, we provide a minimal struct definition that satisfies the test's needs. Since the real header defines `pi_buffer_t`, this means we need a thin wrapper — see §5 Mock Implementation.

### A3: Build Integration — Standalone Makefile

A `Makefile` in `c_src/` with a `test` target, independent of Bundlex. Rationale: Bundlex has no test target support and adding one would require forking the dep.

```makefile
# Usage: cd c_src && make test
```

### A4: CI Integration — Extend elixir.yml

Add a `Run C tests` step to `.github/workflows/elixir.yml` AFTER the pilot-link build step (pilot-link headers are needed for compilation). This avoids a separate workflow file.

---

## 3. File Structure

```
c_src/
├── Makefile                          ← NEW: test build target
├── palm_sync_4_mac/
│   ├── pidlp.c                       ← MODIFIED: remove debug printf, dead code
│   ├── pidlp.h                       ← unchanged
│   ├── pidlp.spec.exs                ← unchanged
│   ├── _generated/                   ← unchanged (Unifex-generated)
│   ├── tests/                        ← NEW: test directory
│   │   ├── test_pidlp_helpers.c      ← pure-data function tests
│   │   ├── test_pidlp_read.c         ← DLP read function tests
│   │   ├── test_pidlp_write.c        ← DLP write function tests
│   │   ├── test_pidlp_connection.c   ← connection flow tests
│   │   └── test_runner.c             ← Unity main() runner
│   └── mocks/                        ← NEW: mock implementations
│       ├── pisock_mocks.c            ← stub bodies for all 21 pilot-link functions
│       ├── pisock_mocks.h            ← mock state: configurable returns, call tracking
│       └── unity/                    ← Unity test framework
│           ├── unity.h
│           ├── unity_internals.h
│           └── unity.c
```

---

## 4. Invariants

### I1: Helper Function Correctness

| ID | Invariant |
|----|-----------|
| I1.1 | `is_blank(NULL)` returns `true` |
| I1.2 | `is_blank("")` returns `true` |
| I1.3 | `is_blank("   ")` (whitespace only) returns `true` |
| I1.4 | `is_blank("abc")` returns `false` |
| I1.5 | `is_blank("  abc  ")` returns `false` |
| I1.6 | `timehtm_to_tm` copies all 9 `struct tm` fields from `timehtm` (tm_sec..tm_isdst) |
| I1.7 | `timehtm_to_tm` with zeroed input produces zeroed output |
| I1.8 | `timehtm_list_to_tm_list(NULL, N)` returns `NULL` |
| I1.9 | `timehtm_list_to_tm_list(src, 0)` returns `NULL` |
| I1.10 | `timehtm_list_to_tm_list` allocates `count * sizeof(struct tm)` bytes |
| I1.11 | `timehtm_list_to_tm_list` maps each element via `timehtm_to_tm` |

### I2: DLP Read Functions

| ID | Invariant |
|----|-----------|
| I2.1 | `read_sysinfo` returns `{:ok, sys_info}` when `dlp_ReadSysInfo` returns ≥0 |
| I2.2 | `read_sysinfo` maps `romVersion → rom_version`, `locale → locale`, `prodID → prod_id` (strndup), `prodIDLength → prod_id_length`, `dlpMajorVersion → dlp_major_version`, `dlpMinorVersion → dlp_minor_version`, `compatMajorVersion → compat_major_version`, `compatMinorVersion → compat_minor_version`, `maxRecSize → max_rec_size` |
| I2.3 | `read_sysinfo` returns `{:error, result, message}` when `dlp_ReadSysInfo` returns <0 |
| I2.4 | `get_sys_date_time` returns `{:ok, palm_date_time}` when `dlp_GetSysDateTime` returns ≥0 |
| I2.5 | `get_sys_date_time` casts `time_t` to `uint64_t` for the result |
| I2.6 | `get_sys_date_time` returns `{:error, result, message}` when `dlp_GetSysDateTime` returns <0 |
| I2.7 | `read_user_info` returns `{:ok, pilot_user}` when `dlp_ReadUserInfo` returns ≥0 |
| I2.8 | `read_user_info` maps `passwordLength → password_length`, `username → username` (strdup), `password → password` (strndup), `userID → user_id`, `viewerID → viewer_id`, `lastSyncPC → last_sync_pc`, `successfulSyncDate → successful_sync_date`, `lastSyncDate → last_sync_date` |
| I2.9 | `read_user_info` returns `{:error, result, message}` when `dlp_ReadUserInfo` returns <0 |

### I3: DLP Write Functions

| ID | Invariant |
|----|-----------|
| I3.1 | `write_user_info` maps `pilot_user_t` fields back to `struct PilotUser` (reverse of I2.8) |
| I3.2 | `write_user_info` null-terminates `username` and `password` via `strncpy` |
| I3.3 | `write_user_info` returns `{:ok}` when `dlp_WriteUserInfo` returns ≥0 |
| I3.4 | `write_user_info` returns `{:error, result, message}` when `dlp_WriteUserInfo` returns <0 |
| I3.5 | `write_datebook_record` calls `pack_Appointment` → `dlp_WriteRecord` in sequence |
| I3.6 | `write_datebook_record` returns `{:error, message}` when `pack_Appointment` returns -1 |
| I3.7 | `write_datebook_record` maps `appointment.event → pilot_appointment.event`, `.begin → .begin` (via timehtm_to_tm), `.end → .end`, `.alarm → .alarm`, `.alarm_advance → .advance`, `.alarm_advance_units → .advanceUnits`, `.repeat_type → .repeatType`, `.repeat_end → .repeatEnd`, `.repeat_frequency → .repeatFrequency`, `.repeat_forever → .repeatForever`, `.repeat_day → .repeatDay`, `.repeat_days → .repeatDays`, `.repeat_weekstart → .repeatWeekstart`, `.exceptions_count → .exceptions`, `.exceptions_actual → .exception` (via timehtm_list_to_tm_list), `.description → .description` (strdup), `.note → .note` (NULL if blank, strdup otherwise) |
| I3.8 | `write_datebook_record` sets `note = NULL` when `is_blank(appointment.note)` is true |
| I3.9 | `write_datebook_record` frees `pi_buffer_t` after `dlp_WriteRecord` |
| I3.10 | `write_datebook_record` returns `{:ok, result, rec_id}` on success |
| I3.11 | `write_calendar_record` calls `new_CalendarEvent` → field mapping → `pack_CalendarEvent` → `dlp_WriteRecord` → `free_CalendarEvent` + `pi_buffer_free` in sequence |
| I3.12 | `write_calendar_record` additionally maps `.location → .location` (NULL if blank, strdup otherwise), sets `.tz = NULL` |
| I3.13 | `write_calendar_record` frees both `CalendarEvent_t` and `pi_buffer_t` on all code paths (success and pack failure) |

### I4: Connection Flow

| ID | Invariant |
|----|-----------|
| I4.1 | `pilot_connect` with NULL port falls back to `$PILOTPORT` env var, then `/dev/pilot` |
| I4.2 | `pilot_connect` returns `{:error, client_sd=-1, parent_sd=-1, message}` when `stat(/dev/pilot)` fails and no port/PILOTPORT |
| I4.3 | `pilot_connect` returns error when `pi_socket` returns 0 |
| I4.4 | `pilot_connect` returns error when `pi_bind` returns <0, includes errno-specific messages (ENOENT, EACCES, ENODEV, EISDIR) |
| I4.5 | `pilot_connect` calls `pi_close(parent_sd)` and `pi_close(client_sd)` on bind failure |
| I4.6 | `pilot_connect` returns error when `pi_listen` returns -1, closes both sockets |
| I4.7 | `pilot_connect` returns error when `pi_accept_to` returns -1, closes both sockets |
| I4.8 | `pilot_connect` calls `dlp_OpenConduit(client_sd)` on successful accept |
| I4.9 | `pilot_connect` returns `{:ok, client_sd, parent_sd}` on full success |
| I4.10 | `pilot_disconnect` calls `pi_close(client_sd)` then `pi_close(parent_sd)` |
| I4.11 | `pilot_disconnect` returns `{:ok, client_sd, parent_sd}` unconditionally |
| I4.12 | `open_conduit` returns `{:ok, client_sd, result}` when `dlp_OpenConduit` returns ≥0 |
| I4.13 | `open_conduit` returns `{:error, client_sd, result, message}` when `dlp_OpenConduit` returns <0 |
| I4.14 | `open_db` returns `{:ok, client_sd, db_handle}` when `dlp_OpenDB` returns ≥0 |
| I4.15 | `open_db` returns `{:error, client_sd, result, message}` when `dlp_OpenDB` returns <0 |
| I4.16 | `close_db` calls `dlp_CloseDB(client_sd, dbhandle)` and returns `{:ok, client_sd}` |
| I4.17 | `end_of_sync` returns `{:ok, client_sd, result}` when `dlp_EndOfSync` returns ≥0 |
| I4.18 | `end_of_sync` returns `{:error, client_sd, result}` when `dlp_EndOfSync` returns <0 |

---

## 5. Mock Implementation

### Mock State Structure

```c
// pisock_mocks.h
typedef struct {
    // Configurable return values
    int pi_socket_return;
    int pi_bind_return;
    int pi_listen_return;
    int pi_accept_to_return;
    int pi_close_return;
    int dlp_OpenConduit_return;
    int dlp_OpenDB_return;
    int dlp_CloseDB_return;
    int dlp_EndOfSync_return;
    int dlp_ReadSysInfo_return;
    int dlp_GetSysDateTime_return;
    int dlp_SetSysDateTime_return;
    int dlp_ReadUserInfo_return;
    int dlp_WriteUserInfo_return;
    int dlp_WriteRecord_return;
    int pack_Appointment_return;
    int pack_CalendarEvent_return;

    // Configurable output data (for read functions)
    struct SysInfo mock_sys_info;
    struct PilotUser mock_pilot_user;
    time_t mock_sys_date_time;
    recordid_t mock_new_rec_id;

    // Call tracking
    int pi_socket_call_count;
    int pi_bind_call_count;
    int pi_listen_call_count;
    int pi_accept_to_call_count;
    int pi_close_call_count;
    int dlp_OpenConduit_call_count;
    int dlp_OpenDB_call_count;
    int dlp_CloseDB_call_count;
    int dlp_EndOfSync_call_count;
    int dlp_ReadSysInfo_call_count;
    int dlp_GetSysDateTime_call_count;
    int dlp_SetSysDateTime_call_count;
    int dlp_ReadUserInfo_call_count;
    int dlp_WriteUserInfo_call_count;
    int dlp_WriteRecord_call_count;
    int pack_Appointment_call_count;
    int pack_CalendarEvent_call_count;
    int new_CalendarEvent_call_count;
    int free_CalendarEvent_call_count;
    int pi_buffer_new_call_count;
    int pi_buffer_free_call_count;
} PilotLinkMockState;

// Global mock state — set in test setUp, reset in tearDown
extern PilotLinkMockState mock_state;

// Helper to reset mock state to default (all returns = 0)
void mock_state_reset(void);
```

### pi_buffer_t Mock

`pi_buffer_t` is opaque in pilot-link. For tests, provide a minimal struct:

```c
// In pisock_mocks.h
typedef struct {
    unsigned char *data;
    size_t used;
    size_t allocated;
} pi_buffer_t;
```

The mock `pi_buffer_new` allocates this struct + a data buffer. The mock `pi_buffer_free` releases both. `pack_Appointment`/`pack_CalendarEvent` mocks write fake data into `buf->data` and set `buf->used`.

### Compilation Strategy

```bash
# Compile pidlp.c with REAL pilot-link headers but link against mocks
gcc -std=c11 -I/opt/homebrew/include \
    -Ic_src/palm_sync_4_mac \
    -Ic_src/palm_sync_4_mac/_generated/nif \
    -Ic_src/palm_sync_4_mac/mocks \
    -c c_src/palm_sync_4_mac/pidlp.c -o build/pidlp.o

# Compile mocks
gcc -std=c11 -I/opt/homebrew/include -Ic_src/palm_sync_4_mac/mocks \
    -c c_src/palm_sync_4_mac/mocks/pisock_mocks.c -o build/pisock_mocks.o

# Compile tests
gcc -std=c11 -I... -c c_src/palm_sync_4_mac/tests/test_pidlp_helpers.c -o build/test_helpers.o
# ... etc

# Link: pidlp.o + pisock_mocks.o + unity.o + test_*.o → test binary
gcc build/pidlp.o build/pisock_mocks.o build/unity.o build/test_*.o -o build/test_pidlp
```

**Key**: pidlp.c is compiled with REAL `<pi-*.h>` headers (struct definitions are authentic). Only the function BODIES come from `pisock_mocks.c` instead of `libpisock.a`. This guarantees struct layout matches production.

### Unifex Env Stub

NIF functions take `UnifexEnv *env` as first arg. For C tests, we need a minimal `UnifexEnv` that satisfies the generated code. Two approaches:

1. **Stub UnifexEnv**: Define a minimal `UnifexEnv` struct in the mock layer
2. **Test helper functions directly**: The pure-data helpers (`is_blank`, `timehtm_to_tm`, `timehtm_list_to_tm_list`) don't take `UnifexEnv` — test them with zero Unifex dependency
3. **Test NIF function logic with mock result builders**: The generated `_result_ok`/`_result_error` functions need `UnifexEnv`. For C unit tests, we mock these too (they just need to return a non-crashing value so we can verify the function took the right branch)

**Decision**: For Phase 1 (this gate), test the NIF function LOGIC without calling the Unifex result builders. Extract the "business logic" path (error checks, field mapping, call sequencing) by:
- Testing helpers directly (no UnifexEnv needed)
- Testing NIF functions by checking mock state (call counts, argument captures) rather than return values
- If a NIF function returns via `*_result_ok`/`*_result_error`, we provide mock implementations of these that just record what was called

This avoids pulling in the entire Unifex/ErlNif runtime for C tests.

---

## 6. Test Cases

### C1: Helper Function Tests (test_pidlp_helpers.c)

| # | Test | Invariant |
|---|------|-----------|
| 1 | `test_is_blank_null` | I1.1 |
| 2 | `test_is_blank_empty` | I1.2 |
| 3 | `test_is_blank_whitespace_only` | I1.3 |
| 4 | `test_is_blank_nonwhitespace` | I1.4 |
| 5 | `test_is_blank_mixed` | I1.5 |
| 6 | `test_timehtm_to_tm_all_fields` | I1.6 |
| 7 | `test_timehtm_to_tm_zeroed` | I1.7 |
| 8 | `test_timehtm_list_null_input` | I1.8 |
| 9 | `test_timehtm_list_zero_count` | I1.9 |
| 10 | `test_timehtm_list_allocation` | I1.10 |
| 11 | `test_timehtm_list_maps_each_element` | I1.11 |

### C2: DLP Read Tests (test_pidlp_read.c)

| # | Test | Invariant |
|---|------|-----------|
| 12 | `test_read_sysinfo_success` | I2.1, I2.2 |
| 13 | `test_read_sysinfo_error` | I2.3 |
| 14 | `test_get_sys_date_time_success` | I2.4, I2.5 |
| 15 | `test_get_sys_date_time_error` | I2.6 |
| 16 | `test_read_user_info_success` | I2.7, I2.8 |
| 17 | `test_read_user_info_error` | I2.9 |

### C3: DLP Write Tests (test_pidlp_write.c)

| # | Test | Invariant |
|---|------|-----------|
| 18 | `test_write_user_info_field_mapping` | I3.1, I3.2 |
| 19 | `test_write_user_info_success` | I3.3 |
| 20 | `test_write_user_info_error` | I3.4 |
| 21 | `test_write_datebook_record_success` | I3.5, I3.7, I3.10 |
| 22 | `test_write_datebook_record_pack_failure` | I3.6 |
| 23 | `test_write_datebook_record_note_blank` | I3.8 |
| 24 | `test_write_datebook_record_buffer_freed` | I3.9 |
| 25 | `test_write_calendar_record_success` | I3.11, I3.12 |
| 26 | `test_write_calendar_record_pack_failure` | I3.13 (frees on error) |
| 27 | `test_write_calendar_record_location_blank` | I3.12 |
| 28 | `test_write_calendar_record_resources_freed` | I3.13 |

### C4: Connection Flow Tests (test_pidlp_connection.c)

| # | Test | Invariant |
|---|------|-----------|
| 29 | `test_pilot_connect_null_port_uses_default` | I4.1 |
| 30 | `test_pilot_connect_stat_fails` | I4.2 |
| 31 | `test_pilot_connect_socket_fails` | I4.3 |
| 32 | `test_pilot_connect_bind_fails_enoent` | I4.4 (errno=2) |
| 33 | `test_pilot_connect_bind_fails_eacces` | I4.4 (errno=13) |
| 34 | `test_pilot_connect_bind_fails_enodev` | I4.4 (errno=19) |
| 35 | `test_pilot_connect_bind_fails_eisdir` | I4.4 (errno=21) |
| 36 | `test_pilot_connect_bind_fails_closes_sockets` | I4.5 |
| 37 | `test_pilot_connect_listen_fails` | I4.6 |
| 38 | `test_pilot_connect_accept_fails` | I4.7 |
| 39 | `test_pilot_connect_success` | I4.8, I4.9 |
| 40 | `test_pilot_disconnect` | I4.10, I4.11 |
| 41 | `test_open_conduit_success` | I4.12 |
| 42 | `test_open_conduit_error` | I4.13 |
| 43 | `test_open_db_success` | I4.14 |
| 44 | `test_open_db_error` | I4.15 |
| 45 | `test_close_db` | I4.16 |
| 46 | `test_end_of_sync_success` | I4.17 |
| 47 | `test_end_of_sync_error` | I4.18 |

**Total: 47 tests**

---

## 7. Build Order

| Step | Action | Depends on |
|------|--------|------------|
| 1 | Create `c_src/palm_sync_4_mac/mocks/` with Unity + pisock_mocks | — |
| 2 | Create `c_src/Makefile` with `test` target | Step 1 |
| 3 | Create `c_src/palm_sync_4_mac/tests/test_pidlp_helpers.c` | Step 1 |
| 4 | Create `c_src/palm_sync_4_mac/tests/test_pidlp_read.c` | Step 1, 2 |
| 5 | Create `c_src/palm_sync_4_mac/tests/test_pidlp_write.c` | Step 1, 2 |
| 6 | Create `c_src/palm_sync_4_mac/tests/test_pidlp_connection.c` | Step 1, 2 |
| 7 | Create `c_src/palm_sync_4_mac/tests/test_runner.c` | Step 3–6 |
| 8 | Clean up pidlp.c: remove debug printf, dead code | Step 2 |
| 9 | Add CI step to `.github/workflows/elixir.yml` | Step 2, 7 |
| 10 | Verify all 47 tests pass | Step 7 |

---

## 8. Prohibitions

| # | Prohibition |
|----|------------|
| P1 | NEVER modify `pidlp.spec.exs` — this gate adds no new NIFs |
| P2 | NEVER modify `_generated/` files — they are auto-generated |
| P3 | NEVER link C tests against real `libpisock.a` — always use mocks |
| P4 | NEVER add C tests to Bundlex — use standalone Makefile |
| P5 | NEVER include `<erl_nif.h>` or Unifex headers in test files — tests must compile without Erlang/OTP headers |
| P6 | NEVER change NIF function signatures — only remove dead code and debug output from pidlp.c |
| P7 | NEVER skip the `pi_buffer_free` / `free_CalendarEvent` cleanup paths in tests — resource leaks are a NIF safety concern |
| P8 | NEVER test private Unifex internals (`_result_*` functions) — test business logic only |

---

## 9. Integration Points

| Point | Details |
|-------|---------|
| Build system | `c_src/Makefile` — `make test` target, independent of `mix compile` |
| CI | `.github/workflows/elixir.yml` — new step after pilot-link build |
| pidlp.c cleanup | Remove `printf` on lines 613, 618, 620-626; remove commented-out `map_repeat_type`/`map_day_of_month` (lines 73-172) |
| Future NIFs (#16) | Test harness must be extensible: add mock for `dlp_ReadRecordByIndex`, `dlp_ReadNextModifiedRec`, `dlp_ReadRecordById` by extending `pisock_mocks.c` |

---

## 10. Error Cases

| Error | Expected Behavior |
|-------|-------------------|
| `pi_socket` returns 0 | `pilot_connect` returns error with socket message |
| `pi_bind` returns <0 | `pilot_connect` returns errno-specific error, closes both sockets |
| `pi_listen` returns -1 | `pilot_connect` returns error, closes both sockets |
| `pi_accept_to` returns -1 | `pilot_connect` returns error, closes both sockets |
| `dlp_ReadSysInfo` returns <0 | `read_sysinfo` returns `{:error, result, message}` |
| `dlp_GetSysDateTime` returns <0 | `get_sys_date_time` returns `{:error, result, message}` |
| `dlp_ReadUserInfo` returns <0 | `read_user_info` returns `{:error, result, message}` |
| `dlp_WriteUserInfo` returns <0 | `write_user_info` returns `{:error, result, message}` |
| `pack_Appointment` returns -1 | `write_datebook_record` returns error, does NOT call `dlp_WriteRecord` |
| `pack_CalendarEvent` returns -1 | `write_calendar_record` frees CalendarEvent + buffer, returns error |
| `dlp_WriteRecord` returns <0 | `write_datebook_record`/`write_calendar_record` returns error |
| `malloc` returns NULL in `timehtm_list_to_tm_list` | Returns NULL (caller must handle) |
| `stat(/dev/pilot)` fails | `pilot_connect` returns error with `strerror(errno)` |

---

## 11. Done When

- [ ] C test harness exists at `c_src/palm_sync_4_mac/tests/` with Unity framework
- [ ] Mock pilot-link stubs at `c_src/palm_sync_4_mac/mocks/pisock_mocks.c`
- [ ] 47 test cases pass (11 helpers + 6 read + 11 write + 19 connection)
- [ ] `make test` runs from `c_src/` without real hardware
- [ ] Debug `printf` and dead code removed from `pidlp.c`
- [ ] Framework ready for 3 new read-record NIFs in #16
- [ ] CI step added to `elixir.yml`
