defmodule PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker do
  @moduledoc """
  Handles reading and writing of the PalmUserInfo during a sync
  """

  use GenServer

  require Logger

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Pilot.SyncWorkerRegistry

  import Palmsync4mac.Pilot.Helper.UserInfo.UserInfoHelper

  defstruct client_sd: -1, user_info: %PalmSync4Mac.Comms.Pidlp.PilotUser{}, username: nil

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  @impl true
  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info.client_sd}")
    {:ok, worker_info}
  end

  def pre_sync do
    GenServer.call(__MODULE__, :pre_sync)
  end

  def post_sync do
    GenServer.call(__MODULE__, :post_sync)
  end

  @impl true
  def handle_call(:pre_sync, _from, state) do
    Logger.info("Pre-sync: Reading user info for client_sd: #{state.client_sd}")

    case read_user_info(state.client_sd) do
      {:ok, user_info} ->
        try do
          update_username(state.username)
          write_to_db!(user_info)
        rescue
          # upserts throw when the resource is stale. Which in this case means that nothing has
          # changed and we dont need to update. So for now we rescue and log
          reason ->
            Logger.warning("Failed to create or update Pilot User entry: #{inspect(reason)}")
        end

        new_state = %{state | user_info: user_info}
        {:reply, :ok, new_state}

      {:error, message} ->
        {:reply, {:error, message}, state}
    end
  end
end
