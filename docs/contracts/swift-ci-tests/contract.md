## Contract — Swift Test Sanitization & CI

> **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key). NOT the Palm device's integer `user_id`. All contracts reference the UUID.

### Purpose

Fix the structurally broken Swift test suite so that existing and new tests actually exercise the production code path through a mockable `EKEventStore`. Then add missing test coverage for untested production functions. Finally, run `swift test` in GitHub Actions CI on a macOS runner.

### Problem Statement

All 4 existing Swift tests are **structurally broken**: they create `MockEventStore` instances that are never used by the production code. The root cause is `let store = EKEventStore()` at file scope — `getCalendarEvents` and `getSelectedCalendars` use this global immutable, making injection impossible. Tests pass by coincidence (real EKEventStore returns empty data on CI), not by correctness.

Evidence: Swift compiler warnings on every `var store = mockStore` — "initialization of variable 'store' was never used" — confirming local shadowing does nothing.

### Inputs → Outputs

| Change | Type | Constraint |
|--------|------|------------|
| `let store` → `var store` in Main.swift | minimal refactor | Zero call-site changes in production code |
| Fix 4 existing tests | test repair | Tests must exercise production path through injected mock |
| Add missing tests | new tests | Cover `getSelectedCalendars`, `sendMessage`, `readMessage`, command dispatch, error paths |
| Add macOS CI job | CI config | `swift test` runs on every push/PR, blocks merges on failure |

### Invariants (MUST ALWAYS be true)

1. **Mock injection works**: Changing `store` to a `MockEventStore` in `setUp` causes `getCalendarEvents` and `getSelectedCalendars` to use the mock — verified by tests that assert mock-controlled behavior (e.g., access denied, calendar not found)
2. **Production code unchanged in behavior**: `var store = EKEventStore()` as the initial value preserves identical runtime behavior. No function signatures change, no new parameters added, no protocols introduced
3. **Every test restores `store` in `tearDown`**: Global state mutation must be cleaned up to prevent test interdependence. `tearDown` sets `store = EKEventStore()`
4. **Tests must not require EventKit permissions or real calendars**: All tests use `MockEventStore` or its subclasses. No system permission dialogs, no real calendar data. Tests must pass on a fresh macOS runner with no user interaction
5. **CI job runs on `macos-latest`**: Swift compilation + EventKit framework require macOS. Ubuntu cannot run these tests

### Test Coverage Requirements

#### Fixed existing tests (4)

| Test | What it must actually verify |
|------|------------------------------|
| `testAccessDenied` | `MockEventStore.shouldGrantAccess = false` → `getCalendarEvents` outputs `access_denied` error. Mock is actually used (not coincidental) |
| `testCalendarNotFound` | `MockEventStore` with empty `mockCalendars` → `getCalendarEvents` with non-matching calendar name outputs `calendar_not_found` |
| `testCalendarFoundNoEvents` | `MockEventStore` with calendar but `events(matching:)` returning `[]` → output has empty events array and correct `request_id` |
| `testCalendarFoundWithEvents` | `MockEventStore` subclass returning mock events → output contains those events with correct fields (`apple_event_id`, `title`, `request_id`) |

#### New tests (minimum)

| Test | Function tested | What it verifies |
|------|-----------------|------------------|
| `testGetSelectedCalendarsAllCalendars` | `getSelectedCalendars(named:store:)` | `nil` calendar name → returns `nil` (all calendars) |
| `testGetSelectedCalendarsByName` | `getSelectedCalendars(named:store:)` | Matching name → returns matching calendars |
| `testGetSelectedCalendarsNotFound` | `getSelectedCalendars(named:store:)` | Non-matching name → returns `nil` |
| `testSendMessageLengthPrefix` | `sendMessage(_:to:)` | Output has 4-byte big-endian length prefix followed by UTF-8 JSON data |
| `testReadMessageValidJSON` | `readMessage(from:)` | 4-byte length prefix + valid JSON → returns parsed `[String: Any]` |
| `testReadMessageInvalidLength` | `readMessage(from:)` | Truncated length header (< 4 bytes) → returns `nil` |
| `testReadMessageInvalidJSON` | `readMessage(from:)` | Valid length prefix + invalid JSON → returns `nil`, error written to stderr |
| `testReadMessageTruncatedBody` | `readMessage(from:)` | Length says N bytes, but fewer available → returns `nil` |
| `testUnknownCommand` | `startMainLoop` dispatch | Unknown command → `unknown_command` error in output |
| `testInvalidMessageFormat` | `startMainLoop` dispatch | Missing `command` field → `invalid_message_format` error in output |

