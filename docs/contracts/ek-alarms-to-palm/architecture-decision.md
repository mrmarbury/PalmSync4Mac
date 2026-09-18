# Architecture Decision — EK Alarms → Palm Alarm Mapping (#31, Layer 3)

## Decision

A dedicated **pure module `PalmSync4Mac.Utils.AlarmPicker`** owns alarm policy
(both directions eventually). Data flow:

```
Swift (done)                Elixir write path                Elixir sync path
event.alarms  ──port──▶  CalendarEventWorker ──▶ DB         AppointmentWorker (unchanged)
sorted, signed            AlarmPicker.clean/2   (cleaned      │
offsets                     + default fallback     list)      ▼
                                              CalendarEvent.alarms_seconds
                                                                        │
                                              AlarmPicker.to_palm_alarm/2 ◀─ pick_alarm config
                                                                        │
                                              DatebookAppointment alarm/advance/units
                                                                        │
                                              C NIF (unchanged) ──▶ Palm
```

- **Write path**: `CalendarEventWorker` calls `AlarmPicker.clean/2` before the
  existing upsert; both the stored attribute and the `new_alarms_seconds`
  upsert argument carry the cleaned list. Cleaning is Elixir's job; Swift stays
  a dumb provider (per engineer directive — capture as cross-cycle learning).
- **Sync path**: `DatebookAppointment.from_calendar_event/2` calls
  `AlarmPicker.to_palm_alarm/2` and maps the unit atom to the `AlarmAdvanceUnit`
  enum value. Sole caller (`AppointmentWorker`) unchanged.
- **Future**: the Palm→EK back-conversion (one `{advance, unit}` → offset
  seconds) lands in the same Utils module, which is why EventKit was deemed too
  narrow a namespace.

## Pattern alignment

- Utils-namespace pure module follows `PalmSync4Mac.Utils.TMTime` precedent.
- Worker stays thin orchestrator (config read + pure call + upsert), matching
  existing worker style.
- `from_calendar_event/2` remains a dumb mapper — policy extracted to AlarmPicker.

## Alternatives considered

1. **Private helpers in `DatebookAppointment`** — rejected: puts Apple sync
   policy into the Palm comms layer; hard to property-test in isolation; no home
   for the future back-conversion.
2. **`PalmSync4Mac.EventKit.AlarmPicker`** — rejected: EventKit namespace is too
   narrow once Palm→EK back-conversion exists (engineer decision).
3. **Cleaning in Swift before the port** — rejected: violates "Swift is a dumb
   provider interface; Elixir owns cleaning, policy, source of truth"
   (engineer decision).
4. **Cleaning at sync time inside `from_calendar_event` (store raw)** — rejected:
   DB would hold bogus positives; sync logic would carry a fallback branch; DB
   list would no longer be self-describing (engineer decision).

## Amendment (2026-09-12, post-VERIFY Step 7 finding): bounded advance + ceil-up ladder

**Discovery**: the Palm wire format packs alarm advance as ONE byte + unit byte —
max 255 per unit (255 min ≈ 4¼h, 255 h ≈ 10½d, 255 d ≈ 8mo). The blueprint's
"int is 32-bit signed, no practical protocol cap" was wrong (it described the
in-memory C struct, not the record layout). Unbounded advances wrapped on the
device (270 min → 14 min) or crashed the NIF path (bignum offsets).

**Decision (engineer, "never late" principle)**: `to_palm_alarm/2` bounds
`advance <= 255` and rounds UP when a value fits no clean unit — exact when
divisible, ceil to the next hour (≤ 255 h) or day (≤ 255 d), cap at 255 days
(the sole fires-later case). Rationale: an alarm that fires a little too early
can be snoozed; one that fires too late is missed.

**Alternatives rejected**:
- *Clamp to 255 in chosen unit* — 3 lines, but butchers odd values far from the
  bound (a 1-day-plus-3-minutes alarm would collapse to 4¼ h).
- *Closest representable across units* — best numeric fidelity, but needs
  cross-unit nearest-search with tie-breaking; more logic to verify than the
  guarantee it buys.
- *Drop unrepresentable alarms → default* — a 4.5 h alarm becoming 10 min loses
  far more intent than rounding up.

**Also fixed by this bound**: bignum absoluteDate offsets can no longer
overflow the C int or wire byte (invariant 12).

User-visible behavior documented in README "Known Limitations — Alarm Rounding".

## Structural changes

- New: `lib/palmsync4mac/utils/alarm_picker.ex`, `test/palmsync4mac/utils/alarm_picker_test.exs`
- Modified: `lib/palmsync4mac/event_kit/calendar_event_worker.ex` (+ its test),
  `lib/palmsync4mac/comms/pidlp/datebook_appointment.ex` (+ its test)
- Untouched: Swift port, C NIF, CalendarEvent resource, migrations, config keys
