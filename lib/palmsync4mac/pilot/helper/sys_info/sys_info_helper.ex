defmodule PalmSync4Mac.Pilot.Helper.SysInfo.SysInfoHelper do
  @moduledoc """
  Contains utility methods for reading Palm device system info via the Pidlp NIF.
  Used by SysInfoWorker during pre-sync.
  """
  require Logger
  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Comms.Pidlp.PilotSysInfo

  def read_sys_info(-1), do: {:error, "Not connected to a Palm device?"}

  def read_sys_info(client_sd) do
    case Pidlp.read_sysinfo(client_sd) do
      {:ok, _client_sd, %PilotSysInfo{} = sys_info} ->
        Logger.info(
          "Read SysInfo: rom_version=0x#{Integer.to_string(sys_info.rom_version, 16)}, prod_id=#{sys_info.prod_id}"
        )

        {:ok, sys_info}

      {:ok, _client_sd, value} ->
        Logger.error("Unexpected sysinfo format from NIF: #{inspect(value)}")
        {:error, "Unexpected sysinfo format from NIF"}

      {:error, _client_sd, _result, message} ->
        Logger.error("Failed to read sysinfo: #{message}")
        {:error, message}
    end
  end
end
