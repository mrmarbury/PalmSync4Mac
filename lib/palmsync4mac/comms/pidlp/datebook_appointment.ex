defmodule PalmSync4Mac.Comms.Pidlp.DatebookAppointment do
  @moduledoc """
  Elixir struct that mirrors the Palm DateBook Appointment_t
  """

  alias PalmSync4Mac.Comms.Pidlp.TM
  alias PalmSync4Mac.Utils.TMTime

  @type t :: %__MODULE__{
          event: boolean(),
          begin: TM.t(),
          end: TM.t(),
          alarm: boolean(),
          alarm_advance: integer(),
          alarm_advance_units: integer(),
          repeat_type: atom(),
          repeat_forever: boolean(),
          repeat_end: TM.t(),
          repeat_day: integer(),
          repeat_days: list(integer()),
          repeat_weekstart: integer(),
          exceptions_count: integer(),
          exceptions_actual: list(integer()),
          description: String.t(),
          note: String.t()
        }

  # description is required by Palm
  @enforce_keys [:description]
  defstruct begin: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
            end: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
            # set true when begin/end == nil
            event: false,
            alarm: false,
            alarm_advance: 0,
            # 0=:minutes 1=:hours 2=:days
            alarm_advance_units: 0,
            # :none | :daily | :weekly | …
            repeat_type: :repeatNone,
            repeat_forever: false,
            repeat_end: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
            repeat_frequency: 0,
            repeat_day: :dom_1st_sun,
            repeat_days: [0, 0, 0, 0, 0, 0, 0],
            # Sunday
            repeat_weekstart: 0,
            # 0-7 - derived from exception
            exceptions_count: 0,
            # list of %TM{}
            exceptions_actual: [],
            description: "",
            note: ""
end
