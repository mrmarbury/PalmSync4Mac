defmodule PalmSync4Mac.Comms.USB do
  @moduledoc """
  For now does the initial comms handshake with the Palm device over USB.
  """
  import Bitwise
  require Logger

  @cmp_type_wakeup 1
  @cmp_type_init 2
  @cmp_type_abort 3
  @cmp_flag_baud_change 1
  # Some Palm devices send DLP instead of CMP
  @dlp_response 0x90

  @cmp_initial_baud_rate 9600
  @cmp_max_baud_rate 38_400
  # Prevent "short" reads due to USB limitations
  @usb_read_buffer_size 1024

  # Version 1.2 (same as PI_CMP_VERSION)
  @cmp_version 0x0102
  # Ensure WAKEUP and INIT messages are exactly 10 bytes
  @cmp_header_length 10

  def handshake do
    usb_device()
  end

  defp usb_device do
    case :usb.get_device_list() do
      {:ok, [device | _]} ->
        usb_connect(device)

      {:ok, []} ->
        IO.puts("❌ No USB devices found.")
        {:error, :no_devices}

      {:error, reason} ->
        IO.puts("❌ USB Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp usb_connect(device) do
    IO.puts("🔍 Connecting to USB device...")

    case :usb.open_device(device) do
      {:ok, handle} ->
        IO.puts("✅ USB device opened.")
        :usb.set_configuration(handle, 1)
        :usb.claim_interface(handle, 0)

        {:ok, config_descriptor} = :usb.get_config_descriptor(device, 0)
        first_alt_setting = List.first(config_descriptor.interfaces).alt_settings |> List.first()

        bulk_in =
          first_alt_setting.endpoints
          |> Enum.find(fn %{address: ep, attributes: attr} ->
            Bitwise.band(ep, 0x80) > 0 and Bitwise.band(attr, 0x03) == 2
          end)
          |> Map.get(:address)

        bulk_out =
          first_alt_setting.endpoints
          |> Enum.find(fn %{address: ep, attributes: attr} ->
            Bitwise.band(ep, 0x80) == 0 and Bitwise.band(attr, 0x03) == 2
          end)
          |> Map.get(:address)

        IO.puts("📌 Bulk IN endpoint: #{inspect(bulk_in)}")
        IO.puts("📌 Bulk OUT endpoint: #{inspect(bulk_out)}")

        rx_wakeup(handle, bulk_in, bulk_out)
        {:ok, handle, device}

      {:error, reason} ->
        IO.puts("❌ Failed to open USB device: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp rx_wakeup(handle, bulk_in, bulk_out) do
    IO.puts("📥 Waiting for Palm WAKEUP...")

    case read_until_complete(handle, bulk_in, @cmp_header_length, "") do
      {:ok,
       <<@cmp_type_wakeup::8, flags::8, major_version::8, minor_version::8, _reserved::big-16,
         baud_rate::big-32>>} ->
        # Fix baud rate if it's obviously invalid (above 115200)
        baud_rate =
          if baud_rate > 115_200 do
            IO.puts(
              "⚠️ WARNING: Unreasonable baud rate `#{baud_rate}`, resetting to #{@cmp_initial_baud_rate}"
            )

            @cmp_initial_baud_rate
          else
            baud_rate
          end

        IO.puts("✅ WAKEUP received! Version=#{major_version}.#{minor_version}, Baud=#{baud_rate}")
        send_init(handle, bulk_out, baud_rate)

      {:ok, <<@dlp_response, _rest::binary>>} ->
        IO.puts("⚠️ Device sent a DLP packet instead of CMP. Ignoring and retrying...")
        rx_wakeup(handle, bulk_in, bulk_out)

      {:error, reason} ->
        IO.puts("❌ CMP RX Error: #{inspect(reason)}")
    end
  end

  defp send_init(handle, bulk_out, baud_rate) do
    change_baud_flag = if baud_rate != @cmp_initial_baud_rate, do: @cmp_flag_baud_change, else: 0

    init_packet = <<
      # Type: INIT (1 byte)
      @cmp_type_init::8,
      # Flags: Set if baud change is required
      change_baud_flag::8,
      # Version (2 bytes)
      @cmp_version::big-16,
      # Reserved (2 bytes, always 0)
      0::big-16,
      # Baudrate (4 bytes)
      baud_rate::big-32
    >>

    IO.puts("📤 Sending CMP INIT: #{Base.encode16(init_packet)} (#{byte_size(init_packet)} bytes)")

    case :usb.write_bulk(handle, bulk_out, init_packet, 5000) do
      {:ok, 10} -> IO.puts("✅ INIT sent successfully!")
      {:ok, bytes_written} -> IO.puts("❌ ERROR: INIT only wrote #{bytes_written}/10 bytes!")
      {:error, reason} -> IO.puts("❌ USB Write Error: #{inspect(reason)}")
    end
  end

  defp read_until_complete(handle, bulk_in, expected_size, buffer)
       when byte_size(buffer) >= expected_size do
    {:ok, binary_part(buffer, 0, expected_size)}
  end

  defp read_until_complete(handle, bulk_in, expected_size, buffer) do
    case :usb.read_bulk(handle, bulk_in, @usb_read_buffer_size, 5000) do
      {:ok, new_data} ->
        IO.puts("🔄 Read additional data: #{Base.encode16(new_data)}")
        read_until_complete(handle, bulk_in, expected_size, buffer <> new_data)

      {:error, reason} ->
        IO.puts("❌ USB Read Error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
