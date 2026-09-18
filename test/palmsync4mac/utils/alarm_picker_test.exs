defmodule PalmSync4Mac.Utils.AlarmPickerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PalmSync4Mac.Utils.AlarmPicker

  @default 600

  describe "clean/2" do
    test "drops positive offsets from a mixed list, keeping the rest in order" do
      # Positive offsets would make the alarm fire after the event already
      # started, so they are unrepresentable user intent: only zero and
      # negative offsets survive, in their original order.
      assert AlarmPicker.clean([-900, 60, -300, 7200, 0], default: @default) == [-900, -300, 0]
    end

    test "non-empty input with only positive offsets falls back to [-default]" do
      # The user did set alarms, they just cannot be represented; falling
      # back to the configured default keeps "this event has an alarm"
      # true instead of silently dropping the user's intent entirely.
      assert AlarmPicker.clean([60, 300], default: @default) == [-@default]
    end

    test "a non-positive default is a config typo and must crash loudly" do
      # The default comes from :default_alarm_seconds in config; a zero or
      # negative value would silently store a bogus offset ([0] or even a
      # positive number), so both clauses reject it with FunctionClauseError.
      assert_raise FunctionClauseError, fn -> AlarmPicker.clean([], default: 0) end
      assert_raise FunctionClauseError, fn -> AlarmPicker.clean([-600], default: 0) end
      assert_raise FunctionClauseError, fn -> AlarmPicker.clean([60], default: -600) end
    end
  end

  describe "to_palm_alarm/2" do
    test "empty list converts to {false, 0, :minutes}" do
      # An empty list is the storage encoding of "the user has no alarm",
      # so the appointment must carry alarm: false.
      assert AlarmPicker.to_palm_alarm([], pick_alarm: :first) == {false, 0, :minutes}
    end

    test "pick :first takes the first element" do
      # :first means the alarm farthest from the event start, which is the
      # head of an ascending offset list.
      assert AlarmPicker.to_palm_alarm([-900, -300, -60], pick_alarm: :first) ==
               {true, 15, :minutes}
    end

    test "pick :last takes the last element" do
      # :last means the alarm closest to the event start, which is the
      # tail of an ascending offset list.
      assert AlarmPicker.to_palm_alarm([-900, -300, -60], pick_alarm: :last) ==
               {true, 1, :minutes}
    end

    test "a single-element list matches either pick" do
      # Default substitution produces exactly one offset, so both picks
      # must agree on it.
      assert AlarmPicker.to_palm_alarm([-3600], pick_alarm: :first) == {true, 1, :hours}
      assert AlarmPicker.to_palm_alarm([-3600], pick_alarm: :last) == {true, 1, :hours}
    end

    test "picked offset 0 converts to {true, 0, :minutes}" do
      # Zero is a deliberate "alarm at event start"; since the advance is
      # 0 the unit is cosmetic, and minutes is what the Palm displays.
      assert AlarmPicker.to_palm_alarm([0], pick_alarm: :first) == {true, 0, :minutes}
      assert AlarmPicker.to_palm_alarm([-300, 0], pick_alarm: :last) == {true, 0, :minutes}
    end

    test "converts non-zero offsets per the divisibility rule" do
      # Values that divide cleanly keep their natural unit and convert
      # exactly; when several units spell the same instant exactly
      # (7_200 s = 120 minutes = 2 hours), the largest unit wins.
      expectations = [
        {-90, {true, 2, :minutes}},
        {-3600, {true, 1, :hours}},
        {-5400, {true, 90, :minutes}},
        {-7200, {true, 2, :hours}},
        {-86_400, {true, 1, :days}},
        {-90_000, {true, 25, :hours}},
        {-90_060, {true, 26, :hours}},
        {-172_800, {true, 2, :days}}
      ]

      for {offset, expected} <- expectations do
        assert AlarmPicker.to_palm_alarm([offset], pick_alarm: :first) == expected
      end
    end

    test "bounds advance to the one-byte wire format on the unit ladder" do
      # 255 minutes / 255 hours / 255 days are the exact tops of each
      # ladder rung — one second more cannot be spelled in that unit and
      # must flip to the next rung, rounding up so the alarm never fires
      # late. Random generators almost never hit these flip points
      # exactly, so they are pinned here as examples.
      expectations = [
        # exact tops of each rung
        {-15_300, {true, 255, :minutes}},
        {-918_000, {true, 255, :hours}},
        {-22_032_000, {true, 255, :days}},
        # first ladder rungs (ceil UP to the next representable unit)
        {-15_301, {true, 5, :hours}},
        {-16_200, {true, 5, :hours}},
        {-86_580, {true, 25, :hours}},
        {-918_001, {true, 11, :days}},
        # ceil-up may land exactly on a larger unit; the same instant is
        # then spelled in the largest unit that fits the one-byte advance
        {-3_599, {true, 1, :hours}},
        {-86_399, {true, 1, :days}},
        {-172_799, {true, 2, :days}},
        # past every bound: cap at 255 days (the sole fires-later case)
        {-22_032_001, {true, 255, :days}},
        {-54_000_000, {true, 255, :days}},
        {-1_000_000_000_000_000, {true, 255, :days}}
      ]

      for {offset, expected} <- expectations do
        assert AlarmPicker.to_palm_alarm([offset], pick_alarm: :first) == expected
      end
    end
  end

  describe "properties" do
    property "clean/2 never drops elements <= 0, never keeps positives, order preserved" do
      check all(
              offsets <- list_of(integer()),
              default <- integer(1..100_000)
            ) do
        cleaned = AlarmPicker.clean(offsets, default: default)

        # Any list that is empty or has at least one keepable offset must
        # keep exactly its non-positive elements; only a non-empty list of
        # purely positive offsets falls back to the default.
        if offsets == [] or Enum.any?(offsets, &(&1 <= 0)) do
          assert cleaned == Enum.reject(offsets, &(&1 > 0))
        else
          assert cleaned == [-default]
        end
      end
    end

    property "clean/2 output is empty iff input is empty" do
      check all(
              offsets <- list_of(integer()),
              default <- integer(1..100_000)
            ) do
        cleaned = AlarmPicker.clean(offsets, default: default)
        assert cleaned == [] == (offsets == [])
      end
    end

    property "to_palm_alarm/2 advance always fits the one-byte wire format (0..255) with a valid unit" do
      check all(
              offsets <- list_of(integer(), min_length: 1),
              pick <- member_of([:first, :last])
            ) do
        # Whatever integers arrive (negatives, bignums, unsorted), the
        # result must be a wire-safe triple.
        assert {true, advance, unit} = AlarmPicker.to_palm_alarm(offsets, pick_alarm: pick)
        assert advance in 0..255
        assert unit in [:minutes, :hours, :days]
      end
    end

    property "to_palm_alarm/2 never fires later than the requested offset up to 255 days" do
      check all(
              offset <- integer(-22_032_000..22_032_000),
              pick <- member_of([:first, :last])
            ) do
        {true, advance, unit} = AlarmPicker.to_palm_alarm([offset], pick_alarm: pick)
        assert advance * unit_seconds(unit) >= abs(offset)
      end
    end

    property "to_palm_alarm/2 converts minute-divisible offsets up to 255 minutes exactly" do
      check all(minutes <- integer(0..255)) do
        offset = minutes * 60
        {true, advance, unit} = AlarmPicker.to_palm_alarm([-offset], pick_alarm: :first)
        assert advance * unit_seconds(unit) == offset
      end
    end

    property "to_palm_alarm/2 ceil overshoot is less than one unit across the ladder ranges" do
      check all(offset <- integer(1..22_032_000)) do
        {true, advance, unit} = AlarmPicker.to_palm_alarm([offset], pick_alarm: :first)
        overshoot = advance * unit_seconds(unit) - offset
        assert overshoot >= 0 and overshoot < unit_seconds(unit)
      end
    end

    property "to_palm_alarm/2 bignum offsets past every bound cap at 255 days without overflow" do
      check all(
              offset <- integer(22_032_001..1_000_000_000_000),
              pick <- member_of([:first, :last])
            ) do
        # Absurdly large offsets (e.g. from an absoluteDate far in the
        # past) must clamp before the value reaches the C int / wire byte.
        assert AlarmPicker.to_palm_alarm([offset], pick_alarm: pick) == {true, 255, :days}
        assert AlarmPicker.to_palm_alarm([-offset], pick_alarm: pick) == {true, 255, :days}
      end
    end

    property "to_palm_alarm/2 returns the earliest time the Palm can express, ties to the largest unit" do
      check all(offset <- integer(1..22_032_000)) do
        {true, advance, unit} = AlarmPicker.to_palm_alarm([-offset], pick_alarm: :first)
        result = advance * unit_seconds(unit)

        # The alarm may ring early, never late.
        assert result >= offset

        # And no time the Palm can express may sit strictly between the
        # requested instant and the chosen alarm — otherwise a closer
        # representable alarm was passed over.
        refute expressible_value_between?(offset, result)

        # When several units spell the same instant exactly (3_600 s is
        # both 1 hour and 60 minutes), the largest fitting unit is the
        # canonical answer.
        assert_largest_exact_unit(result, unit)
      end
    end
  end

  @minute_seconds 60
  @hour_seconds 3_600
  @day_seconds 86_400

  # A Palm can express m*60, h*3_600 and d*86_400 seconds for counts 1..255.
  # To decide whether any such value lies strictly between the requested
  # offset and the returned result, only the counts whose value can fall
  # into that window are enumerated — an empty (and cheap) range whenever
  # the result equals the requested instant itself.
  defp expressible_value_between?(offset, result) do
    candidate_between?(offset, result, @minute_seconds) or
      candidate_between?(offset, result, @hour_seconds) or
      candidate_between?(offset, result, @day_seconds)
  end

  defp candidate_between?(offset, result, unit_seconds) do
    first = max(1, div(offset, unit_seconds) + 1)
    last = min(255, div(result - 1, unit_seconds))

    first <= last and Enum.any?(first..last, fn count -> count * unit_seconds > offset end)
  end

  defp assert_largest_exact_unit(result, unit) do
    exactly_representable? = fn seconds ->
      rem(result, seconds) == 0 and div(result, seconds) <= 255
    end

    cond do
      exactly_representable?.(@day_seconds) -> assert unit == :days
      exactly_representable?.(@hour_seconds) -> assert unit == :hours
      true -> assert unit == :minutes
    end
  end

  defp unit_seconds(:minutes), do: 60
  defp unit_seconds(:hours), do: 3_600
  defp unit_seconds(:days), do: 86_400
end
