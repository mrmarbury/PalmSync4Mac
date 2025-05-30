defmodule PalmSync4Mac.PilotLink.DatebookHandler do
  @moduledoc false

  require Logger
  import Bitwise

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Utils.TMTime

  alias PalmSync4Mac.Comms.Pidlp.DatebookAppointment
  alias PalmSync4Mac.Comms.Pidlp.TM

  alias PalmSync4Mac.Dlp.OpenDbMode

  def do_sync do
    date = [
      event: false,
      description: "Untimed Test Date No Note",
      note: "Some Note"
    ]

    dateboot_entry = struct(DatebookAppointment, date)
    sync_datebook_appointment(dateboot_entry)
  end

  @spec sync_datebook_appointment(Pidlp.DatebookAppointment.t()) :: :ok
  def sync_datebook_appointment(datebook_appointment) do
    dlpOpenMode = OpenDbMode.build([:read, :write])

    {:ok, client_sd, parent_sd} = Pidlp.pilot_connect("usb:", 300)
    Logger.info("#{client_sd} connected to #{parent_sd}")
    {:ok, _client_sd, _result} = Pidlp.open_conduit(client_sd)
    # {:ok, _client_sd, user_info} = PiDlp.read_user_info(client_sd)
    {:ok, _client_sd, db_handle} =
      Pidlp.open_db(client_sd, 0, dlpOpenMode, "DatebookDB")

    {:ok, _client_sd, sysinfo} = Pidlp.read_sysinfo(client_sd)
    Logger.info("SysInfo: #{inspect(sysinfo)}")
    IO.inspect(datebook_appointment, label: "Final struct sent to NIF")
    write_resp = Pidlp.write_datebook_record(client_sd, db_handle, datebook_appointment)
    Logger.info("Wrote datebook record: #{inspect(write_resp)}")
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

    {:ok, _client_sd, _result} = Pidlp.end_of_sync(client_sd, 0)
    Logger.info("End of sync")
    {:ok, _client_sd, _parent_sd} = Pidlp.pilot_disconnect(client_sd, parent_sd)
    Logger.info("Disconnected")
    :ok
  end
end
