defmodule PalmSync4Mac.EventKit.EventKitSup do
  @moduledoc """
  Supervisor for the EventKit library.
  """
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_args) do
    calendar_names = Application.fetch_env!(:palm_sync_4_mac, :apple_calendar_names)

    children = [
      {PalmSync4Mac.EventKit.PortHandler, []},
      {PalmSync4Mac.EventKit.CalendarEventWorker, calendar_names}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
