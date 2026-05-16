# Context Brief — Swift Port ↔ Elixir Integration Test

**Feature**: Add Swift port ↔ Elixir integration test
**GitHub**: [mrmarbury/PalmSync4Mac#22](https://github.com/mrmarbury/PalmSync4Mac/issues/22)
**ADP Phase**: 2 prerequisite (Gate C for sync-from-palm #16)
**Depends on**: Gate A (#20) — complete
**Date**: 2026-05-07

---

## Feature Description

Automated integration test that verifies the full round-trip: Elixir app starts → Swift port receives `get_events` command → events land in Ash SQLite via `CalendarEvent.create_or_update`. The Swift port is currently only tested in isolation — there is no automated test that the Erlang port protocol (length-prefixed JSON over stdin/stdout) works end-to-end.

---

## Why This Gates #16

Phase 2 (sync-from-palm) adds EventKit read operations and a `sync_from_palm` flow that writes Palm records to Apple Calendar via the Swift port. Without integration coverage, port protocol bugs, encoding issues, and supervisor wiring problems are invisible until manual testing.

---

## Current State

| Aspect | Status |
|--------|--------|
| Swift unit tests | 14 tests, all use MockEventStore (no Elixir involvement) ✅ |
| Elixir tests | 49 tests, Swift port binary not started in test env (`start_event_kit_sup: false`) |
| Integration tests | **Zero** — no test starts the Swift port as an Erlang port, sends a command, and verifies DB result |

---

## Approach

1. Create a test fixture that seeds a known Apple Calendar event (or mock the Swift port's response at the port protocol level)
2. Start the Elixir app with the Swift port enabled in test env
3. Trigger the `get_events` interval (or call directly)
4. Assert that `CalendarEvent` rows appear in the DB with the expected fields
5. Clean up test data after assertion

---

## Constraints

- **Conditional supervisor startup**: `EventKitSup` is guarded by `Application.get_env(:palm_sync_4_mac, :start_event_kit_sup, true)`. Test env currently sets `false`. Integration test needs `true` + a working Swift binary.
- **Swift binary must exist**: The Swift port is compiled via `swift build` in `ports/`. The binary must be at the expected path before the Elixir app starts.
- **No real calendar access**: Test must work without real Apple Calendar permissions. Mock at the port protocol level or use MockEventStore through the Swift binary.
- **Port protocol**: Length-prefixed JSON over stdin/stdout. See `PortHandler` in Elixir and `sendMessage`/`processMessage` in Swift.

---

## Scope

### In Scope

1. One integration test verifying Swift port → Elixir → DB round-trip
2. Test runs in `mix test`
3. Passes without real hardware or calendar access

### Out of Scope

- Swift unit tests (Gate A — done)
- C NIF tests (Gate B)
- sync-from-palm implementation (#16)

---

## Done When

- Integration test runs in `mix test`
- Verifies Swift port → Elixir → DB round-trip
- Passes without real hardware or calendar access

---

## References

- **Blocking**: [mrmarbury/PalmSync4Mac#16](https://github.com/mrmarbury/PalmSync4Mac/issues/16)
- **Depends on**: [mrmarbury/PalmSync4Mac#20](https://github.com/mrmarbury/PalmSync4Mac/issues/20) (Gate A — complete)
- **Sync-from-palm context brief**: `docs/contracts/sync-from-palm/context-brief.md`
- **ADP Transition**: vault `Projects/palmSync4Mac/ADP Transition.md` Phase 2
- **Patterns**: vault `wiki/elixir/palmsync4mac-patterns.md` — Swift/Erlang port patterns
