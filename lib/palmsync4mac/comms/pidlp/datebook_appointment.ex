defmodule PalmSync4Mac.Comms.Pidlp.DatebookAppointment do
  @moduledoc """
  Elixir struct that mirrors the Palm DateBook Appointment_t
  """
  use TypedStruct

  alias PalmSync4Mac.Comms.Pidlp.AlarmAdvanceUnit
  alias PalmSync4Mac.Comms.Pidlp.DayOfMonthType
  alias PalmSync4Mac.Comms.Pidlp.RepeatType
  alias PalmSync4Mac.Comms.Pidlp.TM
  alias PalmSync4Mac.Utils.TMTime

  typedstruct do
    plugin(TypedStructLens)
    plugin(TypedStructNimbleOptions)

    field(:event, boolean(), default: false, doc: "True if this is a timeless event")

    field(:begin, TM.t(),
      default: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
      doc: "Start time of the appointment as a TM struct. Default is current time"
    )

    field(:end, TM.t(),
      default: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
      doc: "End time of the appointment as a TM struct. Default is current time"
    )

    field(:alarm, boolean(), default: false, doc: "True if this appointment has an alarm")

    field(:alarm_advance, non_neg_integer(),
      default: 0,
      doc: "Alarm advance time by X units. Default is 0"
    )

    field(:alarm_advance_units, AlarmAdvanceUnit.t(),
      default: AlarmAdvanceUnit.Minutes.value(),
      doc: "Alarm advance units as AlarmAdvanceUnit enum. Default is Minutes"
    )

    field(:repeat_type, RepeatType.t(),
      default: RepeatType.None.value(),
      doc: "Repeat type as RepeatType enum. Default is None"
    )

    field(:repeat_forever, boolean(),
      default: false,
      doc: "True if this appointment repeats forever. Default is false"
    )

    field(:repeat_end, TM.t(),
      default: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
      doc: "End time of the repeat as a TM struct. Default is current time"
    )

    field(:repeat_frequency, non_neg_integer(),
      default: 0,
      doc: "Repeat frequency, i.e. how many times to repeat. Default is 0"
    )

    field(:repeat_day, DayOfMonthType.t(),
      default: DayOfMonthType.FirstSun.value(),
      doc: "Day of the month type as DayOfMonthType enum. Default is FirstSun"
    )

    field(:repeat_days, list(non_neg_integer()),
      default: [0, 0, 0, 0, 0, 0, 0],
      doc: "Days of the week to repeat. List of 7 integers for Sun-Sat"
    )

    field(:repeat_weekstart, non_neg_integer(),
      default: 0,
      doc: "Start of the week as an integer, where 0 is Sunday. Default is 0"
    )

    field(:exceptions_count, non_neg_integer(),
      default: 0,
      doc: "Number of exceptions. Default is 0"
    )

    field(:exceptions_actual, list(TM.t()),
      default: [],
      doc: "List of exceptions as TM structs. Default is empty list"
    )

    field(:description, String.t(),
      default: "",
      enforce: true,
      doc: "Description text of the appointment. Must be set"
    )

    field(:note, String.t(),
      default: "",
      doc:
        "Note text of the appointment. Default is empty string which becomes NULL in C and therefore wont create a note on the Palm device"
    )
  end
end
