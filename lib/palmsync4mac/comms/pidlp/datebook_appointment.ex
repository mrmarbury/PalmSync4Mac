defmodule PalmSync4Mac.Comms.Pidlp.DatebookAppointment do
  @moduledoc """
  Elixir struct that mirrors the Palm DateBook Appointment_t
  """
  use TypedStruct

  alias PalmSync4Mac.Comms.Pidlp.AlarmAdvanceUnit
  alias PalmSync4Mac.Comms.Pidlp.DayOfMonthType
  alias PalmSync4Mac.Comms.Pidlp.RepeatType
  alias PalmSync4Mac.Comms.Pidlp.TM
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent
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
        "Note text of the appointment. Default is empty string which becomes NULL in C and therefore won't create a note on the Palm device"
    )

    field(:rec_id, non_neg_integer(),
      default: 0,
      doc:
        "The record id of the palm record. If the record is new, this will be zero by default. After writing the appointment to the palm it has a rec_id which should be used when referring to that appointment later"
    )
  end

  @spec from_calendar_event(CalendarEvent.t()) ::
          {CalendarEvent.t(), DatebookAppointment.t()}
  def from_calendar_event(%CalendarEvent{} = event) do
    {event,
     %__MODULE__{
       description: event.title |> to_palm_encoding(),
       begin: event.start_date |> DateTime.to_unix() |> TMTime.unix_to_tm(),
       end: event.end_date |> DateTime.to_unix() |> TMTime.unix_to_tm(),
       note: event |> build_note() |> to_palm_encoding(),
       event: event.start_date == event.end_date,
       rec_id: event.rec_id
     }}
  end

  defp build_note(%CalendarEvent{} = event) do
    [
      event.notes,
      if(event.location, do: "Location: #{event.location}"),
      if(event.url, do: "URL: #{event.url}")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    # truncate to roughly 4k
    |> String.slice(0, 4000)
  end

  defp to_palm_encoding(string) when is_binary(string) do
    case Codepagex.from_string(string, :iso_8859_1) do
      {:ok, encoded} -> encoded
      # fallback to original if unconvertible chars
      {:error, _} -> string
    end
  end

  defp to_palm_encoding(nil), do: ""
end