#### Test infrastructure

| Item | Detail |
|------|--------|
| `MockEventStore` | Keep existing subclass. Add `mockEvents: [EKEvent]` property so `events(matching:)` can return configurable events without creating a new subclass each time |
| `captureOutput` | Keep existing helper for stdout capture. Add `captureError` variant for stderr |
| `captureInput` | New helper: creates a `Pipe`, writes a length-prefixed JSON message to its write end, returns the read end as `FileHandle` for `readMessage(from:)` testing |

### Error cases

| Condition | Behavior |
|-----------|----------|
| EKEventStore access denied | `getCalendarEvents` outputs `{"error": "access_denied", "request_id": N}` |
| Calendar name not found | `getCalendarEvents` outputs `{"error": "calendar_not_found", "request_id": N}` |
| Unknown command in message | `startMainLoop` outputs `{"error": "unknown_command", "request_id": N}` |
| Message missing `command` field | `startMainLoop` outputs `{"error": "invalid_message_format"}` |
| JSON serialization failure | `getCalendarEvents` outputs `{"error": "json_serialization_failed", "request_id": N}` |
| JSON encoding failure | `getCalendarEvents` outputs `{"error": "json_encoding_failed", "request_id": N}` |
| Invalid JSON in `readMessage` | Returns `nil`, writes error to stderr |
| Truncated input in `readMessage` | Returns `nil` |

### Integration points

- Depends on: `ports/Sources/EKCalendarInterface/Main.swift` (production code — `var store` change)
- Depends on: `ports/Tests/EKCalendarInterfaceTests/MockEventStore.swift` (mock enhancement)
- Depends on: `ports/Tests/EKCalendarInterfaceTests/EKCalendarInterfaceTests.swift` (test fixes + additions)
- Depends on: `.github/workflows/` (new or extended CI workflow)
- Modifies: `ports/Package.swift` — no changes needed (test target already configured)
- Modifies: Elixir codebase — no changes

### Prohibitions (MUST NEVER)

1. NEVER add function parameters for `EKEventStore` injection — the `var store` global is the injection point. Protocol-based DI or parameter passing is overengineering for an Erlang port process with a single event store
2. NEVER introduce a new Swift package dependency — the port must stay zero-dependency
3. NEVER test against real EventKit data — all tests use mocks, no system permission dialogs
4. NEVER change production `getCalendarEvents` or `getSelectedCalendars` signatures — they are called from `startMainLoop` and the Elixir port
5. NEVER combine Elixir CI and Swift CI in one job — different OS runners (Ubuntu vs macOS), different build tools
6. NEVER skip `tearDown` store restoration — global state leaks between tests

### CI Job Specification

```yaml
# .github/workflows/swift.yml
name: Swift CI
on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]
jobs:
  test:
    name: Swift Test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Swift tests
        run: cd ports && swift test
```

No caching needed (Swift build is fast, no external dependencies). No pilot-link, no Elixir — this job is Swift-only.

### Build Order

1. Change `let store` → `var store` in Main.swift
2. Enhance `MockEventStore` with `mockEvents` property
3. Fix 4 existing tests (remove local shadowing, use global `store` assignment)
4. Add test infrastructure helpers (`captureError`, `captureInput`)
5. Add 10 new tests
6. Add `.github/workflows/swift.yml`
7. Verify: `swift test` passes locally, all tests exercise production path

### Done When

- `let store` → `var store` in Main.swift (only production code change)
- All 4 existing tests fixed — each exercises production path through mock
- ≥10 new tests added covering `getSelectedCalendars`, `sendMessage`, `readMessage`, command dispatch
- `swift test` passes locally with zero warnings
- `swift test` passes in GitHub Actions on `macos-latest`
- CI job blocks merges on failure
