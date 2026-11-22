# VERIFY Findings & Pending Remediation Decision — palm-identity-onboarding

Status: **resolved 2026-11-13** — engineer (Beezle-supervised session) chose the full recommended bundle: items 1–4 + the README line applied (RED-first tests added, all green); item 5 (RE_ONBOARD breadcrumb) declined for this cycle. VERIFY phase originally passed all three CCR reviews (Step 6 Alignment PASS, Step 7 Safety PASS, Step 8 Regression PASS — gates independently re-run and matched) on 2026-09-18. Implementation is committed as wip on `42-palm-identity-onboarding`.

## Resolved by engineer decision
- **M1 — unique index aborts on bug-era DBs**: no prod DB exists; the policy is **drop and recreate the DB** (delete dev.sqlite + wal/shm). ~~Pending small item: one README line tying the "UNIQUE constraint failed" migration error to that procedure.~~ **README line added 2026-11-13.**
- Migration formatting LOW: re-verified `mix format --check-formatted` CLEAN — reviewer's claim was stale, no action.
- **2026-11-13 full bundle applied** (see "Awaiting decision" items below, now resolved):
  - Item 1 (MEDIUM): `reset_sync_status_rows/1` now collects destroy failures and returns `{:error, :join_row_reset_incomplete}`; worker error branch wired; contract error table updated.
  - Item 2 (LOW): `update_username/2` nameless+nil fallback branch deleted; explicit binary name required (FunctionClauseError otherwise).
  - Item 3 (LOW): `validate_username/1` rejects whitespace-only names; contract invariant 8 + error table updated.
  - Item 4 (LOW): vacuous `successful_sync_date` assertion replaced with a concrete `> 0` check; join-row count asserted in the zero-write regression test.
  - Item 5 (optional RE_ONBOARD breadcrumb): declined this cycle.
- **2026-11-22 design change (engineer decision)**: RANDOM_FALLBACK removed — a
  nameless device without an explicit username now fails pre_sync with
  `{:error, :username_required}` before any row or device write. Rationale: the
  username is permanent on Palm hardware (established devices drop username
  writes), so a machine-invented identity is a lifelong decision taken
  without the operator; the name must be a conscious choice (see D7 in
  architecture-decision.md and rule 3.2 in laws.md).
  `generate_unique_name/0` and `StringUtils.generate_random_string/1` deleted.

## Originally awaiting decision (presented 2026-09-18, all now applied/declined above)

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
