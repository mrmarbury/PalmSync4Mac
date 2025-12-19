defmodule PalmSync4Mac.Pilot.SyncWorker.MainWorker do
  @moduledoc """
  When a sync is initiated it connects to the respective Palm and spawns dynamic sync processes until the sync queue is processed
  """
  use TypedStruct
  use GenServer

  require Logger

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Pilot.DynamicSyncWorkerSup

  typedstruct module: PilotSyncRequest do
    plugin(TypedStructLens)
    plugin(TypedStructNimbleOptions)

    field(:sync_queue, list(mfa()),
      default: [],
      doc:
        "List of MFA to run in the main sync process. The client_sd is always added as a keyword to the args. There is no need to manually add it"
    )

    field(:pre_sync_queue, list(mfa()),
      default: [],
      doc: """
      List of MFA that should always be included in the sync before the main sync happens.
      These are usually tasks to prepare the main sync. Like fetching user info
      the client_sd is always added as a keyword to the args. There is no need to manually add it
      """
    )

    field(:post_sync_queue, list(mfa()),
      default: [],
      doc: """
      List of MFA that should always be included in the sync after the main sync happens.
      These items are usually used for cleanup on the Palm and tasks that need to be run after the main sync.
      the client_sd is always added as a keyword to the args. There is no need to manually add it
      """
    )

    field(:client_sd, integer(),
      default: -1,
      doc:
        "The client socket descriptor. Default is -1 to indicate no client sd. Will be set automatically after connecting"
    )

    field(:parent_sd, integer(),
      default: -1,
      doc:
        "The parent socket descriptor. Default is -1 to indicate no parent sd. Will be set automatically after connecting"
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

  @impl true
  def init(opts) do
    Logger.info("Starting #{__MODULE__}")
    {:ok, opts, {:continue, :connect}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Stopping #{__MODULE__} at the end of the sync")
    Pidlp.pilot_disconnect(state.client_sd, state.parent_sd)
    terminate_children()
    :ok
  end

  @impl true
  def handle_continue(:connect, state) do
    Logger.info("Waiting for Palm for #{state.connect_wait_timeout}s (0 means forever)")

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

  @impl true
  def handle_info(:sync, state) do
    Logger.info("Starting Sync 👷‍♀️")

    queue =
      state.pre_sync_queue
      |> Enum.concat(state.sync_queue)
      |> Enum.concat(state.post_sync_queue)

    Logger.info("Sync queue: #{inspect(queue)}")

    case do_sync(state, queue) do
      :ok -> Logger.info("Sync finished.")
      :empty_queue -> Logger.warning("Sync queue is empty, nothing to run")
    end

    {:stop, :normal, state}
  end

  defp do_sync(_state, []), do: :empty_queue

  defp do_sync(state, mfas) do
    start_queue(mfas, state.client_sd)
    run_queue(mfas)
    :ok
  end

  defp start_queue([], _client_sd), do: :empty_queue

  defp start_queue(mfas, client_sd) do
    mfas
    |> Enum.map(fn {mod, _, _} -> mod end)
    |> Enum.uniq()
    |> Enum.reduce([], fn mod, acc ->
      worker_struct = struct(mod, client_sd: client_sd)

      case DynamicSupervisor.start_child(DynamicSyncWorkerSup, {mod, worker_struct}) do
        {:ok, _pid} ->
          Logger.info("Started sync worker #{mod}")

        {:error, reason} ->
          Logger.error("Failed to start #{mod}: #{inspect(reason)}")
      end
    end)
  end

  defp run_queue([]) do
    Logger.info("No more tasks to run")
    :ok
  end

  defp run_queue([{mod, fun, args} | rest]) do
    case apply(mod, fun, args) do
      :ok ->
        Logger.info("-> #{mod}.#{fun}(#{inspect(args)}) completed successfully")
        run_queue(rest)

      {:error, reason} ->
        Logger.error("-> #{mod}.#{fun}(#{inspect(args)}) failed with reason: #{reason}")
        run_queue(rest)
    end
  end

  defp terminate_children do
    worker_list =
      DynamicSupervisor.which_children(DynamicSyncWorkerSup)

    Enum.each(worker_list, fn {_id, pid, _type, name} ->
      Logger.info("Terminating worker #{Enum.at(name, 0)}, with pid #{inspect(pid)}")
      # It either kills the process or there is none to kill.
      _any =
        DynamicSupervisor.terminate_child(DynamicSyncWorkerSup, pid)
    end)

    # That's fine
    :ok
  end
end
