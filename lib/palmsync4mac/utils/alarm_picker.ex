defmodule PalmSync4Mac.Utils.AlarmPicker do
  @moduledoc """
  Pure alarm policy: cleans raw alarm offsets and converts the picked offset into Palm's alarm triple.

  The Palm device stores an alarm as ONE byte of advance plus ONE byte of
  unit (minutes, hours or days), so the advance is capped at 255 in
  whichever unit is used: 255 minutes is about 4¼ hours, 255 hours about
  10½ days, 255 days about 8 months. Apple's EventKit, in contrast,
  allows arbitrary second-granular offsets — squeezing those into the
  one-byte envelope without ever firing late is this module's whole job.

  The policy: when the requested offset divides cleanly into a unit that
  fits one byte, it is represented exactly, preferring the largest such
  unit (2 days, not 48 hours). Every other value is rounded UP to the
  next representable hour or day so the alarm never fires later than
  requested — a too-early alarm can be snoozed, a late one is simply
  missed. The sole exception is the cap: offsets beyond 255 days clamp
  to 255 days, the only case where the alarm fires later than the user
  asked for.
  """

  @minute_seconds 60
  @hour_seconds 3_600
  @day_seconds 86_400

  @max_advance 255
  @max_minute_offset 15_300
  @max_hour_offset 918_000
  @max_day_offset 22_032_000

  @type unit :: :minutes | :hours | :days

  @doc """
  Keeps every offset `<= 0` in original order; substitutes `[-default]` when a
  non-empty input consisted solely of positive offsets.

  A non-positive `default` raises `FunctionClauseError`. The default comes
  from the `:default_alarm_seconds` config, and a typo there should crash
  loudly on first use instead of silently storing a bogus alarm offset.
  """
  @spec clean(list(integer()), default: pos_integer()) :: list(integer())
  def clean([], default: default) when is_integer(default) and default > 0, do: []

  def clean(alarms_seconds, default: default)
      when is_integer(default) and default > 0 do
    case for(offset <- alarms_seconds, offset <= 0, do: offset) do
      [] -> [-default]
      kept -> kept
    end
  end

  @doc """
  Picks one offset per `:pick_alarm` and converts it to the Palm alarm triple.

  The advance always fits the one-byte wire format (0..255). Divisible values
  keep their natural unit; odd values round UP to the next representable unit
  (better to alarm too early than too late). Only offsets beyond 255 days cap
  at 255 days — the sole case that fires later than requested.

  ## Options

    * `:pick_alarm` — `:first` (offset farthest from the event start) or
      `:last` (offset closest to the event start). Both picks assume the
      caller delivers the offsets in ascending order, as the Swift port
      does; on an unsorted list they simply take whichever end happens to
      be there.

  ## Returns

  A `{alarm?, advance, unit}` triple:

    * `alarm?` — `false` only when the list was empty (the triple is then
      `{false, 0, :minutes}`); `true` for any non-empty list
    * `advance` — the number of units the alarm fires before the event,
      always within `0..255` to fit the one-byte wire field
    * `unit` — one of `:minutes`, `:hours` or `:days`
  """
  @spec to_palm_alarm(list(integer()), pick_alarm: :first | :last) ::
          {boolean(), non_neg_integer(), unit()}
  def to_palm_alarm([], _opts), do: {false, 0, :minutes}

  def to_palm_alarm(alarms_seconds, pick_alarm: pick) do
    offset = abs(picked_offset(alarms_seconds, pick))
    {advance, unit} = advance_and_unit(offset)
    {true, advance, unit}
  end

  defp picked_offset(alarms_seconds, :first), do: List.first(alarms_seconds)
  defp picked_offset(alarms_seconds, :last), do: List.last(alarms_seconds)

  defp advance_and_unit(0), do: {0, :minutes}

  # Divisible values first: keep the natural unit when it fits one byte.
  defp advance_and_unit(offset)
       when rem(offset, @day_seconds) == 0 and div(offset, @day_seconds) <= @max_advance,
       do: {div(offset, @day_seconds), :days}

  defp advance_and_unit(offset)
       when rem(offset, @hour_seconds) == 0 and div(offset, @hour_seconds) <= @max_advance,
       do: {div(offset, @hour_seconds), :hours}

  # Ceil ladder for values that fit no clean unit: round UP, never later.
  # The rounded instant may land exactly on a larger unit (3599 seconds
  # rounds up to a whole hour); the same instant is then spelled in the
  # largest unit the wire format can express — 1 hour rather than
  # 60 minutes — so a given alarm time always gets one canonical shape.
  defp advance_and_unit(offset) when offset <= @max_minute_offset,
    do: renormalize(ceil_div(offset, @minute_seconds), :minutes)

  defp advance_and_unit(offset) when offset <= @max_hour_offset,
    do: renormalize(ceil_div(offset, @hour_seconds), :hours)

  defp advance_and_unit(offset) when offset <= @max_day_offset,
    do: {ceil_div(offset, @day_seconds), :days}

  # Beyond 255 days: cap (the only fires-later case).
  defp advance_and_unit(_offset), do: {@max_advance, :days}

  defp renormalize(advance, unit) do
    instant = advance * unit_to_seconds(unit)
    {larger_seconds, larger_unit} = next_larger_unit(unit)

    if rem(instant, larger_seconds) == 0 and div(instant, larger_seconds) <= @max_advance do
      {div(instant, larger_seconds), larger_unit}
    else
      {advance, unit}
    end
  end

  # Only the two ceil ladder rungs re-normalize, so only :minutes and
  # :hours ever reach these lookups.
  defp unit_to_seconds(:minutes), do: @minute_seconds
  defp unit_to_seconds(:hours), do: @hour_seconds

  defp next_larger_unit(:minutes), do: {@hour_seconds, :hours}
  defp next_larger_unit(:hours), do: {@day_seconds, :days}

  defp ceil_div(offset, unit_seconds), do: div(offset + unit_seconds - 1, unit_seconds)
end
