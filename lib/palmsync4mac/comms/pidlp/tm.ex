defmodule PalmSync4Mac.Comms.Pidlp.TM do
  @moduledoc """
  Elixir struct that mirrors C's `struct tm` so we can round‑trip
  timestamps through the Palm DateBook packing logic.

  * `tm_mon` is **0‑based** (January = 0).
  * `tm_year` is stored as **years since 1900**.
  * All other fields match their C counterparts one‑for‑one.
  """
  use TypedStruct

  typedstruct do
    plugin(TypedStructLens)

    # 0-60   (allow leap second)
    field(:tm_sec, non_neg_integer(), default: 0)
    # 0-59
    field(:tm_min, non_neg_integer(), default: 0)
    # 0-23
    field(:tm_hour, non_neg_integer(), default: 0)
    # 1-31
    field(:tm_mday, non_neg_integer(), default: 1)
    # 0-11
    field(:tm_mon, non_neg_integer(), default: 1)
    # years since 1900
    field(:tm_year, non_neg_integer(), default: 0)
    # 0-6 (sun = 0)
    field(:tm_wday, non_neg_integer(), default: 0)
    # 0-365
    field(:tm_yday, non_neg_integer(), default: 0)
    # 1 = DST, 0 = no DST, -1 = unknown
    field(:tm_isdst, non_neg_integer(), default: 0)
  end
end
