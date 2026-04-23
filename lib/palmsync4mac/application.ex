defmodule PalmSync4Mac.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        if(Application.get_env(:palm_sync_4_mac, :start_event_kit_sup, true),
          do: PalmSync4Mac.EventKit.EventKitSup
        ),
        PalmSync4Mac.Repo,
        if(Application.get_env(:palm_sync_4_mac, :start_pilot_sync_sup, true),
          do: PalmSync4Mac.Pilot.PilotSyncSup
        )
      ]
      |> Enum.filter(& &1)

    opts = [strategy: :one_for_one, name: PalmSync4Mac.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
