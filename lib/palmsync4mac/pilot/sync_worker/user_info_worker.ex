defmodule PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker do
  @moduledoc """
  Handles reading and writing of the PalmUserInfo during a sync
  """

  use GenServer

  require Logger

  alias PalmSync4Mac.Comms.Pidlp.PilotUser

  defstruct client_sd: -1, id: __MODULE__

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info[:client_sd]}")
    {:ok, worker_info}
  end
end
