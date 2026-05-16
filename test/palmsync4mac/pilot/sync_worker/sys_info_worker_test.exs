defmodule PalmSync4Mac.Pilot.SyncWorker.SysInfoWorkerTest do
  use ExUnit.Case, async: false
  use Patch

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Comms.Pidlp.PilotSysInfo
  alias PalmSync4Mac.Pilot.SyncWorker.SysInfoWorker

  @moduletag :capture_log

  setup do
    {:ok, pid} =
      SysInfoWorker.start_link(%SysInfoWorker{
        client_sd: 42,
        sys_info: %PilotSysInfo{}
      })

    on_exit(fn ->
      try do
        case Process.whereis(SysInfoWorker) do
          nil -> :ok
          pid -> GenServer.stop(pid, :normal, 5000)
        end
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  describe "pre_sync/0" do
    test "returns {:ok, %PilotSysInfo{}} when helper succeeds" do
      fake_sys_info = %PilotSysInfo{
        rom_version: 0x05040000,
        prod_id: "Palm TX"
      }

      patch(Pidlp, :read_sysinfo, fn _sd ->
        {:ok, 42, Map.from_struct(fake_sys_info)}
      end)

      assert {:ok, %PilotSysInfo{rom_version: 0x05040000} = result} = SysInfoWorker.pre_sync()
      assert result.prod_id == "Palm TX"
    end

    test "returns {:error, reason} when helper fails" do
      patch(Pidlp, :read_sysinfo, fn _sd ->
        {:error, 42, -1, "device disconnected"}
      end)

      assert {:error, "device disconnected"} = SysInfoWorker.pre_sync()
    end

    test "stores sys_info in GenServer state" do
      fake_sys_info = %PilotSysInfo{rom_version: 0x05020000}

      patch(Pidlp, :read_sysinfo, fn _sd ->
        {:ok, 42, Map.from_struct(fake_sys_info)}
      end)

      SysInfoWorker.pre_sync()

      assert {:ok, %PilotSysInfo{rom_version: 0x05020000}} = SysInfoWorker.pre_sync()
    end

    # Contract: I1 — client_sd=-1 returns connection error
    test "returns {:error, \"Not connected...\"} when client_sd is -1" do
      case Process.whereis(SysInfoWorker) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal, 5000)
      end

      {:ok, _pid} =
        SysInfoWorker.start_link(%SysInfoWorker{client_sd: -1, sys_info: %PilotSysInfo{}})

      assert {:error, "Not connected to a Palm device?"} = SysInfoWorker.pre_sync()
    end
  end
end
