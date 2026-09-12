# Verification Report — #31 Layer 3 (EK Alarms → Palm)

Verification executed 2026-09-12 via ultrawork session 20260911-234219:
2 build/fix cycles, 12 cross-context reviews (Steps 2-4 plan, 6-8 verify ×2, 10/12 refine, 14-17 ship ×1 re-run).

## Contract compliance

### Contract 1 — CalendarEventWorker cleaning (write path)
| Contract item | Implementation | Test | Status |
|---|---|---|---|
| nil → `[]`, no default | calendar_event_worker.ex:67 | calendar_event_worker_test.exs:107 | ✅ |
| keep `offset <= 0`, order preserved | via AlarmPicker.clean/2 (worker:68) | worker_test:87,143,154 | ✅ |
| all-positive non-empty → `[-default]` | worker:68 + alarm_picker.ex:27 | worker_test:132 | ✅ |
| cleaned list in attrs AND upsert arg | worker:75-79 | worker_test:87 | ✅ |
| debug-level cleaning logs | worker:95-108 | worker_test:168,187 | ✅ |
| stale-rescue branch untouched | worker:80-85 (byte-identical) | worker_test:208 | ✅ |

### Contract 2 — Utils.AlarmPicker (pure)
| Contract item | Implementation | Test | Status |
|---|---|---|---|
| Invariants 1-4 (clean) | alarm_picker.ex:14-27 | alarm_picker_test.exs (unit+property) | ✅ |
| Invariant 5 (empty → no alarm) | alarm_picker.ex:23 | :46 | ✅ |
| Invariant 6 (0 ≤ advance ≤ 255) | ladder :59-75 | property (bignum ranges to 10^12, explicit 10^15/10^18) | ✅ |
| Invariant 7 (pick first/last) | :46-48 | :52-62 | ✅ |
| Invariant 8 (divisibility-first units) | :59-66 | :74-85 + boundary property | ✅ |
| Invariant 9 (ceil-up ladder + cap) | :67-75 | :boundary tests 15_300/15_301, 918_000/918_001, 22_032_000/22_032_001 | ✅ |
| Invariant 10 (never-late except cap, overshoot < 1 unit) | uniform ceil_div | never-late + overshoot properties | ✅ |
| Invariant 11 (0 → {true, 0, :minutes}) | :59 | :68 | ✅ |
| Invariant 12 (bignum safety) | ladder + cap | bignum tests + property | ✅ |

### Contract 3 — from_calendar_event/2 (mapping)
| Contract item | Implementation | Test | Status |
|---|---|---|---|
| pick_alarm read at call time | datebook_appointment.ex:115 | datebook_test:66-96 (both picks) | ✅ |
| unit atom → enum value 0/1/2 | :128-131 | datebook_test:106-115 | ✅ |
| empty → struct defaults | :117 | datebook_test:46-56 | ✅ |
| defaulted list → default under both picks | :115-117 | datebook_test:86-96 | ✅ |
| existing mappings byte-identical | :118-126,132 | datebook_test:136-185 (regression) | ✅ |
| sole caller unchanged | appointment_worker.ex:112 | full suite (its tests green) | ✅ |

## Verification stack actually used

| Layer | Result |
|---|---|
| Contract tests (traced) | 35 net-new tests across 3 new files, all traced via `# Contract:` comments |
| Property tests | 9 properties (stream_data): boundedness, never-late, exactness, overshoot, clean-set, bignum |
| Adversarial review | Step 7 v2: hand-computed boundary table (19 adversarial offsets, all ✓) |
| Cross-context review | 12 isolated reviewer passes; every FAIL drove a root-cause fix (see below) |
| Full suite | `mix test` → **9 properties, 130 tests, 0 failures** (baseline pre-branch: 94+2, all still green) |
| Static analysis | format ✓ · credo --strict = exact pre-existing baseline (3R+12D) · dialyzer = only exempt pre-existing unknown_type · compile = only pre-existing warnings |
| Mutation testing | **Not run** — no mutation tooling configured in this project. Property tests + hand-computed adversarial boundary verification substituted; adding mutation tooling is a future-cycle candidate. |

## Review-driven fixes (root-cause, not tactical)

1. **Step 7 HIGH** — Palm wire advance is 1 byte; unbounded advance wrapped (270 min → 14 min) and bignum offsets crashed the NIF path → contract amended (decision 7: bounded ceil-up ladder), T5 fix, re-verified PASS with hand-computed boundaries.
2. **Step 14 MEDIUM** — new dialyzer `invalid_contract` on unit_to_advance_value/1 spec → spec corrected to `:: 0 \| 1 \| 2`, re-verified PASS.
3. **T5 deviation** — build agent found coordinator's prompt example (90060 → {25, :hours}) violated the never-late invariant (25h < 90060s); implemented {26, :hours} per contract. Contract-as-SSOT held.

## Edge cases tested beyond spec

- Sub-minute offsets (90s → 2 min) — ceil keeps never-late universal
- Duplicate offsets preserved (no dedup per contract)
- Negative-picked offsets from legacy uncleaned rows degrade via abs() (documented in backlog.md #1)

## Unverified items

- Mutation score: no tooling (noted above)
- Real-device round trip: needs physical Palm hardware (post-BUILD reality — first live sync may surface DLP quirks; retry/duplicate behavior backlogged)
