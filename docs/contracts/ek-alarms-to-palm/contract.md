# Contract — EK Alarms → Palm Alarm Mapping (#31, Layer 3)

**Inputs**: `docs/blueprints/alarms-31-blueprint.md` (deleted after this contract) +
existing branch code. Where they diverged, the code won (raw-list storage) and
where the blueprint was silent or buggy, the engineer decided (grill-me session,
2026-09-12).

**Scope**: consume the dead `pick_alarm` / `default_alarm_seconds` config and map
stored alarm offsets into Palm alarm fields. Three module boundaries. Swift port,
CalendarEvent resource/migration, and C NIF are **out of scope** (done, approved).

**Engineer decisions (binding, from grill-me)**:
1. Pick + conversion logic lives in a dedicated pure module in the Utils namespace.
2. Data is cleaned **before storage, in Elixir** (worker write path): discard
   positive offsets; if the original list was non-empty but fully filtered, store
   the default (`-default_alarm_seconds`). DB list is self-describing:
   empty ⟺ user has no alarm. Swift stays a dumb provider.
3. `pick_alarm` stays `:first`/`:last` (sync-time pick); on a defaulted list the
   single element matches either pick.
4. Offset `0` (alarm at start) is valid user intent → `alarm: true, advance: 0`.
   Filter discards **positives only**.
5. Unit conversion = divisibility rule: days if `% 86400 == 0`, hours if
   `% 3600 == 0`, else minutes (floor). (Blueprint D3 table had a 0-advance bug
   for values like 5400s.)
6. Cleaning events (discards, default substitution) log at `debug` level.
7. Advance is bounded to the Palm wire format (VERIFY Step 7 finding, engineer
   decision 2026-09-12): the device stores advance as ONE byte + unit byte —
   max 255 per unit (255 min ≈ 4¼h, 255 h ≈ 10½d, 255 d ≈ 8mo). Odd-minute
   offsets that exceed 255 in the divisibility-chosen unit are rounded **UP** to
   the next representable hour/day — better to alarm too early than too late,
   the user can snooze. Only exception: offsets > 255 days cap at 255 days (the
    sole fires-later case). Documented as a known limitation in README.
