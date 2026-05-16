defmodule PalmSync4Mac.Pilot.Helper.SysInfo.SysInfoHelperTest do
  use ExUnit.Case, async: false
  use Patch

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Comms.Pidlp.PilotSysInfo
  alias PalmSync4Mac.Pilot.Helper.SysInfo.SysInfoHelper

  @moduletag :capture_log

  describe "read_sys_info/1" do
    test "returns {:ok, %PilotSysInfo{}} on NIF success" do
      fake_sys_info = %PilotSysInfo{
        rom_version: 0x05040000,
        locale: 1,
        prod_id_length: 6,
        prod_id: "Palm TX",
        dlp_major_version: 1,
        dlp_minor_version: 3,
        compat_major_version: 1,
        compat_minor_version: 3,
        max_rec_size: 65_536
      }

      patch(Pidlp, :read_sysinfo, fn _sd ->
        {:ok, 42, Map.from_struct(fake_sys_info)}
      end)

      assert {:ok, %PilotSysInfo{} = result} = SysInfoHelper.read_sys_info(42)
      assert result.rom_version == 0x05040000
      assert result.prod_id == "Palm TX"
      assert result.max_rec_size == 65_536
    end

    test "returns {:error, message} on NIF failure" do
      patch(Pidlp, :read_sysinfo, fn _sd ->
        {:error, 42, -1, "NIF error"}
      end)

      assert {:error, "NIF error"} = SysInfoHelper.read_sys_info(42)
    end

    test "returns {:error, \"Not connected...\"} when client_sd == -1" do
      assert {:error, "Not connected to a Palm device?"} = SysInfoHelper.read_sys_info(-1)
    end

    # Contract: I1 — defensive against non-map NIF return
    test "returns {:error, \"Unexpected sysinfo format...\"} when NIF returns non-map" do
      patch(Pidlp, :read_sysinfo, fn _sd -> {:ok, 42, "not a map"} end)

      assert {:error, "Unexpected sysinfo format from NIF"} = SysInfoHelper.read_sys_info(42)
    end

    test "field mapping matches NIF response struct" do
      nif_response = %{
        rom_version: 0x05020000,
        locale: 0,
        prod_id_length: 0,
        prod_id: "",
        dlp_major_version: 1,
        dlp_minor_version: 2,
        compat_major_version: 1,
        compat_minor_version: 2,
        max_rec_size: 0
      }

      patch(Pidlp, :read_sysinfo, fn _sd -> {:ok, 42, nif_response} end)

      assert {:ok, result} = SysInfoHelper.read_sys_info(42)
      assert result.rom_version == 0x05020000
      assert result.dlp_major_version == 1
      assert result.dlp_minor_version == 2
    end
  end
end
