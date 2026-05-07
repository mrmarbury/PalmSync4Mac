# Context Brief — C NIF Tests with Mocked Device Calls

**Feature**: Add C unit tests with mocked device calls for pidlp.c
**GitHub**: [mrmarbury/PalmSync4Mac#21](https://github.com/mrmarbury/PalmSync4Mac/issues/21)
**ADP Phase**: 2 prerequisite (Gate B for sync-from-palm #16)
**Date**: 2026-05-07

---

## Feature Description

Create C-level unit tests for `pidlp.c` that mock the pilot-link API (`pi_*`, `dlp_*` calls) so NIF functions can be exercised without real hardware. Currently there are zero C tests — all NIF testing is done from Elixir using Patch mocks that bypass the C layer entirely.

---

## Why This Gates #16

Phase 2 (sync-from-palm) requires **3 new NIFs**: `dlp_ReadRecordByIndex`, `dlp_ReadNextModifiedRec`, `dlp_ReadRecordById`. Phase 1.5 showed 11 post-BUILD bugs found only during manual device testing — most would have been caught by C-level mock tests. Without C test infrastructure, new NIFs are untestable except on real hardware.

---

## Current State

| Aspect | Status |
|--------|--------|
| C source | `c_src/palm_sync_4_mac/pidlp.c` — 13 NIF functions |
| C tests | **Zero** — no framework, no mocks, no harness |
| Elixir tests | 4 files using Patch to mock `PalmSync4Mac.Comms.Pidlp` at BEAM level |
| Test config | `config/test.exs` disables Palm sync supervisors (NIFs crash without hardware) |
| Unifex spec | `c_src/palm_sync_4_mac/pidlp.spec.exs` — defines 4 custom types + 13 NIF specs |
| Generated code | `c_src/palm_sync_4_mac/_generated/nif/pidlp.c` — auto-generated NIF glue (~1400 lines) |

### The 13 NIF Functions

| Function | pilot-link API calls | Device I/O? |
|----------|---------------------|-------------|
| `pilot_connect` | `pi_socket`, `pi_bind`, `pi_listen`, `pi_accept_to`, `dlp_OpenConduit` | YES |
| `pilot_disconnect` | `pi_close` (x2) | YES |
| `open_conduit` | `dlp_OpenConduit` | YES |
| `open_db` | `dlp_OpenDB` | YES |
| `close_db` | `dlp_CloseDB` | YES |
| `end_of_sync` | `dlp_EndOfSync` | YES |
| `read_sysinfo` | `dlp_ReadSysInfo` | YES |
| `get_sys_date_time` | `dlp_GetSysDateTime` | YES |
| `set_sys_date_time` | `dlp_SetSysDateTime` | YES |
| `read_user_info` | `dlp_ReadUserInfo` | YES |
| `write_user_info` | `dlp_WriteUserInfo` | YES |
| `write_datebook_record` | `pack_Appointment` + `dlp_WriteRecord` | YES |
| `write_calendar_record` | `pack_CalendarEvent` + `dlp_WriteRecord` | YES |

**Every single function hits real pilot-link calls requiring hardware.**

---

## Device Communication Layer (functions to mock)

### Connection layer
- `pi_socket()`, `pi_bind()`, `pi_listen()`, `pi_accept_to()`, `pi_close()`

### DLP protocol layer
- `dlp_OpenConduit()`, `dlp_OpenDB()`, `dlp_CloseDB()`, `dlp_EndOfSync()`

### DLP read layer
- `dlp_ReadSysInfo()`, `dlp_GetSysDateTime()`, `dlp_ReadUserInfo()`

### DLP write layer
- `dlp_WriteUserInfo()`, `dlp_WriteRecord()`

### Record packing layer
- `pack_Appointment()`, `pack_CalendarEvent()`, `pi_buffer_new()`, `pi_buffer_free()`

---

## Constraints

| ID | Constraint |
|----|-----------|
| — | NIF safety: recoverable failures return `{:error, _}`; process crash = unrecoverable |
| — | Unifex struct alignment: missing fields in spec → crash after NIF rebuild |
| — | pilot-link compiled from source in CI, `PILOT_LINK_INCLUDE` env var required |
| D1 | `PilotUser.viewerID` is `unsigned long` (`0x50534D`), not string |
| D7 | `rec_id` lifecycle: 0 = new, join table owns mapping |
| — | See vault LEARNINGS.md and wiki/elixir/palmsync4mac-patterns for full list |

---

## Priority Test Targets

1. **Pure-data functions** (no mocking needed): `timehtm_to_tm`, `timehtm_list_to_tm_list`, `is_blank`
2. **DLP read functions**: `read_sysinfo`, `read_user_info`, `get_sys_date_time`
3. **DLP write functions**: `write_datebook_record`, `write_calendar_record`, `write_user_info`
4. **Connection flow**: `pilot_connect`, `pilot_disconnect` (most complex, most valuable)

---

## Approach Options

### Option A: Mock headers with function pointers
Create `c_src/mocks/` with stub headers for `pi-socket.h`, `pi-dlp.h`, `pi-datebook.h`, `pi-calendar.h`. Each stub defines the same function signatures but with configurable function pointers or static return values. Compile `pidlp.c` against mocks instead of real pilot-link.

### Option B: Compile-time interface extraction
Refactor `pidlp.c` to call device functions through an internal interface struct (function pointer table). Production code gets the real pilot-link table; test code gets a mock table. More invasive but cleaner long-term.

### Option C: Link-time substitution
Compile `pidlp.c` normally but link against a mock `libpisock` instead of the real one at test time. Requires building a mock `.c` file implementing all pilot-link functions.

**Recommendation**: Option A (mock headers) — least invasive, fastest to implement, sufficient for the goal.

---

## Scope

### In Scope

1. C test framework setup (Unity or simple assert-based)
2. Mock pilot-link headers in `c_src/mocks/`
3. Tests for existing 13 NIF functions (prioritized list above)
4. Build integration (`Makefile` target or similar)
5. Tests runnable without real hardware

### Out of Scope

- Writing the 3 new NIFs for #16 (that's Phase 2 BUILD)
- Elixir-side test changes
- Running C tests in CI (nice-to-have, can be added later)

---

## Done When

- C test harness exists with mock pilot-link stubs
- Existing NIF functions have meaningful test coverage
- Framework is ready for adding the 3 new NIFs in #16
- Tests can run without real hardware

---

## References

- **Blocking**: [mrmarbury/PalmSync4Mac#16](https://github.com/mrmarbury/PalmSync4Mac/issues/16)
- **Sync-from-palm context brief**: `docs/contracts/sync-from-palm/context-brief.md`
- **ADP Transition**: vault `Projects/palmSync4Mac/ADP Transition.md` Phase 2
- **Patterns**: vault `wiki/elixir/palmsync4mac-patterns.md`
- **NIF spec**: `c_src/palm_sync_4_mac/pidlp.spec.exs`
