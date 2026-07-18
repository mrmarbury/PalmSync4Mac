defmodule PalmSync4Mac.Pilot.SyncWorker.SysInfoWorker do
  @moduledoc """
  Pre-sync worker that fetches Palm device system info (rom_version, prod_id, etc.)
  via the Pidlp.read_sysinfo NIF. Returns PilotSysInfo struct as sync context for
  subsequent workers that need device capabilities (e.g., version-branching in
  AppointmentWorker for DateBookDB vs CalendarDB-PDat).
  """

  use GenServer, restart: :transient

  require Logger

  import PalmSync4Mac.Pilot.Helper.SysInfo.SysInfoHelper

  alias PalmSync4Mac.Comms.Pidlp.PilotSysInfo

  defstruct client_sd: -1, sys_info: %PilotSysInfo{}

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  def pre_sync do
    GenServer.call(__MODULE__, :pre_sync)
  end

  @impl true
  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info.client_sd}")
    {:ok, worker_info}
  end

  @impl true
  def handle_call(:pre_sync, _from, state) do
    client_sd = state.client_sd
    Logger.info("Pre-sync: Reading system info for client_sd: #{client_sd}")

    case read_sys_info(client_sd) do
      {:ok, sys_info} ->
        Logger.info(
          "Pre-sync: Got sys_info, rom_version=0x#{Integer.to_string(sys_info.rom_version, 16)}"
        )

        new_state = %{state | sys_info: sys_info}
        {:reply, {:ok, sys_info}, new_state}

      {:error, message} ->
        Logger.error("Pre-sync: Error reading system info: #{message}")
        {:reply, {:error, message}, state}
    end
  end
end
