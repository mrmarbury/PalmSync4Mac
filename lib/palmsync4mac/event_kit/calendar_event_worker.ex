defmodule PalmSync4Mac.EventKit.CalendarEventWorker do
  @moduledoc """
  This module is responsible for retrieving and storing calendar events retrieved through the PortHandler.
  """
  use GenServer

  require Logger

  # defaults
  @calendars []
  @interval 13

  def start_link(calendars \\ @calendars, interval \\ @interval)
      when is_list(calendars) and is_integer(interval) do
    GenServer.start_link(__MODULE__, [calendars: calendars, interval: interval], name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info(
      "#{__MODULE__} started - Starting Autosync for Calendars #{Enum.join(opts[:calendars], ",")} with interval #{opts[:interval]}"
    )

    Process.send(self(), :auto_sync, [])
    {:ok, opts}
  end

  @impl true
  def handle_info(:auto_sync, state) do
    Logger.info("Autosyncing Calendars")

    synced_cals = state[:calendars]
    sync_interval = state[:interval]

    case synced_cals do
      [] ->
        Logger.info("Fetching all Events)")
        sync_calendar(nil, sync_interval)

      _ ->
        Logger.info("Fetching Events for: #{Enum.join(synced_cals, ", ")}")

        Enum.each(synced_cals, fn cal ->
          sync_calendar(cal, sync_interval)
        end)
    end

    schedule_sync()
    {:noreply, state}
  end

  defp schedule_sync do
    Process.send_after(self(), :auto_sync, :timer.minutes(1))
  end

  ### Business Logic

  defp sync_calendar(calendar, interval) do
    case PalmSync4Mac.EventKit.PortHandler.get_events(interval, calendar) do
      {:ok, data} ->
        Enum.each(data["events"], fn cal_date ->
          try do
            PalmSync4Mac.Entity.EventKit.CalendarEvent
            |> Ash.Changeset.new()
            |> Ash.Changeset.set_argument(:new_last_modified, cal_date["last_modified"])
            |> Ash.Changeset.for_create(:create_or_update, cal_date)
            |> Ash.create!()
          rescue
            # upserts throw when the resource is stale. Which in this case means that nothing has
            # changed and we dont need to update. So for now we rescue and log
            reason ->
              Logger.warning("Failed to create or update calendar event: #{inspect(reason)}")
          end
        end)

      {:error, reason} ->
        Logger.error("Error syncing calendar events: #{inspect(reason)}")
    end
  end
end
