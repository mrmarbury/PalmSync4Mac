defmodule PalmSync4Mac.Utils.AlarmPickerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PalmSync4Mac.Utils.AlarmPicker

  @default 600

  describe "clean/2" do
    test "empty input yields an empty list" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — output is empty iff input is empty
      assert AlarmPicker.clean([], default: @default) == []
    end

    test "keeps zero and negative offsets in original order" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — every kept element appears in input with offset <= 0, order preserved
      assert AlarmPicker.clean([-900, -300, 0], default: @default) == [-900, -300, 0]
    end

    test "drops positive offsets from a mixed list, keeping the rest in order" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — no valid element is dropped, no positive element is kept
      assert AlarmPicker.clean([-900, 60, -300, 7200, 0], default: @default) == [-900, -300, 0]
    end

    test "keeps duplicate offsets (no deduplication)" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — no valid element is ever dropped, duplicates included
      assert AlarmPicker.clean([-600, -300, -300, 0, 900], default: @default) == [
               -600,
               -300,
               -300,
               0
             ]
    end

    test "non-empty input with only positive offsets falls back to [-default]" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — input non-empty and all positive → output == [-default]
      assert AlarmPicker.clean([60, 300], default: @default) == [-@default]
    end

    test "non-empty input with at least one valid offset never inserts the default" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — default is consulted only when filtering empties a non-empty list
      assert AlarmPicker.clean([0, 900], default: @default) == [0]
    end
  end

  describe "to_palm_alarm/2" do
    test "empty list converts to {false, 0, :minutes}" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — empty list → {false, 0, :minutes}
      assert AlarmPicker.to_palm_alarm([], pick: :first) == {false, 0, :minutes}
    end

    test "pick :first takes the first element" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — picked offset = List.first of input when pick is :first
      assert AlarmPicker.to_palm_alarm([-900, -300, -60], pick: :first) == {true, 15, :minutes}
    end

    test "pick :last takes the last element" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — picked offset = List.last of input when pick is :last
      assert AlarmPicker.to_palm_alarm([-900, -300, -60], pick: :last) == {true, 1, :minutes}
    end

    test "a single-element list matches either pick" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — on a defaulted single-element list both picks agree
      assert AlarmPicker.to_palm_alarm([-3600], pick: :first) == {true, 1, :hours}
      assert AlarmPicker.to_palm_alarm([-3600], pick: :last) == {true, 1, :hours}
    end

    test "picked offset 0 converts to {true, 0, :minutes}" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — picked offset 0 → {true, 0, :minutes} (explicit override)
      assert AlarmPicker.to_palm_alarm([0], pick: :first) == {true, 0, :minutes}
      assert AlarmPicker.to_palm_alarm([-300, 0], pick: :last) == {true, 0, :minutes}
    end

    test "converts non-zero offsets per the divisibility rule" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — divisible values keep their
      # natural unit and convert exactly (invariant 8); odd values ceil UP so
      # the alarm never fires later than requested (invariant 10)

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
        assert AlarmPicker.to_palm_alarm([offset], pick: :first) == expected
      end
    end

    test "bounds advance to the one-byte wire format on the unit ladder" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — advance is always 0..255
      # (invariants 6, 12); the ceil ladder never fires later except the >255d
      # cap (invariants 9, 10)

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
        # past every bound: cap at 255 days (the sole fires-later case)
        {-22_032_001, {true, 255, :days}},
        {-54_000_000, {true, 255, :days}},
        {-1_000_000_000_000_000, {true, 255, :days}}
      ]

      for {offset, expected} <- expectations do
        assert AlarmPicker.to_palm_alarm([offset], pick: :first) == expected
      end
    end
  end

  describe "properties" do
    property "clean/2 never drops elements <= 0, never keeps positives, order preserved" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — keeps all offsets <= 0 in order; never keeps a positive
      check all(
              offsets <- list_of(integer()),
              default <- integer(1..100_000)
            ) do
        cleaned = AlarmPicker.clean(offsets, default: default)

        if offsets == [] or Enum.any?(offsets, &(&1 <= 0)) do
          assert cleaned == Enum.reject(offsets, &(&1 > 0))
        else
          assert cleaned == [-default]
        end
      end
    end

    property "clean/2 output is empty iff input is empty" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — output empty iff input empty, for every possible default
      check all(
              offsets <- list_of(integer()),
              default <- integer(1..100_000)
            ) do
        cleaned = AlarmPicker.clean(offsets, default: default)
        assert cleaned == [] == (offsets == [])
      end
    end

    property "to_palm_alarm/2 advance always fits the one-byte wire format (0..255) with a valid unit" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — non-empty input of ANY
      # integers (negatives, bignums) → {true, advance, unit} with advance in
      # 0..255 (invariants 6, 12)
      check all(
              offsets <- list_of(integer(), min_length: 1),
              pick <- member_of([:first, :last])
            ) do
        assert {true, advance, unit} = AlarmPicker.to_palm_alarm(offsets, pick: pick)
        assert advance in 0..255
        assert unit in [:minutes, :hours, :days]
      end
    end

    property "to_palm_alarm/2 never fires later than the requested offset up to 255 days" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — advance * unit_seconds >=
      # offset for every offset <= 22_032_000 (invariants 9, 10)
      check all(
              offset <- integer(-22_032_000..22_032_000),
              pick <- member_of([:first, :last])
            ) do
        {true, advance, unit} = AlarmPicker.to_palm_alarm([offset], pick: pick)
        assert advance * unit_seconds(unit) >= abs(offset)
      end
    end

    property "to_palm_alarm/2 converts minute-divisible offsets up to 255 minutes exactly" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — rem(offset, 60) == 0 and
      # offset <= 15_300 → advance * unit_seconds == offset (invariants 8, 10)
      check all(minutes <- integer(0..255)) do
        offset = minutes * 60
        {true, advance, unit} = AlarmPicker.to_palm_alarm([-offset], pick: :first)
        assert advance * unit_seconds(unit) == offset
      end
    end

    property "to_palm_alarm/2 ceil overshoot is less than one unit across the ladder ranges" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — 0 <= advance * unit_seconds
      # - offset < unit_seconds for every offset <= 22_032_000 (invariant 10)
      check all(offset <- integer(1..22_032_000)) do
        {true, advance, unit} = AlarmPicker.to_palm_alarm([offset], pick: :first)
        overshoot = advance * unit_seconds(unit) - offset
        assert overshoot >= 0 and overshoot < unit_seconds(unit)
      end
    end

    property "to_palm_alarm/2 bignum offsets past every bound cap at 255 days without overflow" do
      # Contract: PalmSync4Mac.Utils.AlarmPicker — any offset > 22_032_000
      # (incl. absurd bignums) → {true, 255, :days}; downstream C int / wire
      # byte can never wrap (invariants 6, 12)
      check all(
              offset <- integer(22_032_001..1_000_000_000_000),
              pick <- member_of([:first, :last])
            ) do
        assert AlarmPicker.to_palm_alarm([offset], pick: pick) == {true, 255, :days}
        assert AlarmPicker.to_palm_alarm([-offset], pick: pick) == {true, 255, :days}
      end
    end
  end

  defp unit_seconds(:minutes), do: 60
  defp unit_seconds(:hours), do: 3_600
  defp unit_seconds(:days), do: 86_400
end
