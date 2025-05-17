defmodule PalmSync4Mac.PilotLink.DatebookHandler do
  @moduledoc false

  require Logger

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Utils.TMTime

  alias PalmSync4Mac.Comms.Pidlp.DatebookAppointment
  alias PalmSync4Mac.Comms.Pidlp.TM

  def do_sync do
    date = [
      event: false,
      description: "Test Date",
      note: "",
      repeat_type: :repeatNone,
      repeat_day: :dom_1st_sun,
      repeat_days: [0, 0, 0, 0, 0, 0, 0],
      exceptions_actual: [],
      exceptions_count: 0,
      # will be ignored if event: true
      begin: %TM{},
      end: %TM{},
      repeat_end: %TM{}
      # event: false,
      # begin: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
      # end: TMTime.unix_to_tm(DateTime.utc_now() |> DateTime.to_unix()),
      # description: "Test Date"
    ]

    dateboot_entry = struct(DatebookAppointment, date)
    sync_datebook_appointment(dateboot_entry)
  end

  @spec sync_datebook_appointment(Pidlp.DatebookAppointment.t()) :: :ok
  def sync_datebook_appointment(datebook_appointment) do
    {:ok, client_sd, parent_sd} = Pidlp.pilot_connect("usb:")
    Logger.info("#{client_sd} connected to #{parent_sd}")
    {:ok, _client_sd, _result} = Pidlp.open_conduit(client_sd)
    # {:ok, _client_sd, user_info} = PiDlp.read_user_info(client_sd)
    {:ok, _client_sd, db_handle} = Pidlp.open_db(client_sd, 0, 0x80, "DatebookDB")
    {:ok, _client_sd, sysinfo} = Pidlp.read_sysinfo(client_sd)
    Logger.info("SysInfo: #{inspect(sysinfo)}")
    {:ok, _client_sd} = Pidlp.write_datebook_record(client_sd, db_handle, datebook_appointment)
    Logger.info("Wrote datebook record")
    :timer.sleep(1000)
    {:ok, _client_sd} = Pidlp.close_db(client_sd, db_handle)
    Logger.info("Closed DB")
    {:ok, _client_sd, palm_date_time} = Pidlp.get_sys_date_time(client_sd)
    Logger.info("Palm Date Time: #{inspect(palm_date_time)}")

    # TODO implement this
    # /* Tell the user who it is, with a different PC id. */
    # User.lastSyncPC 	= 0x00010000;
    # User.successfulSyncDate = time(NULL);
    # User.lastSyncDate 	= User.successfulSyncDate;
    # dlp_WriteUserInfo(sd, &User);
    # {:ok, _client_sd} = Pidlp.write_user_info(client_sd, user_info)

    {:ok, _client_sd} = Pidlp.end_of_sync(client_sd, 0)
    Logger.info("End of sync")
    {:ok, _client_sd} = Pidlp.pilot_disconnect(client_sd, parent_sd)
    Logger.info("Disconnected")
    :ok
  end
end
