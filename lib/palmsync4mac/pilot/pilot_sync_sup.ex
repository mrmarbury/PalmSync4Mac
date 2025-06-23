defmodule PalmSync4Mac.Pilot.PilotSyncSup do
  @moduledoc """
  Supervisor for the EventKit library.
  """
  use Supervisor

  def start_link(_opts \\ []) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {Registry, keys: :unique, name: PalmSync4Mac.Pilot.SyncWorkerRegistry},
      {DynamicSupervisor, name: PalmSync4Mac.Pilot.DynamicSyncWorkerSup, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
