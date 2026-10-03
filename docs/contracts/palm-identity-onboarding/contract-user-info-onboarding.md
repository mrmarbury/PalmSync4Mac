# Contract — UserInfoWorker.pre_sync / UserInfoHelper (onboarding state machine)

## Purpose

Classify each connected Palm by its device username, provision a DB identity (row + Palm `user_id`) on first contact, and return the stable `palm_user_id` for the sync session — eliminating the per-sync random-name/row duplication that caused duplicate record pushes.

## Inputs → Outputs

| Input | Type | Constraints | Output | Type | Guarantee |
|---|---|---|---|---|---|
| `client_sd` | integer | valid DLP socket | classification result | — | device user info read exactly once per pre_sync |
| `username` (optional) | String.t | 1–40 printable ASCII; only used for nameless devices | `{:ok, palm_user_id}` | `{:ok, String.t}` | palm_user_id ALWAYS non-nil, references existing `palm_user` row (hard-fail otherwise) |
| device `PilotUser` | struct | from `read_user_info` | state transition | — | exactly one of: KNOWN / ADOPT / ONBOARD / RANDOM_FALLBACK / RE_ONBOARD (see state machine) |

## State machine (device username → row)

| # | Device reads | Row state | Action |
|---|---|---|---|
| 1 | name ≠ blank | row exists (`username` exact byte match) | **KNOWN**: no identity writes; if `row.user_id ≠ device.user_id` → `Logger.warning` (two devices may share the name — documented gap, see backlog) |
| 2 | name ≠ blank | no row | **ADOPT**: create row (username = device name, `user_id = next_user_id()`); write our `user_id` to device **best-effort** (warn on failure, sync continues — identity is the name) |
| 3 | name blank | explicit `username` arg matches existing row | **RE_ONBOARD**: write name+`user_id` (row's existing id) to device first; on success reset that row's join rows (`ek_calendar_datebook_sync_status`) with a loud log; on write failure `{:error, :device_write_failed}`, no changes |
| 4 | name blank | explicit `username` arg, no row | **ONBOARD**: create row (`user_id = next_user_id()`) → write name+`user_id` to device → on write failure **delete the row** (compensating) and `{:error, :device_write_failed}` |
| 5 | name blank | no arg | **RANDOM_FALLBACK**: generate 5-char `[a-z0-9]` name, **unique-checked against all `palm_user.username`** (regenerate until unique), then proceed as ONBOARD (row 4) |

- Blank detection: `String.trim(device_username) == ""`. Matching: exact raw bytes, no trim/case-folding (deliberate asymmetry, documented).
- Name writes only ever happen for nameless devices (rows 3–5). A device that already has a name is NEVER renamed — hardware-verified: Palm OS drops username writes on established devices, and our row key must equal the device's real name.

### post_sync (teardown writes)

`post_sync` (lastSyncDate device write + DB date upsert) is guarded:

1. It performs **no device writes and no DB upsert** unless `pre_sync` succeeded in the same session — a failed pre_sync leaves the worker without valid identity state, and an upsert with a default `%PilotUser{}` would write blank username / `user_id 0` and could resurrect a row the ONBOARD compensating delete just removed.
2. Its DB upsert never touches `palm_user.username` or `palm_user.user_id` — the row's provisioned identity is authoritative; only sync/date fields update.
3. Its device user-info write (if any) round-trips the device's own username bytes exactly.

## Invariants (MUST ALWAYS be true)

1. `pre_sync` returns `{:ok, palm_user_id}` with a non-nil UUID of an existing row, or `{:error, reason}` — nil never flows downstream.
2. Two consecutive `pre_sync` calls for the same physical device return the **same** `palm_user_id` (regression test: RED today).
3. Every generated (fallback) username is unique among `palm_user.username` at generation time (check-then-retry, not hope).
4. Every provisioned `user_id` is `> 0`, unique across `palm_user` (unique index + `max(user_id)+1` in a transaction), and written to the device in the same session (ADOPT/ONBOARD/RE_ONBOARD).
5. A successful second sync of unchanged data produces **zero** `write_datebook_record` calls (duplication regression test).
6. ONBOARD failure leaves no orphaned row: device write failure → row deleted.
7. RE_ONBOARD resets join rows only after a successful device write.
8. Explicit `username` argument is validated: 1–40 printable ASCII → else `{:error, :username_invalid}` (generated names are safe by construction).
9. `palm_user.username` is immutable after row creation (no update path touches it).
10. After a failed `pre_sync`, `post_sync` performs zero device writes and zero DB writes in that session.
11. `post_sync`'s upsert never changes `palm_user.username` or `palm_user.user_id` (row identity is authoritative; only sync/dates fields update).
12. A named device plus an explicit `username` argument classifies as **KNOWN** — the argument is ignored, and zero username-write calls reach the NIF for that session.

## Error cases

| Condition | Behavior |
|---|---|
| `read_user_info` fails | `{:error, reason}` — abort pre_sync, no DB/device writes |
| explicit name invalid (empty, > 40, non-ASCII, non-printable) | `{:error, :username_invalid}` — no row, no device write |
| ADOPT user_id write fails | warning log, sync continues (identity = name) |
| ONBOARD/RE_ONBOARD device write fails | `{:error, :device_write_failed}` — onboard compensates (row deleted), re-onboard leaves everything unchanged; sync aborted |
| DB create fails (e.g. unique violation race) | `{:error, reason}` — abort; no device write happened for ONBOARD (DB-first ordering) |
| `pre_sync` failed this session | `post_sync` no-ops (no device writes, no DB writes) |

## Integration points

- Depends on: `Pidlp.read_user_info/1`, `Pidlp.write_user_info/4`, `PalmUser` resource (`create_or_update` upsert, D4 StaleRecord fallback), Ash transaction.
- Modifies: `palm_user` table (new unique index on `user_id`), join rows on RE_ONBOARD.
- Returns to MainWorker: `{:ok, palm_user_id}` (D3 — unchanged contract).

## Prohibitions (MUST NEVER)

1. Never write a username different from the device's current name (any path, including post_sync; round-tripping identical bytes is the only permitted username write to a named device).
2. Never mutate `palm_user.username` after row creation.
3. Never generate or modify password bytes — round-trip exactly as read (`strndup` w/ length at the NIF).
4. Never return nil/let nil flow out of pre_sync.
5. Never normalize (trim/case-fold) usernames for matching.
6. Never provision `user_id = 0`.
7. No new NIF functions (existing `write_user_info` wrapper suffices — T3-verified it commits).

## Test plan (regression, RED-first)

1. pre_sync twice for the same mocked device → same `palm_user_id`, one row (RED against current code).
2. Second sync of unchanged data → zero `write_datebook_record` calls.
3. Named device + explicit argument → KNOWN; argument ignored; zero username writes.
4. Blank device + no argument → generated name unique among rows; second sync matches the generated row.
5. ONBOARD device-write failure → row deleted (compensation), `{:error, :device_write_failed}`.
6. RE_ONBOARD → join rows reset only after successful device write.
7. KNOWN with user_id mismatch → warning logged.
8. Failed pre_sync → post_sync performs zero device/DB writes; post_sync upsert preserves row `user_id`/`username`.

## Common pitfalls (from LEARNINGS / Rocco brief)

- Mocks must return the spec-declared `%PilotUser{}` struct, not a plain map.
- Test DB: `MIX_ENV=test mix ash_sqlite.create && MIX_ENV=test mix ash_sqlite.migrate`.
- Unifex spec type paths fully qualified (`PalmSync4Mac.Comms.Pidlp.PilotUser`).
- Known adjacent bug (NOT in scope, see backlog): `start_queue` double-start `{:already_started, pid}`.
