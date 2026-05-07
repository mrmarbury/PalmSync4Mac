# Context Brief — sync-from-palm

**Feature**: PalmSync4Mac #16 — Sync Datebook Appointments to Apple Calendar
**GitHub**: [mrmarbury/PalmSync4Mac#16](https://github.com/mrmarbury/PalmSync4Mac/issues/16)
**ADP Phase**: 2 (follows Phase 1: multi-device sync)
**Date**: 2026-05-07

---

## Feature Description

Enable reverse sync: Palm datebook entries that don't exist in Apple Calendar should be created as Apple Calendar events during sync. Currently sync is one-directional (Apple Calendar → Palm); Palm-only entries are lost.

---

## Hard Prerequisites (gates SPECIFY)

These gates must be complete before the SPECIFY stage begins. Gate A and Gate B are independent and can be worked in parallel. Gate C depends on Gate A.

### Gate A: Swift Tests in CI

**What**: Get `swift test` running in GitHub Actions on a macOS runner.

**Why it gates #16**: The #16 feature adds EventKit read operations to the Swift port (`ports/`). Without CI coverage, any Swift changes are untested until a manual device run. The Swift port already has 4 tests + `MockEventStore.swift` in `ports/Tests/`, and `Package.swift` has a test target configured — but they are not executed in CI. The current GitHub Actions workflow only runs Elixir tests.

**Current state**:
- Swift tests: `ports/Tests/EKCalendarInterfaceTests/EKCalendarInterfaceTests.swift` (4 tests)
- Mock: `ports/Tests/EKCalendarInterfaceTests/MockEventStore.swift`
- Package: `ports/Package.swift` with test target
- CI: Elixir only (no macOS runner, no `swift test`)

**Done when**: `swift test` runs in CI on every push/PR, passes, and blocks merges on failure.

### Gate B: C Tests with Mocked Device Calls

**What**: Create C-level unit tests for `pidlp.c` that mock the pilot-link API (`pi_*`, `dlp_*` calls) so NIF functions can be exercised without real hardware.

**Why it gates #16**: The #16 feature requires **3 new NIFs** (`dlp_ReadRecordByIndex`, `dlp_ReadNextModifiedRec`, `dlp_ReadRecordById`). Phase 1.5 showed 11 post-BUILD bugs found only during manual testing with a real Palm device — most of these would have been caught by C-level mock tests. Without C test infrastructure, new NIFs are untestable except on hardware.

**Current state**:
- C source: `c_src/palm_sync_4_mac/pidlp.c` (13 NIF functions, all call pilot-link APIs)
- C tests: **zero** — no C test framework, no mock headers, no test harness
- Elixir tests: 4 test files using `Patch` library to mock the NIF module at BEAM level (not C level)
- Test config: `config/test.exs` disables Palm sync supervisors entirely (NIFs crash without hardware)

**Device communication layer** (functions that need mocking):
- Connection: `pi_socket()`, `pi_bind()`, `pi_listen()`, `pi_accept_to()`, `pi_close()`
- DLP protocol: `dlp_OpenConduit()`, `dlp_OpenDB()`, `dlp_CloseDB()`, `dlp_EndOfSync()`
- DLP read: `dlp_ReadSysInfo()`, `dlp_GetSysDateTime()`, `dlp_ReadUserInfo()`
- DLP write: `dlp_WriteUserInfo()`, `dlp_WriteRecord()`
- Record packing: `pack_Appointment()`, `pack_CalendarEvent()`, `pi_buffer_new()`, `pi_buffer_free()`

**Priority test targets** (for the mock infrastructure):
1. Pure-data functions first (no mocking needed): `timehtm_to_tm`, `timehtm_list_to_tm_list`, `is_blank`
2. DLP read functions: `read_sysinfo`, `read_user_info`, `get_sys_date_time`
3. DLP write functions: `write_datebook_record`, `write_calendar_record`, `write_user_info`
4. Connection flow: `pilot_connect`, `pilot_disconnect` (most complex, most valuable)

**Done when**: C test harness exists with mock pilot-link stubs, covers existing NIF functions with meaningful assertions, runs in CI (or at least locally via `make test-c`), and the framework is ready for adding the 3 new NIFs in #16.

### Gate C: Swift Port ↔ Elixir Integration Test

**What**: Automated integration test that verifies the full round-trip: Elixir app starts → Swift port receives `get_events` command → events land in Ash SQLite via `CalendarEvent.create_or_update`.

**Why it gates #16**: Phase 2 adds EventKit read operations and a `sync_from_palm` flow that writes Palm records to Apple Calendar via the Swift port. The Swift port is currently only tested in isolation (unit tests with MockEventStore) — there is no automated test that the Erlang port protocol (length-prefixed JSON over stdin/stdout) works end-to-end with the Elixir application. A round-trip integration test catches port protocol bugs, encoding issues, and supervisor wiring problems that unit tests miss.

**Current state**:
- Swift unit tests: 14 tests, all use MockEventStore (no Elixir involvement)
- Elixir tests: 49 tests, Swift port binary not started in test env (`config/test.exs` sets `start_event_kit_sup: false`)
- No test exists that starts the Swift port as an Erlang port, sends a command, and verifies the result in the DB

**Approach**:
1. Create a test fixture that seeds a known Apple Calendar event (or mock the Swift port's response at the port protocol level)
2. Start the Elixir app with the Swift port enabled in test env
3. Trigger the `get_events` interval (or call directly)
4. Assert that `CalendarEvent` rows appear in the DB with the expected fields
5. Clean up test data after assertion

**Done when**: Integration test runs in `mix test`, verifies Swift port → Elixir → DB round-trip, passes without real hardware or calendar access.

---

## Key Constraints

From LEARNINGS.md, Decisions.md, and [[wiki/elixir/palmsync4mac-patterns]]:

| ID | Constraint |
|----|-----------|
| D1 | `PilotUser.viewerID` is `unsigned long` (`0x50534D`), not string |
| D7 | `rec_id` lifecycle: 0 = new, join table owns mapping |
| D10 | Ash SQLite uses `ash_domains`, not `ecto_repos` |
| — | NIF safety: recoverable failures return `{:error, _}`; process crash = unrecoverable |
| — | Unifex struct alignment: missing fields in spec → crash after NIF rebuild |
| — | Conditional supervisor startup: Swift port binary doesn't exist on CI — needs `Application.get_env` guards |
| — | Build system: pilot-link compiled from source in CI, `PILOT_LINK_INCLUDE` env var required |
| — | `inject_palm_user_id/2` only injects `palm_user_id` as LAST arg into sync_queue |

---

## Existing Test Coverage

| Layer | Tests | Gap |
|-------|-------|-----|
| Swift (`ports/`) | 14 tests + MockEventStore | ✅ In CI (Gate A done) |
| Swift ↔ Elixir | 0 | No integration test — Gate C |
| C (`c_src/`) | 0 | No unit tests at all — Gate B |
| Elixir | 4 test files, Patch-based mocks | Only Elixir-level; NIFs fully mocked away |

---

## Codebase Boundaries for #16

| Boundary | File(s) | Change required |
|----------|---------|-----------------|
| C NIF layer | `c_src/.../pidlp.c`, `pidlp.spec.exs` | Add 3 new read-record functions + `unpack_Appointment` |
| Elixir NIF module | `lib/.../comms/pidlp.ex` | Add 3 new function calls + Elixir-side types |
| Swift port | `ports/Sources/` | Add EventKit read operations (fetch events from calendar) |
| Sync workers | `lib/.../pilot/sync_worker/` | Add `sync_from_palm` flow (read Palm records → create Apple Calendar events) |
| Sync status | `lib/.../ek_calendar_datebook_sync_status.ex` | Update for bidirectional direction tracking |

---

## Out of Scope

- Deletion propagation (#17) — separate story
- EKCalendarInterface shutdown on app exit (#18) — separate story
- Mutation testing (Phase 3 goal)
- Multi-agent verification (Phase 3 goal)

---

## Risk Factors

| Risk | Mitigation |
|------|-----------|
| pilot-link API stability | `dlp_ReadRecordByIndex` etc. are documented but edge cases around modified records need investigation during SPECIFY |
| EventKit permissions | Reading calendar events requires different entitlements than writing — verify during SPECIFY |
| Data conflicts | Palm entries that already exist in Apple Calendar (by title/time) need dedup logic — define in SPECIFY |
| C mock fidelity | Mock stubs must accurately represent pilot-link return types and error codes — validate against pilot-link source |

---

## References

- **ADP Transition**: `Projects/palmSync4Mac/ADP Transition.md` (vault)
- **Story file**: `Projects/palmSync4Mac/Stories/Sync Datebook Appointments to Apple Calendar.md` (vault)
- **Phase 1 backlog**: `docs/contracts/multi-device-sync/backlog.md` (repo) — item #2
- **Phase 1 contracts**: `docs/contracts/multi-device-sync/` (repo) — reference for contract style
- **Wiki patterns**: [[wiki/elixir/palmsync4mac-patterns]]
- **Wiki ADP**: [[wiki/ai-engineering/agentic-development-protocol]]
- **Existing design doc**: `docs/design/calendar_event_design.md` (repo) — covers bidirectional architecture
