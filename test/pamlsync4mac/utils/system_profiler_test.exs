defmodule PalmSync4Mac.System.SystemProfilerTest do
  use ExUnit.Case, async: true
  use Patch

  alias PalmSync4Mac.System.SystemProfiler

  @full_json_with_palm """
    {
      "SPUSBDataType" : [
        {
          "_name" : "USB31Bus",
          "host_controller" : "AppleT8112USBXHCI"
        },
        {
          "_items" : [
            {
              "_name" : "Palm Handheld ",
              "bcd_device" : "1.00",
              "bus_power" : "500",
              "bus_power_used" : "2",
              "device_speed" : "full_speed",
              "extra_current_used" : "0",
              "location_id" : "0x00100000 / 1",
              "manufacturer" : "Palm, Inc.",
              "product_id" : "0x0060",
              "serial_num" : "3030563541424E333139554D",
              "vendor_id" : "0x0830  (Palm Inc.)"
            }
          ],
          "_name" : "USB31Bus",
          "host_controller" : "AppleT8112USBXHCI"
        },
        {
          "_name" : "USB31Bus",
          "host_controller" : "AppleT8112USBXHCI"
        }
      ]
    }
  """

  @full_json_with_items_no_palm """
    {
      "SPUSBDataType" : [
        {
          "_name" : "USB31Bus",
          "host_controller" : "AppleT8112USBXHCI"
        },
        {
          "_items" : [
            {
              "_name" : "Some Device",
              "serial_num" : "123456",
              "vendor_id" : "0x4223  (Whatever, Inc.)"
            }
          ],
          "_name" : "USB31Bus",
          "host_controller" : "AppleT8112USBXHCI"
        }
      ]
    }
  """

  @full_json_without_items """
    {
      "SPUSBDataType" : [
        {
          "_name" : "USB31Bus",
          "host_controller" : "AppleT8112USBXHCI"
        },
        {
          "_name" : "USB31Bus",
          "host_controller" : "AppleT8112USBXHCI"
        }
      ]
    }
  """

  # Test cases
  test "should find Palm device" do
    expected_output = {
      :ok,
      [
        %{
          "serial_num" => "3030563541424E333139554D",
          "vendor_id" => "0x0830  (Palm Inc.)",
          "_name" => "Palm Handheld ",
          "bcd_device" => "1.00",
          "bus_power" => "500",
          "bus_power_used" => "2",
          "device_speed" => "full_speed",
          "extra_current_used" => "0",
          "location_id" => "0x00100000 / 1",
          "manufacturer" => "Palm, Inc.",
          "product_id" => "0x0060"
        }
      ]
    }

    run_profiler_with_return({@full_json_with_palm, 0})

    assert SystemProfiler.palm_usb_devices() == expected_output
  end

  test "should return :no_device when no Palm device found result without items" do
    run_profiler_with_return({@full_json_without_items, 0})
    assert SystemProfiler.palm_usb_devices() == {:no_device, "No Palm device ready for sync"}
  end

  test "should return :no_device when no Palm device found in result with items" do
    run_profiler_with_return({@full_json_with_items_no_palm, 0})
    assert SystemProfiler.palm_usb_devices() == {:no_device, "No Palm device ready for sync"}
  end

  test "should return error when system_profiler command fails" do
    run_profiler_with_return({"AAAAAAARRRRRRGGGGGGHHHHHH", 1})
    assert SystemProfiler.palm_usb_devices() == {:error, "AAAAAAARRRRRRGGGGGGHHHHHH"}
  end

  defp run_profiler_with_return(return_tuple) do
    Patch.patch(
      System,
      :cmd,
      fn "system_profiler", ["SPUSBDataType", "-json"] -> return_tuple end
    )
  end
end
