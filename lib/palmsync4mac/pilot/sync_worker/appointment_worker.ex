defmodule PalmSync4Mac.Pilot.SyncWorker.AppointmentWorker do
  @moduledoc """
  Sync Worker to sync Apple calendar dates/Palm appointments
  """
  use GenServer

  require Logger
  require Ash.Query

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Dlp.OpenDbMode
  alias PalmSync4Mac.Comms.Pidlp.DatebookAppointment
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent

  defstruct client_sd: -1

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  def sync_to_palm(sync_expired \\ false) do
    GenServer.call(__MODULE__, {:sync_to_palm, sync_expired})
  end

  @impl true
  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info.client_sd}")
    {:ok, worker_info}
  end

  @impl true
  def handle_call({:sync_to_palm, sync_expired}, _from, state) do
    PalmSync4Mac.Entity.EventKit.CalendarEvent
    |> Ash.Query.filter(
      is_nil(sync_to_palm_date) ||
        last_modified > sync_to_palm_date
    )
    |> Ash.read!()
    |> write_records(sync_expired, state.client_sd)

    {:reply, :ok, state}
  end

  defp write_records(calendar_events, sync_expired, client_sd) do
    mode = OpenDbMode.build([:read, :write])
    {:ok, _client_sd, db_handle} = Pidlp.open_db(client_sd, 0, mode, "DatebookDB")

    calendar_events
    |> Enum.map(&DatebookAppointment.from_calendar_event/1)
    |> Enum.each(&write_record_and_update_db(&1, client_sd, db_handle))

    Pidlp.close_db(client_sd, db_handle)
  end

  defp write_record_and_update_db(
         {%CalendarEvent{} = calendar_event, %DatebookAppointment{} = datebook_appointment},
         client_sd,
         db_handle
       ) do
    case Pidlp.write_datebook_record(client_sd, db_handle, datebook_appointment) do
      {:ok, _client_sd, result, rec_id} ->
        Logger.info(
          "Wrote #{result} bytes to Palm for #{datebook_appointment.description}, rec_id: #{rec_id}"
        )

        calendar_event
        |> Ash.Changeset.for_update(:set_synced_to_palm, %{rec_id: rec_id})
        |> Ash.update!()

      {:error, client_sd, result, message} ->
        Logger.info(
          "Error writing #{datebook_appointment.description} to Palm. client_sd: #{client_sd}, result: #{result}, message: #{message}"
        )
    end
  end
end
