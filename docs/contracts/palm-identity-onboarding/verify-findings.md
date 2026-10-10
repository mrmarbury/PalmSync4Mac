# VERIFY Findings & Pending Remediation Decision — palm-identity-onboarding

Status: **awaiting engineer decision** (2026-09-18 session ended here). VERIFY phase passed all three CCR reviews (Step 6 Alignment PASS, Step 7 Safety PASS, Step 8 Regression PASS — gates independently re-run and matched). Implementation is committed as wip `3c2f74a` on `32-palm-identity-onboarding`.

## Resolved by engineer decision
- **M1 — unique index aborts on bug-era DBs**: no prod DB exists; the policy is **drop and recreate the DB** (delete dev.sqlite + wal/shm). Pending small item: one README line tying the "UNIQUE constraint failed" migration error to that procedure.
- Migration formatting LOW: re-verified `mix format --check-formatted` CLEAN — reviewer's claim was stale, no action.

## Awaiting decision (presented with full code context in session, summarized here)

### 1. MEDIUM — partial join-reset reports success (`user_info_helper.ex:311-349`)
`reset_sync_status_rows/1` swallows individual `Ash.destroy` failures (`Enum.each(rows, &destroy_sync_status_row/1)` → always `:ok`). A partially-failed RE_ONBOARD reset reports success → sync proceeds → the wiped device silently never receives the events whose join rows survived — the exact failure RE_ONBOARD exists to prevent. The worker (`user_info_worker.ex:245-250`) already has an error branch waiting for it. Proposed fix: collect failures → `{:error, :join_row_reset_incomplete}` when any; + contract error-table row + test. ~10 lines. (Recommended.)

### 2. LOW (flagged by Steps 6+8 independently) — pre-fix bug entry point still alive (`user_info_helper.ex:366-369`)
`update_username/2`'s nameless+nil branch mints an **unchecked** `generate_random_string()` — the exact pre-fix bug shape. Unreachable from the state machine (which generates unique names first), but public and blessed by `user_info_helper_test.exs:178-192`. Proposed fix: delete the branch, require the explicit name argument, update the test. ~5 lines. (Recommended.)

### 3. LOW — whitespace-only explicit name forks identity
`validate_username(" ")` passes but `nameless?(" ")` is true → device onboarded as `" "` counts as nameless next sync → second random name → duplicate row. Proposed fix: reject blank names in `validate_username/1`. 2 lines + test. (Recommended.)

### 4. LOW — test polish (2 items)
- `user_info_onboarding_test.exs:405`: vacuous assertion (`successful_sync_date == 0 || >= 0` — always true). Delete or assert concrete value.
- Core regression test comment claims "one row, one join row" but never asserts join count. Add the assert.

### 5. Optional — RE_ONBOARD breadcrumb
`re_onboard/3` gives no hint that a typed name matching an existing row may belong to a different physical device. One warning line (with row's last_sync_date context; a user_id-mismatch warning would be noise since wiped devices legitimately read 0).

## Backlogged (pre-existing / adjacent, do NOT fold into this cycle)
- `read_user_info` logs `inspect(user_info)` incl. password bytes at info level (`user_info_helper.ex:32`, pre-existing).
- EndOfSync stays status 0 when queue items fail (contract-conformant; changing is a contract question).
- Same-name collision hardening, display label, start_queue double-start, last_sync_pc, onboarding UI — see `backlog.md`.

## Resume protocol
1. Engineer picks fix bundle (all / M2-only / per-item) — options were presented 2026-09-18.
2. Apply fixes → re-run gates (`mix format && mix credo --strict && mix compile && mix test && make -C c_src test`).
3. Continue ultrawork: Phase 4 REFINE (Steps 9-13: CCR reusability + consistency reviews, refactor agent) → Phase 5 SHIP (Steps 14-17) → integration check → merge.
4. Rocco writeback ONLY after merge + explicit engineer signoff (hard gate in AGENTS.md).

## Artifacts
- Contracts: docs/contracts/palm-identity-onboarding/ (5 files + this one)
- Plan: .agents/results/plan-ses_f6da32bb8ffe34ql42WdD4piK8.json (note: contains a stale line "Explicit EndOfSync NOT included" — contracts mandate EndOfSync; implementation follows contracts)
- Implementer: .agents/results/result-backend-ses_f6da32bb8ffe34ql42WdD4piK8.md
- RED proof: .agents/state/memories/red-proof-onboarding.txt
- Reviews: .agents/results/review-step{2,2-r2,3,4,6,7,8}-*.md
- Probe backup: branch `wip/probe-backup` (commit 263edf2)
- Session log: .agents/state/memories/session-ultrawork.md
