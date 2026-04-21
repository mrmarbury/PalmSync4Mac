defmodule PalmSync4Mac.Pilot.SyncWorker.MiscWorker do
  @moduledoc """
  Sync Worker for all the sync functions that do not really fit anywhere.

  It's currently a bit overkill to have a GenServer for such simple calls
  that do not really need state. And Erik would hate this for sure. 
  But it fits the current sync model well.
  """
  use GenServer

  require Logger

  alias PalmSync4Mac.Comms.Pidlp

  defstruct client_sd: -1

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  def time_sync do
    GenServer.call(__MODULE__, :time_sync)
  end

  @impl true
  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info.client_sd}")
    {:ok, worker_info}
  end

  @impl true
  def handle_call(:time_sync, _from, state) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    case Pidlp.set_sys_date_time(state.client_sd, timestamp) do
      {:ok, _client_sd} -> {:reply, :ok, state}
      {:error, message} -> {:reply, {:error, message}, state}
    end
  end
end
