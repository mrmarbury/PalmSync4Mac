defmodule PalmSync4Mac.Utils.AlarmPicker do
  @moduledoc """
  Pure alarm policy: cleans raw alarm offsets and converts the picked offset into Palm's alarm triple.
  """

  @minute_seconds 60
  @hour_seconds 3_600
  @day_seconds 86_400

  # Palm packs the alarm advance as ONE byte + a unit byte: 0..255 per unit.
  @max_advance 255
  @max_minute_offset 15_300
  @max_hour_offset 918_000
  @max_day_offset 22_032_000

  @type unit :: :minutes | :hours | :days

  @doc """
  Keeps every offset `<= 0` in original order; substitutes `[-default]` when a
  non-empty input consisted solely of positive offsets.
  """
  @spec clean(list(integer()), default: pos_integer()) :: list(integer())
  def clean([], _opts), do: []

  def clean(alarms_seconds, default: default) do
    case for(offset <- alarms_seconds, offset <= 0, do: offset) do
      [] -> [-default]
      kept -> kept
    end
  end

  @doc """
  Picks one offset per `:pick` and converts it to the Palm alarm triple.

  The advance always fits the one-byte wire format (0..255). Divisible values
  keep their natural unit; odd values round UP to the next representable unit
  (better to alarm too early than too late). Only offsets beyond 255 days cap
  at 255 days — the sole case that fires later than requested.
  """
  @spec to_palm_alarm(list(integer()), pick: :first | :last) ::
          {boolean(), non_neg_integer(), unit()}
  def to_palm_alarm([], _opts), do: {false, 0, :minutes}

  def to_palm_alarm(alarms_seconds, pick: pick) do
    offset = abs(picked(alarms_seconds, pick))
    {advance, unit} = advance_and_unit(offset)
    {true, advance, unit}
  end

  defp picked(alarms_seconds, :first), do: List.first(alarms_seconds)
  defp picked(alarms_seconds, :last), do: List.last(alarms_seconds)

  defp advance_and_unit(0), do: {0, :minutes}

  # Divisible values first: keep the natural unit when it fits one byte.
  defp advance_and_unit(offset)
       when rem(offset, @day_seconds) == 0 and div(offset, @day_seconds) <= @max_advance,
       do: {div(offset, @day_seconds), :days}

  defp advance_and_unit(offset)
       when rem(offset, @hour_seconds) == 0 and div(offset, @hour_seconds) <= @max_advance,
       do: {div(offset, @hour_seconds), :hours}

  # Ceil ladder for values that fit no clean unit: round UP, never later.
  defp advance_and_unit(offset) when offset <= @max_minute_offset,
    do: {ceil_div(offset, @minute_seconds), :minutes}

  defp advance_and_unit(offset) when offset <= @max_hour_offset,
    do: {ceil_div(offset, @hour_seconds), :hours}

  defp advance_and_unit(offset) when offset <= @max_day_offset,
    do: {ceil_div(offset, @day_seconds), :days}

  # Beyond 255 days: cap (the only fires-later case).
  defp advance_and_unit(_offset), do: {@max_advance, :days}

  defp ceil_div(offset, unit_seconds), do: div(offset + unit_seconds - 1, unit_seconds)
end
