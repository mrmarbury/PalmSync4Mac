# #31 — Propagate EKEvent Alarms/Reminders to Palm

**Issue**: https://github.com/mrmarbury/PalmSync4Mac/issues/31
**Epic**: #30 (Apple→Palm One-Way Sync Gap Analysis)
**Mode**: APP (Augmented Pair Programming)
**Date**: 2026-09-04

---

## Problem

Apple Calendar events with alarms/reminders (EKAlarm) lose them during sync. The Palm side is fully ready — `DatebookAppointment` has `alarm`, `alarm_advance`, `alarm_advance_units` fields, the C NIF packs them into `pilot_appointment.alarm/advance/advanceUnits`. The gap is upstream: Apple alarm data never flows in.

## Three-Layer Gap

1. **Swift port** (`ports/Sources/EKCalendarInterface/Main.swift`): doesn't extract `event.alarms` (`[EKAlarm]`)
2. **CalendarEvent Ash resource** (`lib/palmsync4mac/entity/event_kit/calendar_event.ex`): no alarm fields
3. **`DatebookAppointment.from_calendar_event/2`** (`lib/palmsync4mac/comms/pidlp/datebook_appointment.ex`): defaults `alarm: false, alarm_advance: 0`

## Decisions

### D1: Swift sends all alarms, Elixir picks

Swift extracts `event.alarms` as a list and sends the whole thing up the port. Elixir reads the `:pick_alarm` config and decides which alarm to keep. Swift stays a dumb extractor; all sync logic lives in Elixir.

**Rationale**: Matches the existing architecture pattern — Swift is a thin EventKit bridge, all sync logic lives in Elixir. Config stays in Elixir where all the other flags live (`palm_viewer_id`, `apple_calendar_names`).

### D2: Both `relativeOffset` and `absoluteDate` are supported

Apple `EKAlarm` has two modes:
- `relativeOffset` (TimeInterval seconds, negative = before start)
- `absoluteDate` (fixed Date)

Both are converted to an offset and then to Palm's `alarm_advance` + `alarm_advance_units`.

**Rationale**: Rocco's brief only covered `relativeOffset` and would silently drop absolute-date alarms. We handle both.

### D3: Offset → unit conversion is dynamic

`alarm_advance_units` is picked dynamically per alarm, not hardcoded to `:minutes`:

| Offset (seconds) | Unit | `alarm_advance` |
|---|---|---|
| < 3600 | Minutes (`:minutes`, 0) | `offset / 60` |
| < 86400 and divisible by 3600 | Hours (`:hours`, 1) | `offset / 3600` |
| else | Days (`:days`, 2) | `offset / 86400` |

Where `offset = abs(relativeOffset)` or `abs(absoluteDate - event.startDate)`.

**Rationale**: Palm supports minutes/hours/days. Picking the largest unit that divides cleanly gives cleaner values and uses the full range.

### D4: Bogus alarms fall back to `:default_alarm_seconds`

Apple allows alarms *after* event start (`relativeOffset > 0` or `absoluteDate > event.startDate`). Palm `alarm_advance` is "advance time" — semantics don't map to "after." Instead of dropping the alarm, fall back to `:default_alarm_seconds` (default 600s = 10 min) — set `alarm: true, alarm_advance: 600, alarm_advance_units: :seconds`.

Same fallback applies to any unusable alarm (no `relativeOffset` and no `absoluteDate`).

**Rationale**: Dropping the alarm silently loses user intent. A 10-minute default is a reasonable fallback that preserves "this event has an alarm" — the user still gets notified on the Palm.

### D5: `:pick_alarm` global config flag

New config key under `:palm_sync_4_mac`:

```elixir
config :palm_sync_4_mac,
  pick_alarm: :last,           # :first or :last
  default_alarm_seconds: 600   # fallback for bogus alarms (positive offset)
```

- `:first` — take the first alarm from sorted `event.alarms` (farthest from event date)
- `:last` — take the last alarm (closest to event date)

Determines which alarm wins when Apple has multiple. Palm only supports one alarm. Default is `:last`.

### D5b: `:default_alarm_seconds` config

```elixir
default_alarm_seconds: 600
```

Fallback value (in seconds) for bogus alarms — positive offsets, alarms with no usable offset data. The alarm is still set (`alarm: true`), just with the default advance. Default is 600s (10 minutes).

