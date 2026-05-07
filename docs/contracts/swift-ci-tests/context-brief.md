# Context Brief — Swift CI Tests

**Feature**: Add Swift tests to GitHub Actions CI
**GitHub**: [mrmarbury/PalmSync4Mac#20](https://github.com/mrmarbury/PalmSync4Mac/issues/20)
**ADP Phase**: 2 prerequisite (Gate A for sync-from-palm #16)
**Date**: 2026-05-07

---

## Feature Description

Get `swift test` running in GitHub Actions on a macOS runner. The Swift port already has tests and a test target — they just aren't executed in CI.

---

## Why This Gates #16

Phase 2 (sync-from-palm) adds EventKit read operations to the Swift port. Without CI coverage, Swift changes are untested until manual device run. The existing 4 tests + MockEventStore provide a baseline — getting them into CI ensures regressions are caught before merge.

---

## Current State

| Aspect | Status |
|--------|--------|
| Swift tests | 4 tests in `ports/Tests/EKCalendarInterfaceTests/` |
| Mock | `ports/Tests/EKCalendarInterfaceTests/MockEventStore.swift` |
| Package.swift | Test target `EKCalendarInterfaceTests` configured |
| CI | Elixir only — no macOS runner, no `swift test` |
| Test config | `config/test.exs` disables `start_event_kit_sup` (no hardware needed) |

### Existing Swift Test Cases

1. Access denied — EventKit permission denied
2. Calendar not found — target calendar doesn't exist
3. No events — empty calendar
4. With events — calendar contains events

---

## Constraints

- **macOS runner required**: Swift compilation + EventKit needs macOS. GitHub Actions `macos-latest` runner.
- **Conditional supervisor startup**: Swift port binary doesn't exist on CI by default. `Application.get_env` guards in Elixir prevent crashes — but Swift test runs independently in `ports/`.
- **No hardware dependency**: MockEventStore replaces real EventKit — tests should pass without any Palm device or calendar access.

---

## Scope

### In Scope

1. Add macOS runner job to `.github/workflows/`
2. Run `swift test` in `ports/` directory
3. Ensure job runs on every push/PR
4. Job blocks merges on failure

### Out of Scope

- Writing additional Swift tests (only get existing tests into CI)
- EventKit read operations (that's #16)
- Elixir-side changes

---

## Done When

- `swift test` runs in CI on every push/PR
- All 4 existing Swift tests pass
- CI blocks merges on Swift test failure

---

## References

- **Blocking**: [mrmarbury/PalmSync4Mac#16](https://github.com/mrmarbury/PalmSync4Mac/issues/16)
- **Sync-from-palm context brief**: `docs/contracts/sync-from-palm/context-brief.md`
- **ADP Transition**: vault `Projects/palmSync4Mac/ADP Transition.md` Phase 2
