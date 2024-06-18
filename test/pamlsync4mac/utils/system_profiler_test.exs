defmodule PalmSync4Mac.Utils.SystemProfilerTest do
  use ExUnit.Case, async: true
  import Mox

  alias PalmSync4Mac.Utils.SystemProfiler

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

  setup :verify_on_exit!

  test "finds Palm device" do
    PalmSync4Mac.MockSystemCmd
    |> expect(:cmd, fn "system_profiler", ["SPUSBDataType", "-json"] -> @full_json_with_palm end)

    assert SystemProfiler.palm_usb_devices() ==
             {:ok, [%{"vendor_id" => "0x0830 (Palm, Inc)", "serial_num" => "123"}]}
  end
end
