defmodule PalmSync4Mac.Comms.Pidlp.DatebookAppointmentTest do
  @moduledoc """
  Tests for DatebookAppointment.from_calendar_event/2 alarm mapping plus
  regression coverage for the pre-existing field mappings.
  """
  use ExUnit.Case, async: false

  alias PalmSync4Mac.Comms.Pidlp.AlarmAdvanceUnit
  alias PalmSync4Mac.Comms.Pidlp.DatebookAppointment
  alias PalmSync4Mac.Comms.Pidlp.DayOfMonthType
  alias PalmSync4Mac.Comms.Pidlp.RepeatType
  alias PalmSync4Mac.Comms.Pidlp.TM
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent
  alias PalmSync4Mac.Utils.TMTime

  @start_date ~U[2026-09-12 10:00:00Z]
  @end_date ~U[2026-09-12 11:00:00Z]

  setup do
    prior_pick = Application.get_env(:palm_sync_4_mac, :pick_alarm)
    on_exit(fn -> Application.put_env(:palm_sync_4_mac, :pick_alarm, prior_pick) end)
    :ok
  end

  defp put_pick(pick), do: Application.put_env(:palm_sync_4_mac, :pick_alarm, pick)

  defp build_event(overrides \\ []) do
    struct!(
      %CalendarEvent{
        title: "Test Event",
        start_date: @start_date,
        end_date: @end_date,
        alarms_seconds: []
      },
      overrides
    )
  end

  defp build_appointment(event, rec_id \\ 0) do
    assert {^event, %DatebookAppointment{} = appointment} =
             DatebookAppointment.from_calendar_event(event, rec_id)

    appointment
  end

  defp alarm_triple(%DatebookAppointment{} = appointment),
    do: {appointment.alarm, appointment.alarm_advance, appointment.alarm_advance_units}

  describe "from_calendar_event/2 alarm mapping" do
    test "empty alarms_seconds means no alarm under :first pick" do
      # An empty stored list is the encoding of "user has no alarm", so
      # the appointment must carry the struct-default alarm triple.
      put_pick(:first)

      appointment = build_event(alarms_seconds: []) |> build_appointment()

      assert alarm_triple(appointment) == {false, 0, AlarmAdvanceUnit.Minutes.value()}
    end

    test "empty alarms_seconds means no alarm under :last pick" do
      # An empty stored list is the encoding of "user has no alarm", so
      # the appointment must carry the struct-default alarm triple.
      put_pick(:last)

      appointment = build_event(alarms_seconds: []) |> build_appointment()

      assert alarm_triple(appointment) == {false, 0, AlarmAdvanceUnit.Minutes.value()}
    end

    test ":first pick selects the farthest offset and maps it to days" do
      # With :first the first offset (-86_400 s, farthest from the start
      # on an ascending list) becomes a 1-day alarm.
      put_pick(:first)

      appointment = build_event(alarms_seconds: [-86_400, -600]) |> build_appointment()

      assert alarm_triple(appointment) == {true, 1, AlarmAdvanceUnit.Days.value()}
    end

    test ":last pick selects the closest offset and maps it to minutes" do
      # With :last the last offset (-600 s, closest to the start on an
      # ascending list) becomes a 10-minute alarm.
      put_pick(:last)

      appointment = build_event(alarms_seconds: [-86_400, -600]) |> build_appointment()

      assert alarm_triple(appointment) == {true, 10, AlarmAdvanceUnit.Minutes.value()}
    end

    test "a single-element defaulted list maps identically under :first" do
      # Default substitution stores exactly one offset, so both picks
      # must select the same alarm.
      put_pick(:first)

      appointment = build_event(alarms_seconds: [-600]) |> build_appointment()

      assert alarm_triple(appointment) == {true, 10, AlarmAdvanceUnit.Minutes.value()}
    end

    test "a single-element defaulted list maps identically under :last" do
      # Default substitution stores exactly one offset, so both picks
      # must select the same alarm.
      put_pick(:last)

      appointment = build_event(alarms_seconds: [-600]) |> build_appointment()

      assert alarm_triple(appointment) == {true, 10, AlarmAdvanceUnit.Minutes.value()}
    end

    test "an offset divisible by hours maps to the Hours unit" do
      # A 2-hour offset divides cleanly into hours, so the unit enum
      # must be Hours (not 120 minutes).
      put_pick(:last)

      appointment = build_event(alarms_seconds: [-7200]) |> build_appointment()

      assert alarm_triple(appointment) == {true, 2, AlarmAdvanceUnit.Hours.value()}
    end

    test "an offset divisible by days maps to the Days unit" do
      # A 2-day offset divides cleanly into days, so the unit enum must
      # be Days (the largest exact unit).
      put_pick(:last)

      appointment = build_event(alarms_seconds: [-172_800]) |> build_appointment()

      assert alarm_triple(appointment) == {true, 2, AlarmAdvanceUnit.Days.value()}
    end

    test "offset 0 is a valid at-start alarm" do
      # Zero means "alarm at event start": alarm true, advance 0, unit
      # Minutes (the advance is 0, so the unit is cosmetic).
      put_pick(:last)

      appointment = build_event(alarms_seconds: [0]) |> build_appointment()

      assert alarm_triple(appointment) == {true, 0, AlarmAdvanceUnit.Minutes.value()}
    end
  end

  describe "from_calendar_event/2 existing mappings regression" do
    test "fully populated event keeps description, times, note, location and event flag" do
      # The non-alarm mappings predate the alarm feature and must stay
      # byte-identical: description ISO-8859-1 encoded, begin/end from
      # event times, note built from notes and URL, location encoded.
      put_pick(:last)

      appointment =
        build_event(
          title: "Café Sync",
          notes: "Line one",
          url: "https://example.com",
          location: "Paris"
        )
        |> build_appointment()

      assert appointment.description == "Caf" <> <<0xE9>> <> " Sync"
      assert appointment.note == "Line one\nURL: https://example.com"
      assert appointment.location == "Paris"
      assert appointment.event == false

      # begin/end replicate C's localtime(): they map the event times through
      # unix_to_tm in the host zone, so compare against the same pipeline
      # instead of environment-dependent wall-clock fields.
      assert appointment.begin == TMTime.unix_to_tm(DateTime.to_unix(@start_date))
      assert appointment.end == TMTime.unix_to_tm(DateTime.to_unix(@end_date))
      assert %TM{} = appointment.begin
    end

    test "note omits a missing URL and ISO-8859-1 encodes non-ASCII notes" do
      # build_note joins only the parts that are present and
      # to_palm_encoding converts them to ISO-8859-1 for the Palm.
      put_pick(:last)

      appointment =
        build_event(title: "Plain", notes: "Résumé", url: nil) |> build_appointment()

      assert appointment.note == "R" <> <<0xE9>> <> "sum" <> <<0xE9>>
    end

    test "a timeless event (start == end) sets the event flag" do
      # A zero-length event is a "timeless" entry on the Palm.
      put_pick(:last)

      appointment =
        build_event(start_date: @start_date, end_date: @start_date) |> build_appointment()

      assert appointment.event == true
    end

    test "rec_id is passed through unchanged, 0 still means new record" do
      # rec_id is the Palm record id: non-zero on updates, 0 for new
      # records (the Palm assigns the real id on first write).
      put_pick(:last)

      assert build_appointment(build_event(), 987_654).rec_id == 987_654
      assert build_appointment(build_event()).rec_id == 0
    end

    test "all other struct fields keep their defaults" do
      # No field other than the alarm triple and the event-mirroring
      # fields may drift from the struct defaults.
      put_pick(:last)

      appointment = build_event() |> build_appointment()

      assert appointment.repeat_type == RepeatType.None.value()
      assert appointment.repeat_forever == false
      assert appointment.repeat_frequency == 0
      assert appointment.repeat_day == DayOfMonthType.FirstSun.value()
      assert appointment.repeat_days == [0, 0, 0, 0, 0, 0, 0]
      assert appointment.repeat_weekstart == 0
      assert appointment.exceptions_count == 0
      assert appointment.exceptions_actual == []
      assert %TM{} = appointment.repeat_end
    end
  end
end