### D6: No batch with #34 (all-day events)

#31 ships alone. #34 (all-day) can follow the same pattern in a separate PR if we want.

### D7: CalendarEvent stores the picked alarm only

The Ash resource stores the *result* of the pick: `alarm` (boolean), `alarm_advance` (integer), `alarm_advance_units` (integer). We don't persist all Apple alarms — just the one Elixir picked.

### D8: Picking + unit-conversion module location — deferred

Where the pick + unit-conversion logic lives (dedicated module like `PalmSync4Mac.EventKit.AlarmPicker` vs folded into the worker) is decided on the go during BUILD. Not a design decision that needs to be made upfront.

---

## Alarm Selection Algorithm

```
1. Read :pick_alarm config (:first or :last)
2. Get EKAlarm list from Swift (each has relative_offset, absolute_date — both nullable)
3. Pick alarm based on :first or :last
4. Compute offset_seconds:
   - If alarm.absoluteDate != nil: offset = (absoluteDate - event.startDate) in seconds
   - Else: offset = alarm.relativeOffset (0 if never set = "at event start")
5. If offset_seconds > 0 (after start): fall back to `:default_alarm_seconds` (600s) → convert: `alarm_advance=10, alarm_advance_units=:minutes`
6. offset_seconds = abs(offset_seconds)
7. Pick unit + advance:
   - < 3600: minutes, advance = offset_seconds / 60
   - < 86400 and (offset_seconds % 3600 == 0): hours, advance = offset_seconds / 3600
   - else: days, advance = offset_seconds / 86400
8. Store: alarm=true, alarm_advance=advance, alarm_advance_units=unit
```

If no alarm at all (empty list): `alarm=false, alarm_advance=0, alarm_advance_units=:minutes` (existing defaults).

---

## Files to Touch

### Swift

- `ports/Sources/EKCalendarInterface/Main.swift` — extract `event.alarms` into a list, each entry: `{relative_offset: seconds | null, absolute_date: ISO8601 | null}`
- `ports/Tests/` — verify alarm extraction (use real `EKEvent` objects per existing test pattern)

### Elixir

- `config/config.exs` — add `pick_alarm: :last` and `default_alarm_seconds: 600` config keys
- `lib/palmsync4mac/entity/event_kit/calendar_event.ex` — add 3 attributes: `alarm` (boolean), `alarm_advance` (integer), `alarm_advance_units` (integer); add to `create_or_update` accept list
- Ash migration — `mix ash_sqlite.generate_migrations` + `mix ash_sqlite.migrate` (dev + test DBs)
- `lib/palmsync4mac/comms/pidlp/datebook_appointment.ex` — map 3 fields in `from_calendar_event/2`
- Picking + unit-conversion logic — location TBD (see D8)
- Elixir tests — verify mapping, picking (`:first`/`:last`), unit conversion, positive offset skip

### C NIF

- No changes. `pidlp.c` already packs `alarm_advance` → `pilot_appointment.advance` and `alarm_advance_units` → `pilot_appointment.advanceUnits` at lines 422-423 and 550-551.

---

## Palm Side (Already Ready)

`DatebookAppointment` struct (`lib/palmsync4mac/comms/pidlp/datebook_appointment.ex`):

| Field | Type | Default |
|---|---|---|
| `alarm` | boolean | `false` |
| `alarm_advance` | non_neg_integer | `0` |
| `alarm_advance_units` | `AlarmAdvanceUnit` enum | `:minutes` (0) |

`AlarmAdvanceUnit` enum (`lib/palmsync4mac/comms/pidlp.ex`):
- `Minutes` = 0
- `Hours` = 1
- `Days` = 2

C struct (both `Appointment_t` and `CalendarEvent_t`): `int alarm, advance, advanceUnits` — `int` is 32-bit signed, no practical protocol cap.

---

## Trust Spectrum

This is a **reversible, medium blast radius** change — additive fields, no removals, no C NIF changes. AI can act, human reviews diff. The config flag addition and Ash migration are mechanical (on the loop). The picking logic and unit conversion are well-specified (on the loop with review).

---

## Open Items (decide on the go)

- [ ] Picking + unit-conversion module location (D8)
- [ ] Swift test fixture approach (check existing `ports/Tests/` MockEventStore pattern first)
- [ ] Whether to log bogus-alarm fallbacks (positive offset, no data) at debug or info level
