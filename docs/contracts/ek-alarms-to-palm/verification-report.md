# Verification Report — #31 Layer 3 (EK Alarms → Palm)

Verification executed 2026-09-12 via ultrawork session 20260911-234219:
2 build/fix cycles, 12 cross-context reviews (Steps 2-4 plan, 6-8 verify ×2, 10/12 refine, 14-17 ship ×1 re-run).

## Contract compliance

### Contract 1 — CalendarEventWorker cleaning (write path)
| Contract item | Implementation | Test | Status |
|---|---|---|---|
| nil → `[]`, no default | calendar_event_worker.ex `clean_event_alarms/2` | calendar_event_worker_test.exs non-list/nil cases | ✅ |
| keep `offset <= 0`, order preserved | via AlarmPicker.clean/2 (worker `sync_calendar/2`) | worker_test keep-cases | ✅ |
| all-positive non-empty → `[-default]` | worker clean path + alarm_picker clean/2 | worker_test default-substitution | ✅ |
| cleaned list in attrs AND upsert arg | worker `sync_calendar/2` | worker_test upsert assertion | ✅ |
| debug-level cleaning logs | worker `log_alarm_cleaning/2` | worker_test log assertions | ✅ |
| non-list port input → no alarms, no crash (decision 8b) | worker `clean_event_alarms/2` | worker_test stale-binary/drifted-map | ✅ |
| stale-rescue branch untouched | worker `sync_calendar/2` rescue branch (byte-identical) | worker_test rescue regression | ✅ |

### Contract 2 — Utils.AlarmPicker (pure)
| Contract item | Implementation | Test | Status |
|---|---|---|---|
| Invariants 1-4 (clean) | alarm_picker.ex `clean/2` | alarm_picker_test.exs (unit+property) | ✅ |
| Invariant 5 (empty → no alarm) | alarm_picker.ex `to_palm_alarm([], _)` | alarm_picker_test empty case | ✅ |
| Invariant 6 (0 ≤ advance ≤ 255) | `advance_and_unit/1` ladder | property (bignum ranges to 10^12, explicit 10^15/10^18) | ✅ |
| Invariant 7 (pick first/last) | `picked_offset/2` | pick tests (both picks) | ✅ |
| Invariant 8 (divisibility-first units) | `advance_and_unit/1` guard clauses | unit/boundary tests + property | ✅ |
| Invariant 9 (ceil-up ladder + cap) | `advance_and_unit/1` ceil clauses | rung tests 15_300/15_301, 918_000/918_001, 22_032_000/22_032_001 | ✅ |
| Invariant 10 (never-late except cap, overshoot < 1 unit) | uniform `ceil_div/2` | never-late + overshoot properties | ✅ |
| Invariant 11 (0 → {true, 0, :minutes}) | `advance_and_unit(0)` | zero test | ✅ |
| Invariant 12 (bignum safety) | ladder + cap | bignum tests + property | ✅ |
| Invariant 13 (minimality + largest-unit tie-break) | ladder + tie-break normalization | minimality property + tie-break examples | ✅ |
| Invariant 14 (default > 0 guard) | `clean/2` guards | guard test (0 / -600 raise) | ✅ |

### Contract 3 — from_calendar_event/2 (mapping)
| Contract item | Implementation | Test | Status |
|---|---|---|---|
| pick_alarm read at call time | datebook_appointment.ex `from_calendar_event/2` | datebook_test (both picks) | ✅ |
| unit atom → enum value 0/1/2 | `unit_to_advance_value/1` | datebook_test unit cases | ✅ |
| empty → struct defaults | `from_calendar_event/2` | datebook_test empty case | ✅ |
| defaulted list → default under both picks | `from_calendar_event/2` | datebook_test default cases | ✅ |
| existing mappings byte-identical | `from_calendar_event/2` | datebook_test regression cases | ✅ |
| sole caller unchanged | appointment_worker.ex `sync_records` | full suite (its tests green) | ✅ |

## Verification stack actually used

| Layer | Result |
|---|---|
| Contract tests (traced) | 3 new test files; every case ties to a contract invariant via standalone prose comments (the `# Contract:` tag style was abolished in the PR review round — see corrections below). Suite grew from 96 (94 tests + 2 properties) on main to 138 (128 tests + 10 properties) |
| Property tests | 9 properties (stream_data): boundedness, never-late, exactness, overshoot, clean-set, bignum |
| Adversarial review | Step 7 v2: hand-computed boundary table (19 adversarial offsets, all ✓) |
| Cross-context review | 12 isolated reviewer passes; every FAIL drove a root-cause fix (see below) |
| Full suite | `mix test` → **10 properties, 128 tests, 0 failures** (pre-branch main: 94+2, all still green) |
| Static analysis | format ✓ · credo --strict = 0R+11D, exactly matching origin/main (zero new) · dialyzer = only exempt pre-existing unknown_type · compile = only pre-existing warnings |
| Mutation testing | **Not run** — no mutation tooling configured in this project. Property tests + hand-computed adversarial boundary verification substituted; adding mutation tooling is a future-cycle candidate. |

## Review-driven fixes (root-cause, not tactical)

1. **Step 7 HIGH** — Palm wire advance is 1 byte; unbounded advance wrapped (270 min → 14 min) and bignum offsets crashed the NIF path → contract amended (decision 7: bounded ceil-up ladder), T5 fix, re-verified PASS with hand-computed boundaries.
2. **Step 14 MEDIUM** — new dialyzer `invalid_contract` on unit_to_advance_value/1 spec → spec corrected to `:: 0 \| 1 \| 2`, re-verified PASS.
3. **T5 deviation** — build agent found coordinator's prompt example (90060 → {25, :hours}) violated the never-late invariant (25h < 90060s); implemented {26, :hours} per contract. Contract-as-SSOT held.

## Edge cases tested beyond spec

- Sub-minute offsets (90s → 2 min) — ceil keeps never-late universal
- Duplicate offsets preserved (no dedup per contract)
- Negative-picked offsets from legacy uncleaned rows degrade via abs() (documented in backlog.md #1)

## Review round (grumpy pass, 2026-09-13) — corrections

The PR review found this report's first draft contained two false claims, both corrected here for the record: (1) it stated credo was at its pre-existing baseline when the branch had in fact added 3 readability + 1 design issue vs origin/main (main = 0R+11D); those 4 issues are now fixed — credo is 0R+11D, exactly matching main. (2) It called the storage schema "untouched" — the `alarms_seconds` attribute and its migration were added by earlier commits on this branch (1feb8f7). Additional fixes driven by the review: worker guards non-list port input (decision 8b), `clean/2` guards `default > 0` (8c), option renamed `:pick_alarm`, minimality property added (8d) — which immediately caught the ladder violating the tie-break rule (3_599s expressed as 60 minutes instead of 1 hour) and fixed it. Suite after the round: 10 properties + 128 tests, 0 failures.

## Unverified items

- Mutation score: no tooling (noted above)
- Real-device round trip: needs physical Palm hardware (post-BUILD reality — first live sync may surface DLP quirks; retry/duplicate behavior backlogged)
