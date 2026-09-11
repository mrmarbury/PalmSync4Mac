# Post-BUILD Code Review — SysInfoWorker Infrastructure (Gate D-1)

> **ADP Stage**: Post-BUILD Review
> **Date**: 2026-06-29
> **PR**: [mrmarbury/PalmSync4Mac#28](https://github.com/mrmarbury/PalmSync4Mac/pull/28)
> **Branch**: `27-gate-d-1-sysinfoworker-infrastructure-struct-helper-pre-sync-worker-mainworker-context-injection`
> **Contract**: [contract.md](./contract.md)
> **Reviewer**: Sisyphus (agentic)

---

## Verification Summary

| Check | Result |
|-------|--------|
| `mix test` | 67 tests, 0 failures |
| `mix format --check-formatted` | PASS |
| `mix credo --strict` | 0 warnings (11 pre-existing design suggestions, all [D] low priority) |
| `mix dialyzer` | 1 pre-existing warning (`datebook_appointment.ex:112` unknown_type — unrelated to this branch) |
| Contract invariants I1-I9 | All verified by tests |
| Contract §12 Review Findings | All 5 issues resolved |
| File structure | Matches contract §3 exactly |
| `pidlp.spec.exs` | Updated to full module path (Issue 1 resolved) |
| `sync_workers.ex` move | Git rename R092, old file deleted, no stale references |

---

## Findings

### 🟡 Gap 1: Empty `pre_sync_queue` bypasses validation (logic bug) — RESOLVED

**Location**: `lib/palmsync4mac/pilot/sync_worker/main_worker.ex:168`

**Code**:
```elixir
defp run_pre_sync([], _client_sd), do: {:ok, %{palm_user_id: nil, sys_info: nil}}
```

**Problem**: This clause returns `{:ok, %{palm_user_id: nil, sys_info: nil}}` directly, bypassing `validate_pre_sync_result/1`. An empty `pre_sync_queue` would inject `nil` values into sync queue MFAs instead of failing fast.

This contradicts invariant I4: "Pre-sync fails fast if either UserInfoWorker or SysInfoWorker fails." An empty queue means neither ran — that should also be fatal. The contract's `validate_pre_sync_result/1` was designed to catch missing `palm_user_id`/`sys_info`, but the empty-list clause short-circuits it.

**Impact**: Unreachable in current usage (`sync_test.ex` always includes both UserInfoWorker and SysInfoWorker in `pre_sync_queue`). However, the logic is incorrect and could cause silent nil injection if the queue is ever empty.

**Research — new device scenario**: Confirmed this is NOT a new-device edge case. `palm_user_id` is always an Ash UUID (`uuid_primary_key` on `PalmUser` resource), decoupled from the Palm device's integer `user_id`. A new device reports `user_id=0` from pilot-link, but `UserInfoHelper.update_username/2` calls `generate_random_string()` when username is blank, so `write_to_db/1` always returns a valid UUID. The `nil` case can only occur if `pre_sync_queue` is empty (UserInfoWorker never ran).

**Resolution**: Changed `run_pre_sync([], _)` to return `{:error, :pre_sync_not_configured}` — a distinct error atom that accurately describes the condition (no pre-sync workers ran, configuration error). Amended contract §6 with the new error case. The original proposed fix (routing through `validate_pre_sync_result`) was rejected because `:palm_user_id_missing` is misleading when the queue was empty — a different failure mode than "a worker ran but returned nil".

Added test: "pre-sync fails with :pre_sync_not_configured when queue is empty" — verifies sync_queue is skipped (canary not called) and post_sync still runs for protocol cleanup. 3 existing tests that omitted `pre_sync_queue` were fixed to include it.

---

### 🟡 Gap 2: Test name contradicts assertion (misleading) — RESOLVED

**Location**: `test/palmsync4mac/pilot/sync_worker/main_worker_test.exs:543-550`

**Code**:
```elixir
test "post-sync queue MFAs are unchanged by inject_sync_context" do
  post_mfas = [{PostModule, :post_func, []}]
  ...
  result = MainWorker.inject_sync_context(post_mfas, "uuid", sys_info)
  assert result != post_mfas  # ← asserts INEQUALITY
end
```

**Problem**: The test name says "post-sync queue MFAs are unchanged" but the assertion `result != post_mfas` proves the opposite — injection DID happen (args were appended). The test actually verifies that `inject_sync_context` modifies all MFAs passed to it, not that post_sync is protected.

The real protection for invariant I5 (no injection into `post_sync`) is in `handle_info(:sync)` at line 110:
```elixir
sync_queue = inject_sync_context(state.sync_queue, palm_user_id, sys_info)
full_queue = sync_queue ++ state.post_sync_queue
```
`inject_sync_context` is only called on `state.sync_queue`, never on `post_sync_queue`. But no test verifies this integration-level invariant.

**Resolution**: Replaced the misleading unit test with an integration test: "post-sync queue MFAs receive no injected palm_user_id or sys_info". The new test calls `handle_info(:sync, ...)` with a populated `post_sync_queue` containing a spy MFA. The spy takes zero args (correct for post_sync). If injection had occurred, the MFA call would crash with arity mismatch. The test verifies the spy is called with zero args — proving I5 holds at the integration boundary where the protection actually lives.

---

### 🟢 Gap 3: `import` vs `alias` for helper (informational)

**Location**: `lib/palmsync4mac/pilot/sync_worker/sys_info_worker.ex:13`

```elixir
import PalmSync4Mac.Pilot.Helper.SysInfo.SysInfoHelper
```

`UserInfoWorker` uses the same `import` pattern (`user_info_worker.ex:10`). This is consistent with the existing codebase. No action needed — noted for awareness only. If the codebase later moves away from `import` in workers, both should change together.

---

### 🟢 Gap 4: No explicit test for `:ok` skip path in accumulator (minor) — RESOLVED

The contract §4.4 specifies: `:ok` or `{:ok, _}` (non-matching) → skip, continue without updating accumulator. The `run_pre_sync` tests cover error paths and missing-value paths, but no test explicitly verifies that a pre-sync MFA returning `:ok` (like `MiscWorker.time_sync`) is correctly skipped while subsequent MFAs still populate the accumulator.

The `ExecuteTest3` integration test includes pre_sync MFAs that all return `{:ok, value}`, so the `:ok` → skip path in `accumulate_pre_sync_result/3` is exercised only indirectly. A test with `[{Misc, :time_sync, []}, {UserInfoWorker, :pre_sync, []}, {SysInfoWorker, :pre_sync, []}]` would explicitly verify the skip behavior.

**Resolution**: Added test ":ok return from pre-sync MFA is skipped, accumulator still populated" in the "run_pre_sync — map accumulator validation" describe block. Uses a fake module (`ExecuteTestOkSkip`) returning bare `:ok`, placed before `ExecuteTest3.pre_func` and `ExecuteTest3.sys_info_pre_func` in the pre_sync_queue. Verifies: (1) the `:ok` MFA was called, (2) sync_queue MFA received valid `palm_user_id` and `sys_info` from subsequent MFAs — proving the accumulator was not corrupted by the `:ok` return. MiscWorker test coverage will be addressed in a separate gate (see `docs/contracts/misc-worker/`).

---

## Verdict

Implementation quality is high. Contract adherence is strong — all 9 invariants covered, all 5 SPECIFY-stage review issues resolved, file structure matches exactly, rename/move done cleanly via git rename.

All actionable gaps resolved:
- Gap 1 (logic bug): Fixed — `run_pre_sync([], _)` now returns `{:error, :pre_sync_not_configured}`. Contract §6 amended.
- Gap 2 (misleading test): Fixed — replaced with I5 integration test verifying post_sync MFAs receive zero injected args.
- Gap 4 (`:ok` skip path): Fixed — explicit test verifying `:ok` return is skipped while accumulator is still populated.

Gap 3 (informational, no action). MiscWorker test coverage deferred to a separate gate.
