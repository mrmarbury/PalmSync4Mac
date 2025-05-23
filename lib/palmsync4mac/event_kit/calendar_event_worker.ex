defmodule PalmSync4Mac.EventKit.CalendarEventWorker do
  @moduledoc """
  This module is responsible for retrieving and storing calendar events retrieved through the PortHandler.
  """
  use GenServer

  require Logger

  defstruct calendars: [], interval: 13

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec sync_calendar_events(list(atom()), non_neg_integer()) :: none()
  def sync_calendar_events(calendars \\ [], interval \\ 13) do
    GenServer.cast(__MODULE__, {:sync, calendars, interval})
  end

  @impl true
  def init(_opts) do
    Logger.info("#{__MODULE__} started")
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:sync, calendars, interval}, state) when is_list(calendars) do
    case calendars do
      [] ->
        Logger.info("Fetching all Events)")
        sync_calendar(nil, interval)

      _ ->
        Logger.info("Fetching Events for #{inspect(calendars)}")

        Enum.each(calendars, fn calendar ->
          sync_calendar(calendar, interval)
        end)
    end

    {:noreply, %__MODULE__{state | calendars: calendars, interval: interval}}
  end

  defp sync_calendar(calendar, interval) do
    case PalmSync4Mac.EventKit.PortHandler.get_events(interval, calendar) do
      {:ok, data} ->
        Enum.each(data["events"], fn cal_date ->
          PalmSync4Mac.Entity.EventKit.CalendarEvent
          |> Ash.Changeset.for_create(:create_or_update, cal_date)
          |> Ash.create!()
        end)

      {:error, reason} ->
        Logger.error("Error syncing calendar events: #{inspect(reason)}")
    end
  end
end
