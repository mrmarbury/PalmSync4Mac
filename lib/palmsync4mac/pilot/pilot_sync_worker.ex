defmodule Palmsync4mac.Pilot.PilotSyncWorker do
  @moduledoc """
  When a sync is initiated it connects to the respective Palm and spawns dynamic sync processes until the sync queue is processed
  """
  use TypedStruct
  use GenServer

  require Logger

  alias PalmSync4Mac.Comms.Pidlp

  typedstruct module: PilotSyncRequest do
    plugin(TypedStructLens)
    plugin(TypedStructNimbleOptions)

    field(:device, PalmSync4Mac.Entity.Device.Palm.t(), doc: "The Palm device to sync with")
    field(:sync_queue, list(module()), doc: "List of modules")

    field(:pre_sync_queue, list(module()),
      default: [],
      doc: """
      List of modules that should always be included in the sync before the main sync happens.
      These are usually tasks to prepare the main sync. Like fetching user info 
      """
    )

    field(:post_sync_queue, list(module()),
      default: [],
      doc: """
      List of modules that should always be included in the sync after the main sync happens.
      These items are usually used for cleanup on the Palm and tasks that need to be run after the main sync.
      """
    )

    field(:sync_options, map(), doc: "Map of options to pass to each Worker in the :sync_queue")

    field(:client_sd, integer(),
      default: -1,
      doc: "The client socket descriptor. Default is -1 to indicate no client sd"
    )

    field(:parent_sd, integer(),
      default: -1,
      doc: "The parent socket descriptor. Default is -1 to indicate no parent sd"
    )

    field(:connect_wait_timeout, integer(),
      default: 300,
      doc:
        "Timeout in seconds to wait for the connection to the Palm device. Default: 300s. Set to 0 to wait indefinitely"
    )

    field(:port, String.t(),
      default: "usb:",
      doc: "The port to connect to the Palm device. Default: \"usb:\""
    )
  end

  def start_link(opts \\ %PilotSyncRequest{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Logger.info("Starting #{__MODULE__}")
    {:ok, opts, {:continue, :connect}}
  end

  def terminate(reason, state) do
    Logger.info("Terminating #{__MODULE__} with reason #{reason}")
    Pidlp.pilot_disconnect(state.client_sd, state.parent_sd)
    terminate_children()
    :ok
  end

  def handle_continue(:connect, state) do
    case(Pidlp.pilot_connect(state.port, state.connect_wait_timeout)) do
      {:ok, client_sd, parent_sd} ->
        Logger.info("Connected to Palm device with client_sd: #{client_sd} on port #{state.port}")
        new_state = %{state | client_sd: client_sd, parent_sd: parent_sd}
        self() |> send(:sync)
        {:noreply, new_state}

      {:error, _client_sd, _parent_sd, message} ->
        Logger.error("Failed to connect: #{message}. Exiting sync.")
        {:stop, :normal, state}
    end
  end

  def handle_info(:sync, state) do
    Logger.info("Starting Sync 👷‍♀️")

    new_state =
      state
      |> do_sync(state.pre_sync_queue ++ state.sync_queue ++ state.post_sync_queue)

    {:noreply, state}
  end

  defp do_sync(state, []) do
    state
  end

  defp do_sync(state, [item | rest]) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        PalmSync4Mac.PilotLink.DynamicPilotSyncSup,
        {item, state}
      )

    {:ok, new_state} = GenServer.call(pid, :sync)
    do_sync(rest, new_state)
  end

  defp terminate_children do
    worker_list = DynamicSupervisor.which_children(PalmSync4Mac.PilotLink.DynamicPilotSyncSup)

    for {_id, pid, _type, _name} <- worker_list do
      # It either kills the process or there is none to kill.
      _any = DynamicSupervisor.terminate_child(PalmSync4Mac.PilotLink.DynamicPilotSyncSup, pid)
    end

    # Thats fine
    :ok
  end
end
