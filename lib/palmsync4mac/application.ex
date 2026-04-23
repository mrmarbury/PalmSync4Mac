defmodule PalmSync4Mac.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PalmSync4Mac.EventKit.EventKitSup,
      PalmSync4Mac.Repo,
      PalmSync4Mac.Pilot.PilotSyncSup
    ]

    opts = [strategy: :one_for_one, name: PalmSync4Mac.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
