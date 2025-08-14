defmodule PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker do
  @moduledoc """
  Handles reading and writing of the PalmUserInfo during a sync
  """

  use GenServer

  require Logger

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Pilot.SyncWorkerRegistry

  defstruct client_sd: -1, user_info: %PalmSync4Mac.Comms.Pidlp.PilotUser{}

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
          PalmSync4Mac.Entity.Device.PalmUser
          |> Ash.Changeset.new()
          |> Ash.Changeset.for_create(:create_or_update)
          |> Ash.create!()
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

  defp read_user_info(-1), do: {:error, "Not connected to a Palm device?"}

  defp read_user_info(client_sd) do
    case Pidlp.read_user_info(client_sd) do
      {:ok, _client_sd, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info} ->
        Logger.info("Read User Info: #{inspect(user_info)}")
        {:ok, user_info}

      {:error, _client_sd, message} ->
        Logger.error("Failed to read user info: #{message}")
        {:error, message}
    end
  end
end