8. PR #41 review round (engineer, 2026-09-13):
   (a) `to_palm_alarm/2`'s option is named `:pick_alarm` (config symmetry); the
       private pick helper is `picked_offset/2` (it returns an offset, not an alarm).
   (b) The worker guards the port input: a non-list `alarms_seconds` value
       (protocol drift or a stale binary) is treated as no alarms + a debug log —
       runtime DATA errors degrade, they must not crash-loop the autosync worker.
   (c) `clean/2` guards `default > 0` and raises FunctionClauseError otherwise —
       CONFIG errors crash loudly (same philosophy as a missing `pick_alarm`).
   (d) Test comments are standalone human prose (AGENTS.md rule), never
       contract-pointer tags. Redundant `clean/2` examples are deleted in favor
       of the properties; a new minimality property pins unit selection ("the
       returned alarm is the earliest time the Palm can express that is not
       later than requested, ties → largest unit"); the ladder-rung boundary
       examples stay — random generators cannot hit exact flip points like
       15_301 or 918_001.

---

## Contract 1 — `PalmSync4Mac.EventKit.CalendarEventWorker` (write-path cleaning)

### Purpose

Clean raw Apple alarm offsets once, at the point they enter the system, so the
DB holds only valid alarm data.

### Inputs → Outputs

| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| `cal_date["alarms_seconds"]` | `list(integer) or nil` | signed ints, ascending per Swift | cleaned list | `list(integer)` | all elements `<= 0`, ascending; non-empty iff input non-empty |
| non-list `alarms_seconds` (protocol drift) | any non-list term | port misbehaved | `[]` | `list(integer)` | degrade to no alarms + debug log, never a worker crash (decision 8b) |
| `default_alarm_seconds` config | `pos_integer()` | from `:palm_sync_4_mac` app env, default 600 | used as fallback | — | only consulted when filtering empties a non-empty list |

### Behavior

1. `nil` → treated as `[]` (no alarm — **no** default inserted).
2. Keep every offset `<= 0`, preserving order (0 included).
3. If input was non-empty and everything was discarded: result is
   `[-default_alarm_seconds]` (exactly one element).
4. The cleaned list becomes BOTH the stored `alarms_seconds` attribute AND the
   `new_alarms_seconds` upsert argument (existing upsert semantics unchanged).
5. `Logger.debug` on discard (count) and on default substitution.

### Error cases

| Condition | Behavior |
|-----------|----------|
| PortHandler error / stale upsert rescue | unchanged — cleaning adds no new error paths |

### Integration points

- Depends on: `PalmSync4Mac.Utils.AlarmPicker.clean/2` (pure), `Application.fetch_env!(:palm_sync_4_mac, :default_alarm_seconds)`
- Modifies: `calendar_event` rows via existing `create_or_update` upsert
- Emits: none

### Prohibitions

1. No filtering/default logic in Swift, C, or the Ash resource.
2. No `:info` (or above) logging for cleaning events.
3. No deduplication of equal offsets.
4. No new config keys; `default_alarm_seconds` semantics (positive int, seconds) unchanged.
5. Existing rescue/log branches for stale upserts stay byte-identical.

---

## Contract 2 — `PalmSync4Mac.Utils.AlarmPicker` (pure functions)

### Purpose

Pure alarm policy: clean raw offset lists (write path) and convert the picked
offset into Palm's `{alarm, advance, unit}` triple (sync path). Will later host
the Palm→EK back-conversion.

### Inputs → Outputs

**`clean(alarms_seconds, opts)`**
| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| `alarms_seconds` | `list(integer)` | may be empty | cleaned list | `list(integer)` | elements `<= 0`, original order preserved; `[-default]` iff all input positive and input non-empty |

`opts` carries `default_alarm_seconds` (pos integer). No config reads, no logging.

**`to_palm_alarm(alarms_seconds, opts)`**
| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| cleaned list | `list(integer)` | elements `<= 0` | `{alarm, advance, unit}` | `{boolean, non_neg_integer, :minutes or :hours or :days}` | see invariants |

`opts` carries `pick_alarm` (`:first` or `:last`; named after the `config.exs` key). No config reads, no logging. The `:first`/`:last` semantics (farthest-from / closest-to start) rely on the Swift port delivering the list in ascending order.

### Invariants (all testable, property-test targets)

1. `clean/2`: output empty ⟺ input empty.
2. `clean/2`: every kept element appears in input with `offset <= 0`, order preserved.
3. `clean/2`: no valid element is ever dropped, no positive element is ever kept.
4. `clean/2`: input non-empty and all positive → output == `[-default]`.
5. `to_palm_alarm/2`: empty list → `{false, 0, :minutes}`.
6. `to_palm_alarm/2`: non-empty → `{true, advance, unit}` with `advance >= 0` and `advance <= 255` (wire-format bound, decision 7).
7. `to_palm_alarm/2`: picked offset = `List.first` (`:first`) or `List.last` (`:last`) of input.
8. `to_palm_alarm/2`: `offset = abs(picked)`; clean values keep their natural unit (divisibility checked first, preserving decision 5): `:days` iff `rem(offset, 86400) == 0` **and** `div(offset, 86400) <= 255`; else `:hours` iff `rem(offset, 3600) == 0` **and** `div(offset, 3600) <= 255`; else `:minutes` if `offset <= 15_300` (255 min).
9. `to_palm_alarm/2` (ceil-up ladder for values that fit no clean unit — decision 7): `offset <= 918_000` (255 h) → `:hours` with `advance = ceil(offset / 3600)`; else `offset <= 22_032_000` (255 d) → `:days` with `advance = ceil(offset / 86400)`; else `:days` with `advance = 255` (cap — the only case that alarms later than requested).
10. `to_palm_alarm/2`: `advance = ceil(offset / unit_seconds)` in EVERY branch (identical to `div` when the value divides cleanly). Consequently the result never fires later than the requested time (`advance * unit_seconds >= offset`) except the >255d cap, and every ceil overshoot is less than one unit.
11. `to_palm_alarm/2`: picked offset `0` → `{true, 0, :minutes}` (explicit override — 0 is divisible by everything; engineer decision Q4: "0 mins to start" reads as minutes; semantically "at start" since advance is 0).
12. Bignum safety: any integer input (including absurd absoluteDate offsets) yields `advance <= 255` — downstream C `int` and wire byte can never overflow or wrap.
13. Minimality (decision 8d): for `0 < offset <= 22_032_000`, the returned alarm is the EARLIEST time the Palm can express that is not later than requested (`advance * unit_seconds >= offset`, and no expressible value — m∈1..255 minutes, h∈1..255 hours, d∈1..255 days — lies strictly between `offset` and the result); when multiple units express the same result exactly, the largest unit is returned.
14. `clean/2` guards its `default` option: `default <= 0` raises FunctionClauseError (loud config failure, decision 8c).

### Error cases

None — pure total functions over closed inputs. No raises on any list of integers.

### Integration points

- Depends on: nothing (no app env, no DB, no NIF, no Logger)
- Modifies: nothing
- Emits: nothing
- Used by: `CalendarEventWorker` (clean), `DatebookAppointment.from_calendar_event/2` (to_palm_alarm)

### Prohibitions

1. No `Application`/config access anywhere in the module.
2. No logging.
3. No dependency on `PalmSync4Mac.Comms.Pidlp` — units are atoms (`:minutes | :hours | :days`); enum-value mapping is the caller's job.
4. No DateTime/NaiveDateTime math — offsets are plain integers.
5. No speculative API beyond `clean/2` and `to_palm_alarm/2` (back-conversion comes in its own cycle).

---

## Contract 3 — `PalmSync4Mac.Comms.Pidlp.DatebookAppointment.from_calendar_event/2` (mapping)

### Purpose

Map the stored (already-clean) `alarms_seconds` into the three Palm alarm fields
using the `pick_alarm` config, keeping the existing mappings untouched.

### Inputs → Outputs

| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| `event` | `CalendarEvent.t()` | `alarms_seconds` cleaned per Contract 1 | appointment with alarm fields set | `DatebookAppointment.t()` | fields set per invariants |
| `rec_id` | `non_neg_integer()` | unchanged | passed through | — | `0` still means "new record" |

### Behavior

- Read `pick_alarm` via `Application.fetch_env!(:palm_sync_4_mac, :pick_alarm)` at call time.
- `alarm`, `alarm_advance`, `alarm_advance_units` = `AlarmPicker.to_palm_alarm(event.alarms_seconds, pick_alarm: pick)` with the unit atom mapped to its `AlarmAdvanceUnit` value (`:minutes → 0`, `:hours → 1`, `:days → 2`).
- Signature, return shape, and all existing field mappings (description, begin, end, note, location, event, rec_id, encoding) byte-identical.

### Invariants

1. Empty `alarms_seconds` → `alarm: false, alarm_advance: 0, alarm_advance_units: AlarmAdvanceUnit.Minutes.value()` (struct defaults).
2. Non-empty → alarm triple equals `to_palm_alarm/2` output for the configured pick.
3. Sole caller (`AppointmentWorker:112`) requires **no changes**.

### Error cases

| Condition | Behavior |
|-----------|----------|
| Missing `pick_alarm` config | `Application.fetch_env!` raises — acceptable, config is mandatory in config.exs |

### Integration points

- Depends on: `PalmSync4Mac.Utils.AlarmPicker.to_palm_alarm/2`, `AlarmAdvanceUnit` enum, `:palm_sync_4_mac` app env (`pick_alarm`)
- Modifies: nothing (builds a struct)
- Emits: nothing

### Prohibitions

1. No new parameters or arity changes.
2. No changes to `build_note/1`, `to_palm_encoding/1`, or any non-alarm mapping.
3. No DB access, no logging inside this function.

---

## Test plan (traced to contracts, plain-language comments per LEARNINGS)

| Contract | Test file (all NEW — none exist yet) | Coverage |
|---|---|---|
| 2 | `test/palmsync4mac/utils/alarm_picker_test.exs` | clean: keeps 0/negatives in order, drops all positives, default insertion only when orig non-empty (unit + stream_data property tests); to_palm_alarm: empty, pick first/last, all boundary conversions (0, 90s, 3600s, 5400s, 86400s, 172800s), the bounded ceil-up ladder (15_300/15_301, 918_000/918_001, 22_032_000/22_032_001, bignum), never-late invariant |
| 1 | `test/palmsync4mac/event_kit/calendar_event_worker_test.exs` | cleaned list reaches both upsert arg and attrs; nil → `[]` stored (nil→[] is the worker's job, not AlarmPicker's); all-positive → `[-default_alarm_seconds]`; debug (not info) log level |
| 3 | `test/palmsync4mac/comms/pidlp/datebook_appointment_test.exs` | alarm mapping for `:first`/`:last`/empty/defaulted list via `Application.put_env`; existing mappings regression-checked. Missing-`pick_alarm` raise is accepted-untested (standard `Application.fetch_env!` behavior) |
