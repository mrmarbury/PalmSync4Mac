defmodule PalmSync4Mac.EventKit.CalendarEventWorker do
  @moduledoc """
  This module is responsible for retrieving and storing calendar events retrieved through the PortHandler.
  """
  use GenServer

  require Logger

  alias PalmSync4Mac.Utils.AlarmPicker

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
    default = Application.fetch_env!(:palm_sync_4_mac, :default_alarm_seconds)

    case PalmSync4Mac.EventKit.PortHandler.get_events(interval, calendar) do
      {:ok, data} ->
        Enum.each(data["events"], fn cal_date ->
          {raw_alarms, cleaned} = clean_event_alarms(cal_date, default)
          log_alarm_cleaning(cal_date["apple_event_id"], raw_alarms)

          try do
            PalmSync4Mac.Entity.EventKit.CalendarEvent
            |> Ash.Changeset.new()
            |> Ash.Changeset.set_argument(:new_last_modified, cal_date["last_modified"])
            |> Ash.Changeset.set_argument(:new_alarms_seconds, cleaned)
            |> Ash.Changeset.for_create(
              :create_or_update,
              Map.put(cal_date, "alarms_seconds", cleaned)
            )
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

  # Trust boundary for the port payload: the Swift port normally delivers
  # alarm offsets as a list of integers, but protocol drift or a stale port
  # binary could produce anything else. A malformed value must degrade to
  # "no alarms" with a debug note — never crash the worker, which would
  # abort the sync of every remaining calendar. A nil key already means
  # "no alarms" and stays silent. Returns the raw (made-safe) list for the
  # debug logging alongside the cleaned list, so a non-list payload is
  # treated exactly like "no alarms" everywhere downstream.
  defp clean_event_alarms(cal_date, default) do
    case cal_date["alarms_seconds"] do
      nil ->
        {[], []}

      raw when is_list(raw) ->
        {raw, AlarmPicker.clean(raw, default: default)}

      raw ->
        Logger.debug(
          "alarms_seconds for event #{inspect(cal_date["apple_event_id"])} is not a list " <>
            "(got #{inspect(raw)}); storing no alarms"
        )

        {[], []}
    end
  end

  # Cleaning events (discarded positives, default substitution) are routine
  # data bookkeeping, not sync progress: they log at :debug level only so
  # they never pollute the default :info sync output.
  defp log_alarm_cleaning(apple_event_id, raw_alarms) do
    positive_count = Enum.count(raw_alarms, &(&1 > 0))

    if positive_count > 0 do
      Logger.debug(
        "Discarded #{positive_count} positive alarm offset(s) for event #{inspect(apple_event_id)}"
      )
    end

    if raw_alarms != [] and Enum.all?(raw_alarms, &(&1 > 0)) do
      Logger.debug(
        "All alarm offsets positive for event #{inspect(apple_event_id)}, substituted default alarm"
      )
    end
  end
end
