defmodule PalmSync4Mac.PilotLink.PilotLinkSup do
  @moduledoc """
  Supervisor for the EventKit library.
  """
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {DynamicSupervisor,
       name: PalmSync4Mac.PilotLink.DynamicPilotSyncSup, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
