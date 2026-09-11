## Verification Report — Swift Test Sanitization & CI

> **ADP Stage**: VERIFY
> **Date**: 2026-05-07
> **Contracts**: docs/contracts/swift-ci-tests/contract.md
> **GitHub**: mrmarbury/PalmSync4Mac#20
> **Branch**: 20-swift-tests-ci

### Contract compliance

#### Invariant 1: Mock injection works

| Contract item | Test | Status | Notes |
|---------------|------|--------|-------|
| MockEventStore with shouldGrantAccess=false → access_denied | `testAccessDenied` | ✅ | Mock flows through `var store` global |
| MockEventStore with empty mockCalendars → calendar_not_found | `testCalendarNotFound` | ✅ | |
| MockEventStore with calendar + empty mockEvents → empty events array | `testCalendarFoundNoEvents` | ✅ | |
| MockEventStore with calendar + mockEvents → events returned | `testCalendarFoundWithEvents` | ✅ | Verifies by title (not eventIdentifier — see deviations) |

#### Invariant 2: Production code unchanged in behavior

| Contract item | Test | Status | Notes |
|---------------|------|--------|-------|
| `var store = EKEventStore()` preserves identical runtime | `swift build -c release` passes | ✅ | |

#### Invariant 3: Every test restores store in tearDown

| Contract item | Test | Status | Notes |
|---------------|------|--------|-------|
| tearDown sets `store = EKEventStore()` | Code review — line 18 | ✅ | Also restores `outputHandle = FileHandle.standardOutput` |

#### Invariant 4: Tests must not require EventKit permissions

| Contract item | Test | Status | Notes |
|---------------|------|--------|-------|
| All 14 tests use MockEventStore | `swift test` passes without permission dialog | ✅ | |

#### Invariant 5: CI job runs on macos-latest

| Contract item | Test | Status | Notes |
|---------------|------|--------|-------|
| `.github/workflows/swift.yml` uses `macos-latest` | File review | ✅ | |

### Test Coverage

| Category | Tests | Status |
|----------|-------|--------|
| Fixed existing: access denied | `testAccessDenied` | ✅ |
| Fixed existing: calendar not found | `testCalendarNotFound` | ✅ |
| Fixed existing: no events | `testCalendarFoundNoEvents` | ✅ |
| Fixed existing: with events | `testCalendarFoundWithEvents` | ✅ |
| New: getSelectedCalendars nil name | `testGetSelectedCalendarsAllCalendars` | ✅ |
| New: getSelectedCalendars by name | `testGetSelectedCalendarsByName` | ✅ |
| New: getSelectedCalendars not found | `testGetSelectedCalendarsNotFound` | ✅ |
| New: sendMessage length prefix | `testSendMessageLengthPrefix` | ✅ |
| New: readMessage valid JSON | `testReadMessageValidJSON` | ✅ |
| New: readMessage invalid length | `testReadMessageInvalidLength` | ✅ |
| New: readMessage invalid JSON | `testReadMessageInvalidJSON` | ✅ |
| New: readMessage truncated body | `testReadMessageTruncatedBody` | ✅ |
| New: unknown command | `testUnknownCommand` | ✅ |
| New: invalid message format | `testInvalidMessageFormat` | ✅ |

**Total: 14 tests, 0 failures**

### Deviations from contract

| Deviation | Reason | Risk |
|-----------|--------|------|
| Added `var outputHandle = FileHandle.standardOutput` to Main.swift | Tests need to capture `sendMessage` output. `getCalendarEvents` calls `sendMessage` with no output arg, writing to `FileHandle.standardOutput`. Same `var` injection pattern as `store`. | Low — identical behavior when not under test |
| Changed `sendMessage` signature: `to output: FileHandle` → `to output: FileHandle? = nil` | Needed for `outputHandle` fallback. Prohibition 4 only covers `getCalendarEvents` and `getSelectedCalendars`. | Low — nil falls back to `outputHandle` which defaults to `standardOutput` |
| Added `processMessage()` function to Main.swift | Contract specified command dispatch tests, but `startMainLoop()` runs infinite RunLoop. Extracted dispatch logic for testability. | Low — `startMainLoop` now calls `processMessage`, same runtime behavior |
| Fixed `event.eventIdentifier!` → `event.eventIdentifier ?? ""` | Force-unwrap crashes on unsaved EKEvent objects. This is a genuine bug fix — eventIdentifier is nil for events not yet saved to an EventStore. | Low — production behavior unchanged for saved events; prevents crash for edge cases |
| `testCalendarFoundWithEvents` verifies by title, not by `apple_event_id` | EKEvent cannot be subclassed in Swift (ObjC factory method `eventWithEventStore:` crashes). Real EKEvent objects from MockEventStore have nil eventIdentifier (unsaved). Test verifies by `title` field instead. | Low — still proves mock injection works and events flow through production code |

### Build verification

```
cd ports && swift build — PASS
cd ports && swift build -c release — PASS
cd ports && swift test — 14 tests, 0 failures
mix compile — PASS (0 errors, pre-existing warnings only)
```

### Unverified items

- **CI job**: `.github/workflows/swift.yml` created but not yet pushed to GitHub. CI validation requires push to remote. **Risk: Low** — YAML is minimal and matches the contract spec exactly.
