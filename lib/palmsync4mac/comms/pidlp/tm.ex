defmodule PalmSync4Mac.Comms.Pidlp.TM do
  @moduledoc """
  Elixir struct that mirrors C's `struct tm` so we can round‑trip
  timestamps through the Palm DateBook packing logic.

  * `tm_mon` is **0‑based** (January = 0).
  * `tm_year` is stored as **years since 1900**.
  * All other fields match their C counterparts one‑for‑one.
  """

  @type t :: %__MODULE__{
          tm_sec: integer(),
          tm_min: integer(),
          tm_hour: integer(),
          tm_mday: integer(),
          tm_mon: integer(),
          tm_year: integer(),
          tm_wday: integer(),
          tm_yday: integer(),
          tm_isdst: integer()
        }
  # 0-60   (allow leap second)
  defstruct tm_sec: 0,
            # 0-59
            tm_min: 0,
            # 0-23
            tm_hour: 0,
            # 1-31
            tm_mday: 1,
            # 0-11
            tm_mon: 0,
            # years since 1900
            tm_year: 0,
            # 0-6  (Sun = 0)
            tm_wday: 0,
            # 0-365
            tm_yday: 0,
            # 1 = DST, 0 = no DST, -1 = unknown
            tm_isdst: 0
end
