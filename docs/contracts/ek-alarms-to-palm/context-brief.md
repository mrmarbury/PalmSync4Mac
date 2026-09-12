# Context Brief — #31 Layer 3: EK Alarms → Palm Alarm Mapping

## Target

Map Apple alarm data (already stored as `CalendarEvent.alarms_seconds`) into the
Palm `DatebookAppointment` alarm fields (`alarm`, `alarm_advance`,
`alarm_advance_units`) inside `from_calendar_event/2`, consuming the currently-dead
`pick_alarm` / `default_alarm_seconds` config.

## Existing code

- `ports/Sources/EKCalendarInterface/Main.swift:106` — extracts `event.alarms` to
  `alarms_seconds`: signed offset seconds (`alarmOffsetSeconds/2`, absoluteDate takes
  precedence over relativeOffset), **sorted ascending**, `[]` when no alarms.
- `lib/palmsync4mac/entity/event_kit/calendar_event.ex:167` — `alarms_seconds`
  `{:array, :integer}` attribute; in `create_or_update` accept list + upsert condition.
- `lib/palmsync4mac/event_kit/calendar_event_worker.ex` — passes `new_alarms_seconds`
  through; stores the FULL raw list (user decision: keep, pick at sync time).
- `lib/palmsync4mac/comms/pidlp/datebook_appointment.ex:113` — `from_calendar_event/2`:
  maps description/begin/end/note/location/event/rec_id, **no alarm fields** (defaults:
  `alarm: false, alarm_advance: 0, alarm_advance_units: :minutes`). Sole caller:
  `AppointmentWorker:112`.
- `lib/palmsync4mac/comms/pidlp.ex:17` — `AlarmAdvanceUnit` enum: Minutes=0, Hours=1,
  Days=2 (stored as integers in the typed struct).
- `config/config.exs:31,34` — `pick_alarm: :last`, `default_alarm_seconds: 600`
  defined, **nothing reads them** (dead config).
- C NIF `write_calendar_record` already packs alarm/advance/advanceUnits — no NIF work.

## Reuse opportunities

- `from_calendar_event/2` private-helper pattern (`build_note/1`, `to_palm_encoding/1`)
  for small pure mappers.
- `PalmSync4Mac.Utils.TMTime` — precedent for pure conversion helper modules.
- Existing test patterns: `calendar_event_alarm_test.exs` (stream_data property tests),
  Swift test file for extraction; `Patch` library for worker mocking.

## Conventions to follow

- `{:ok, result}` / `{:error, reason}` tuples; error atoms = cause not symptom.
- No `IO.inspect`, no `Contract: Ix` prefixes in code (plain-language comments only).
- `#{inspect(reason)}` in Logger calls.
- Palm encoding ISO-8859-1 (codepagex) — N/A for alarm ints.
- Tests: ExUnit + Patch + stream_data; trace to contract items in plain language.

## Hard constraints

- `from_calendar_event/2` signature stays `{CalendarEvent.t(), non_neg_integer()} ->
  {CalendarEvent.t(), DatebookAppointment.t()}` (sole caller depends on it).
- DatebookAppointment field types fixed: `alarm` boolean, `alarm_advance`
  non_neg_integer, `alarm_advance_units` AlarmAdvanceUnit integer value (0/1/2).
- `rec_id = 0` means "new record" — untouched.
- Palm only supports ONE alarm per appointment.

## Out of scope

- Swift port (done, user-approved as-is), CalendarEvent resource/migration (done),
  C NIF (already packs), #34 all-day events, reverse (Palm→Apple) sync.

## Spec source order (user directive)

**Code wins over blueprint** where they disagree. Blueprint
(`docs/blueprints/alarms-31-blueprint.md`) is input; it gets deleted once the
contract exists. Known divergence already resolved: D7 (store raw list, pick at
sync time) — user decision, 2026-09-11.
