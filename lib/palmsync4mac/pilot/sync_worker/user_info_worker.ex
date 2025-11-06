defmodule PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker do
  @moduledoc """
  Handles reading and writing of the PalmUserInfo during a sync
  """

  use GenServer

  require Logger

  alias PalmSync4Mac.Pilot.SyncWorkerRegistry

  import PalmSync4Mac.Pilot.Helper.UserInfo.UserInfoHelper

  defstruct client_sd: -1, user_info: %PalmSync4Mac.Comms.Pidlp.PilotUser{}, username: nil

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  @impl true
  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info.client_sd}")
    {:ok, worker_info}
  end

  def pre_sync(username \\ nil) do
    GenServer.call(__MODULE__, {:pre_sync, username})
  end

  def post_sync do
    GenServer.call(__MODULE__, :post_sync)
  end

  @impl true
  def handle_call({:pre_sync, username}, _from, state) do
    client_sd = state.client_sd
    Logger.info("Pre-sync: Reading user info for client_sd: #{client_sd}")

    with {:ok, user_info} <- read_user_info(client_sd),
         with_username <- update_username(user_info, username),
         with_pc <- update_last_sync_pc(with_username),
         with_last_sync_date <- update_last_sync_date(with_pc),
         {:ok, _client_sd} <- write_user_info(client_sd, with_last_sync_date),
         :ok <- write_to_db!(with_last_sync_date) do
      new_state = %{state | user_info: with_last_sync_date}
      {:reply, :ok, new_state}
    else
      {:error, message} ->
        Logger.error("Error Pre-Syncing User Info")
        {:reply, {:error, message}, state}
    end
  end

  @impl true
  def handle_call(:post_sync, _from, state) do
    client_sd = state.client_sd

    Logger.info(
      "Post-sync: Writing updated user info the the device with client_sd: #{client_sd}"
    )

    with with_successful_sync_date <- update_successful_sync_date(state.user_info),
         {:ok, _client_sd} <- write_user_info(client_sd, with_successful_sync_date),
         :ok <- write_to_db!(with_successful_sync_date) do
      new_state = %{state | user_info: with_successful_sync_date}
      {:reply, :ok, new_state}
    else
      {:error, message} ->
        Logger.error("Error Post-Syncing User Info: #{message}")
        {:reply, {:error, message}, state}
    end
  end
end
