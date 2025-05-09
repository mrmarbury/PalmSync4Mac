defmodule PalmSync4Mac.PilotLink.DatebookHandler do
  @moduledoc false

  alias PalmSync4Mac.Comms.Pidlp

  defmodule DatebookAppointment do
    defstruct [
      :event,
      :begin,
      :end,
      :alarm,
      :alarmAdvance,
      :alarmAdvanceUnits,
      :repeat_type,
      :repeat_forevery,
      :repeat_end,
      :repeat_day_of_Month,
      :repeat_days,
      :repeat_weekstart,
      :exceptions_count,
      :exceptions_actual,
      :description,
      :note
    ]
  end

  defmodule TimeHTime do
    defstruct [
      :sec,
      :min,
      :hour,
      :mday,
      :mon,
      :year,
      :wday,
      :yday,
      :isdst
    ]
  end

  def do_sync do
    begin_opts = [
      sec: 0,
      min: 0,
      hour: 12,
      mday: 10,
      mon: 5,
      year: 2025,
      wday: 0,
      yday: 0,
      isdst: 0
    ]

    end_opts = [
      sec: 0,
      min: 0,
      hour: 13,
      mday: 10,
      mon: 5,
      year: 2025,
      wday: 0,
      yday: 0,
      isdst: 0
    ]

    date = [
      event: true,
      begin: struct(TimeHTime, begin_opts),
      end: struct(TimeHTime, end_opts),
      alarm: false,
      alarmAdvanceUnits: 0,
      alarmAdvance: 0,
      repeat_type: :none,
      repeat_forevery: false,
      repeat_end: struct(TimeHTime, end_opts),
      repeat_day_of_Month: :dom_1st_sun,
      repeat_days: [0, 0, 0, 0, 0, 0, 0],
      repeat_weekstart: 0,
      exceptions_actual: [],
      description: "Test Date",
      note: ""
    ]

    dateboot_entry = struct(DatebookAppointment, date)
    sync_datebook_appointment(dateboot_entry)
  end

  @spec sync_datebook_appointment(Pidlp.DatebookAppointment.t()) :: :ok
  def sync_datebook_appointment(datebook_appointment) do
    {:ok, client_sd, parent_sd} = Pidlp.pilot_connect("usb:")
    {:ok, _client_sd, _result} = Pidlp.open_conduit(client_sd)
    # {:ok, _client_sd, user_info} = PiDlp.read_user_info(client_sd)
    {:ok, _client_sd, db_handle} = Pidlp.open_db(client_sd, 0, 0x80, "DatebookDB")
    {:ok, _client_sd} = Pidlp.write_record(client_sd, db_handle, datebook_appointment)
    {:ok, _client_sd} = Pidlp.close_db(client_sd, db_handle)

    # TODO implement this
    # /* Tell the user who it is, with a different PC id. */
    # User.lastSyncPC 	= 0x00010000;
    # User.successfulSyncDate = time(NULL);
    # User.lastSyncDate 	= User.successfulSyncDate;
    # dlp_WriteUserInfo(sd, &User);
    # {:ok, _client_sd} = Pidlp.write_user_info(client_sd, user_info)

    {:ok, _client_sd} = Pidlp.end_of_sync(client_sd, 0)
    {:ok, _client_sd} = Pidlp.pilot_disconnect(client_sd, parent_sd)
    :ok
  end
end
