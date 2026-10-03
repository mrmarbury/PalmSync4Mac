# Architecture Decision — palm-identity-onboarding

## D1: State machine lives in `UserInfoWorker.pre_sync` (extended), not a new OnboardingWorker

- **Chosen**: extend `pre_sync/2` with the classify-and-provision state machine; helpers in `UserInfoHelper`.
- **Alternative rejected**: new `OnboardingWorker` — breaks the existing queue structure (D51: pre/sync/post queue phases, `inject_sync_context/3` arg positions) and D3's single-channel return for no benefit; onboarding is one phase of pre_sync, not a new phase.
- **Pattern alignment**: existing worker-per-task queue (`sync_test.ex` pre/main/post queues), `{:ok, palm_user_id}` return contract.

## D2: Identity = device username, exact byte match; username immutable after row creation

- **Chosen**: match device username against `palm_user.username` with exact bytes (no trim, no case folding for matching). Blank *detection* uses `String.trim(username) == ""` (a whitespace-only name counts as nameless) — deliberate asymmetry, documented.
- **Alternatives rejected**: normalization (two devices legitimately differ by one byte; NOCASE hides errors); user_id as matching key (user_id is 0 on fresh devices and mutable by foreign tools — proven on wire).

## D3: `user_id` = the Palm device integer, provisioned DB-side as `max(user_id)+1`

- **Chosen**: at onboarding, assign `user_id = max(existing user_id) + 1` (min 1) inside a transaction, backed by a new **unique index on `palm_user.user_id`**. Written to the device in the same session.
- **Alternatives rejected**: random uint32 ≠ 0 (engineer preference: no global namespace exists — each device collection runs its own ps4m/DB, sequential ids are readable and collision-free); replacing the UUID PK (supersedes D2, forces join-FK migration for zero benefit).
- Uniqueness only matters within one ps4m DB; SQLite serializes writers, so max+1 in a transaction is safe; the unique index is the backstop.

## D4: DB row first, device write second, compensating delete on onboard failure

- **Chosen**: onboard order = create DB row → write user info to device → on write failure, delete the row and return `{:error, :device_write_failed}`. Re-onboard (row pre-exists) order = write device first → reset join rows only after success.
- **Alternative rejected**: device-first (current flow) — if `write_to_db` fails, the device is permanently mutated (name sticks on virgin devices!) with no DB row.
- Self-healing closed loops: if we compensate but the device actually took the write, the device now has a name → next sync takes the ADOPT path. If we keep a row but the write failed, device stays blank → re-onboarding with the same explicit name reuses the row.

## D5: EndOfSync explicit in `MainWorker.terminate/2` (already on branch, wip 263edf2)

- `end_sync(client_sd, reason)` → `Pidlp.end_of_sync(client_sd, status)` — status 0 on `:normal`, 3 ("reasonable abort") otherwise — before `pilot_disconnect`. Guards `client_sd >= 0`, logs result, never blocks disconnect. Included because pi_close's auto-EndOfSync is conditional (clean socket state only), not guaranteed.
- **Probe REMOVED**: `write_user_info_raw/5` + its mock additions + wire tests dropped from the branch (recoverable from wip commit 263edf2).

## D6: Zero-join amplifier guard is warn-only

- `list_unsynced_for_device` logs a loud warning when it returns "everything" (zero join rows). Legitimate for a first sync after onboarding; the message documents that and the data-loss alternative. No behavior change.

## Module placement

| Change | File |
|---|---|
| State machine + provisioning helpers | `lib/palmsync4mac/pilot/helper/user_info/user_info_helper.ex`, `lib/palmsync4mac/pilot/sync_worker/user_info_worker.ex` |
| Unique index on `user_id` | new Ash migration (`mix ash_sqlite.generate_migrations`) |
| EndOfSync teardown | `lib/palmsync4mac/pilot/sync_worker/main_worker.ex` (done, on branch) |
| Probe removal | `c_src/palm_sync_4_mac/{pidlp.c,pidlp.spec.exs,mocks/*,tests/*}` (revert probe hunks from wip 263edf2) |
| Zero-join warn | `list_unsynced_for_device` (`appointment_worker.ex:68`) |
| Docs | `README.md` onboarding + random-fallback + clean-slate notes |

## Dependency graph

probe-removal → (independent); migration → helpers → worker state machine → regression tests; EndOfSync fix (done) → keep; guard (independent) → docs last.
