# Context Brief — palm-identity-onboarding

## Target

Fix the duplicate-records bug at its root: give every Palm a stable identity in our DB via a username-keyed onboarding state machine, provision each onboarded device with a DB-assigned `user_id` (Palm device integer), and guarantee clean session teardown (EndOfSync). Blank devices without a user-supplied name fall back to the existing random generator — documented as permanent, since Palm names are immutable after first assignment.

## Hardware evidence (this cycle, all Palm OS 5.x)

- Wiped Tungsten T3 onboarded with a name → **name persists** across HotSync app reopen → first-sync adoption confirmed.
- Established devices (TX, Tungsten C, CLIÉ UX50) **silently drop username writes** on the wire (modflags 0x3f, OpenConduit, nonzero lastSyncPC, dlpsh, pilot-install-user all failed to rename).
- `user_id` writes **commit reliably** on every device tested (18839 → 12345 → 55332 across tools).
- `dlp_EndOfSync` is the required session-finalization call (pi-dlp.h:783); `pi_close` only auto-sends it under clean socket state — not guaranteed (see `.agents/state/memories/result-investigate-20260913-094700.md`).

## Existing code

- `lib/palmsync4mac/entity/device/palm_user.ex` — Ash resource: `uuid_primary_key(:id)`, identity `unique_event` on `[:username]` (eager_check), upsert action `create_or_update`; `username` + `user_id` both `allow_nil?(false)`.
- `lib/palmsync4mac/pilot/sync_worker/user_info_worker.ex` — `pre_sync(username \\ nil)`: read_user_info → update_username → update_last_sync_pc/date → write_user_info (device) → write_to_db (upsert) → `{:ok, palm_user_id}` (D3: this return is the only channel to MainWorker).
- `lib/palmsync4mac/pilot/helper/user_info/user_info_helper.ex` — `update_username/2` ({true,false} branch generates random 5-char name, **no DB uniqueness check**); `write_to_db` upserts by username, catches StaleRecord (D4); `get_existing_palm_user_id` returns nil on lookup failure (nil then flows into all sync workers).
- `lib/palmsync4mac/pilot/sync_worker/main_worker.ex` — terminate does bare disconnect (pre-fix); wip commit 263edf2 carries the EndOfSync fix + probe.
- `lib/palmsync4mac/comms/pidlp.ex` (generated from `c_src/palm_sync_4_mac/pidlp.spec.exs`) — NIF surface: `read_user_info`, `write_user_info`, `end_of_sync` (already exists, pidlp.c:246), plus the `write_user_info_raw/5` probe to be REMOVED.
- `list_unsynced_for_device` (`lib/palmsync4mac/pilot/sync_worker/appointment_worker.ex:68`) — treats "zero join rows" as "sync everything" (the amplifier that turned the identity bug into duplicate batches).

## Reuse opportunities

- `update_username/2`'s random generator becomes the documented fallback — wrapped with a DB uniqueness check.
- `write_to_db` upsert + StaleRecord fallback (D4) reused for row creation.
- `Pidlp.end_of_sync/2` already exists in the NIF — MainWorker just has to call it.

## Conventions to follow

- `{:ok, _}` / `{:error, reason}` tuples, never raise on expected errors.
- Patch (NIF mocking) + Mox for tests; mocks must return the spec-declared `%PilotUser{}` struct, not a plain map (`struct/2` on a struct crashes).
- Unifex spec type paths fully qualified (`PalmSync4Mac.Comms.Pidlp.PilotUser`).
- Comments: standalone prose with full context, no trace tags.

## Hard constraints

- Palm encoding ISO-8859-1 via codepagex; usernames for provisioning are **ASCII-only printable, length 1–40** (Palm wire limit); generated names are 5-char `[a-z0-9]` by construction.
- Password bytes must round-trip exactly as read (`strndup` with length at the NIF) — never generated, never modified.
- `rec_id = 0` means "new record"; tm_mon 0–11; NIF safety (no VM crashes).
- D2: `PalmUser.id` (UUID) stays the canonical DB identifier and join-FK; D3: pre_sync returns `{:ok, palm_user_id}`.
- **No PK migration.** The auto-increment provisions the Palm device integer (`pilot_user.userID`), not the DB PK.

## Out of scope

- Garbage cleanup: none — engineer deletes the dev sqlite DBs (plus `-wal`/`-shm`); on-device duplicate batches on T|C/UX50 are cleared by hard reset (dev system).
- Same-name hard conflict handling (warn-only now; documented gap, revisit at UI round).
- `last_sync_pc` stays hardcoded 0 (can't send hostnames).
- `{:already_started, pid}` double-start bug in `start_queue` (pre-existing; backlog).
- Username normalization/case-folding (exact byte match, documented).
- Display-label field separate from username (backlog for UI round).
