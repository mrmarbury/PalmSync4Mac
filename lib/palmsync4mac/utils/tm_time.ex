defmodule PalmSync4Mac.Utils.TMTime do
  @moduledoc """
  Helper functions that replicate C's `localtime()` and `mktime()` in
  pure Elixir, using the struct defined in `PalmSync4Mac.Struct.TM`.
  """
  require Logger

  alias PalmSync4Mac.Comms.Pidlp.TM

  ## ----------------------------------------------------------------
  ##  Public API
  ## ----------------------------------------------------------------

  @doc """
  Convert **Unix epoch seconds** to a `%TM{}` that reflects the given
  IANA time‑zone (defaults to the host system zone).

      iex> PalmSync4Mac.Utils.Time.unix_to_tm(1_701_187_600, "Europe/Berlin")
      %TM{tm_hour: 13, tm_min: 0, tm_year: 123, tm_mon: 10, ...}
  """
  @spec unix_to_tm(integer(), String.t()) :: TM.t()
  def unix_to_tm(unix_seconds, tz \\ system_tz()) do
    {:ok, utc_dt} = DateTime.from_unix(unix_seconds, :second)

    local_dt =
      case DateTime.shift_zone(utc_dt, tz) do
        {:ok, dt} ->
          dt

        # If the zone is invalid, fall back to UTC
        {:error, message} ->
          Logger.warning("Falling back to UTC because of #{message}")
          utc_dt
      end

    %TM{
      tm_sec: local_dt.second,
      tm_min: local_dt.minute,
      tm_hour: local_dt.hour,
      tm_mday: local_dt.day,
      tm_mon: local_dt.month - 1,
      tm_year: local_dt.year - 1900,
      tm_wday: sunday_based_wday(local_dt),
      tm_yday: zero_based_yday(local_dt),
      tm_isdst: if(local_dt.std_offset != 0, do: 1, else: 0)
    }
  end

  @doc """
  Convert a `%TM{}` back to Unix epoch seconds.  The optional `tz`
  argument (default: system zone) tells the function which rules to
  use when interpreting the broken‑down values.

  If the local time is *ambiguous* (the hour that repeats when DST
  falls back), the `tm_isdst` flag decides which occurrence to pick.
  """
  @spec tm_to_unix(TM.t(), String.t()) :: integer()
  def tm_to_unix(%TM{} = tm, tz \\ system_tz()) do
    {:ok, naive} =
      NaiveDateTime.new(
        tm.tm_year + 1900,
        tm.tm_mon + 1,
        tm.tm_mday,
        tm.tm_hour,
        tm.tm_min,
        tm.tm_sec
      )

    case DateTime.from_naive(naive, tz) do
      {:ok, dt} ->
        DateTime.to_unix(dt, :second)

      {:ambiguous, dt1, dt2} ->
        chosen = choose_ambiguous(dt1, dt2, tm.tm_isdst)
        DateTime.to_unix(chosen, :second)

      {:gap, _before, _after} ->
        # Spring‑forward gap ⇒ shove one second forward into valid time
        {:ok, patched} = DateTime.from_naive(NaiveDateTime.add(naive, 1), tz)
        DateTime.to_unix(patched, :second)
    end
  end

  ## ----------------------------------------------------------------
  ##  Private helpers
  ## ----------------------------------------------------------------

  # Host‑default zone
  defp system_tz, do: Timex.Timezone.Local.lookup()

  # Convert ISO weekday (Mon=1…Sun=7) to Sunday‑based (Sun=0)
  defp sunday_based_wday(%DateTime{} = dt), do: rem(Date.day_of_week(dt), 7)

  # 0‑based day‑of‑year
  defp zero_based_yday(%DateTime{} = dt) do
    {:ok, jan1} = Date.new(dt.year, 1, 1)
    Date.diff(dt, jan1)
  end

  # Resolve DST ambiguity according to tm_isdst
  defp choose_ambiguous(dt1, dt2, tm_isdst) do
    cond do
      tm_isdst == 1 and dt1.std_offset != 0 -> dt1
      tm_isdst == 1 -> dt2
      tm_isdst == 0 and dt1.std_offset == 0 -> dt1
      tm_isdst == 0 -> dt2
      true -> dt1
    end
  end
end
