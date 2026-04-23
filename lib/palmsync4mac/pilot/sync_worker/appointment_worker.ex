defmodule PalmSync4Mac.Pilot.SyncWorker.AppointmentWorker do
  @moduledoc """
  Sync Worker to sync Apple calendar dates/Palm appointments.
  Uses EkCalendarDatebookSyncStatus join table for per-device sync tracking.
  """

  use GenServer

  require Logger
  require Ash.Query

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Comms.Pidlp.DatebookAppointment
  alias PalmSync4Mac.Dlp.OpenDbMode
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent
  alias PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus

  defstruct client_sd: -1

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  @doc """
  Main sync entry point. palm_user_id is injected as the last argument by MainWorker
  after UserInfoWorker extracts it during pre_sync.
  """
  def sync_to_palm(palm_user_id) do
    GenServer.call(__MODULE__, {:sync_to_palm, palm_user_id})
  end

  @impl true
  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info.client_sd}")
    {:ok, worker_info}
  end

  @impl true
  def handle_call({:sync_to_palm, palm_user_id}, _from, state) do
    Logger.info("Syncing to Palm for palm_user_id: #{palm_user_id}")

    case list_unsynced_for_device(palm_user_id) do
      {:ok, calendar_events} when calendar_events == [] ->
        Logger.info("No unsynced events for palm_user_id: #{palm_user_id}")
        {:reply, :ok, state}

      {:ok, calendar_events} ->
        write_records(calendar_events, state.client_sd, palm_user_id)
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to query unsynced events: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Lists CalendarEvents that need syncing for a specific Palm device.

  Returns events that match any of these conditions:
  1. No join row exists yet (new event, will use rec_id=0 to create new Palm record)
  2. rec_id == 0 (previous write failed, retry with rec_id=0)
  3. CalendarEvent.version > last_synced_version (event was updated, use existing rec_id)
  """
  def list_unsynced_for_device(palm_user_id) do
    with {:ok, all_events} <- Ash.read(CalendarEvent),
         {:ok, sync_statuses} <- read_sync_statuses(palm_user_id) do
      synced_map =
        sync_statuses
        |> Enum.map(fn status -> {status.calendar_event_id, status} end)
        |> Map.new()

      unsynced =
        Enum.filter(all_events, fn event ->
          case Map.get(synced_map, event.id) do
            nil -> true
            %{rec_id: 0} -> true
            %{last_synced_version: v} when v < event.version -> true
            _ -> false
          end
        end)
        |> Enum.map(fn event ->
          rec_id =
            case Map.get(synced_map, event.id) do
              %{rec_id: id} -> id
              _ -> 0
            end

          {event, rec_id}
        end)

      {:ok, unsynced}
    end
  end

  defp read_sync_statuses(palm_user_id) do
    EkCalendarDatebookSyncStatus
    |> Ash.Query.filter(palm_user_id == ^palm_user_id)
    |> Ash.read()
  end

  defp write_records(calendar_events, client_sd, palm_user_id) do
    mode = OpenDbMode.build([:read, :write])

    case Pidlp.open_db(client_sd, 0, mode, "DatebookDB") do
      {:ok, _client_sd, db_handle} ->
        calendar_events
        |> Enum.map(fn {event, rec_id} ->
          DatebookAppointment.from_calendar_event(event, rec_id)
        end)
        |> Enum.each(&write_record_and_update_join(&1, client_sd, db_handle, palm_user_id))

        Pidlp.close_db(client_sd, db_handle)

      # If we can't open the database, mark all pending events as failed
      # so we don't lose track of what needs syncing
      {:error, _client_sd, _result, message} ->
        Logger.error("Failed to open DatebookDB: #{message}")

        Enum.each(calendar_events, fn {%CalendarEvent{} = event, _rec_id} ->
          upsert_join_row(palm_user_id, event.id, 0, event.version, false)
        end)
    end
  end

  # Each write attempt creates or updates a join row to track sync status
  defp write_record_and_update_join(
         {%CalendarEvent{} = calendar_event, %DatebookAppointment{} = datebook_appointment},
         client_sd,
         db_handle,
         palm_user_id
       ) do
    case Pidlp.write_datebook_record(client_sd, db_handle, datebook_appointment) do
      {:ok, _client_sd, _result, rec_id} ->
        Logger.info("Wrote #{datebook_appointment.description} to Palm, rec_id: #{rec_id}")

        upsert_join_row(palm_user_id, calendar_event.id, rec_id, calendar_event.version, true)

      {:error, _client_sd, _result, message} ->
        Logger.error("Error writing #{datebook_appointment.description} to Palm: #{message}")

        upsert_join_row(palm_user_id, calendar_event.id, 0, calendar_event.version, false)
    end
  end

  defp upsert_join_row(palm_user_id, calendar_event_id, rec_id, last_synced_version, success) do
    EkCalendarDatebookSyncStatus
    |> Ash.Changeset.for_create(:create_or_update, %{
      palm_user_id: palm_user_id,
      calendar_event_id: calendar_event_id,
      rec_id: rec_id,
      last_synced_version: last_synced_version,
      last_sync_success: success
    })
    |> Ash.create()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.error("Failed to upsert join row: #{inspect(reason)}")
    end
  end
end
