defmodule PalmSync4Mac.Comms.Handshake do
  # Equivalent to PI_CMP_TYPE_WAKE
  @cmp_type_wakeup 1
  # Equivalent to PI_CMP_VERSION
  @cmp_version 1

  def cmp_wakeup(handle, bulk_out, max_baud) do
    wakeup_packet = <<
      # Type: WAKEUP
      @cmp_type_wakeup,
      # Flags (always 0)
      0,
      # Version
      @cmp_version,
      # Reserved (padding to match struct)
      0,
      # Baudrate (sent as a 32-bit integer)
      max_baud::32
    >>

    IO.puts("📤 Sending WAKEUP: #{Base.encode16(wakeup_packet)}")

    case :usb.write_bulk(handle, bulk_out, wakeup_packet, 5000) do
      :ok -> IO.puts("✅ WAKEUP sent successfully")
      {:error, reason} -> IO.puts("❌ USB Write Error: #{inspect(reason)}")
    end
  end

  def bulk_out(device) do
    {:ok, config_descriptor} = :usb.get_config_descriptor(device, 0)
    first_alt_setting = List.first(config_descriptor.interfaces).alt_settings |> List.first()

    first_alt_setting.endpoints
    |> Enum.find(fn %{address: ep, attributes: attr} ->
      Bitwise.band(ep, 0x80) == 0 and Bitwise.band(attr, 0x03) == 2
    end)
    |> Map.get(:address)
  end
end

