defmodule PalmSync4Mac.Utils.SystemProfiler do
  @moduledoc """
  Utility to query Mac system_profiler for USB devices
  """
  alias PalmSync4Mac.Utils.SystemCmd

  # Palm Vendor ID
  @vendor_id "0x0830"

  def palm_usb_devices do
    no_device = {:no_device, "No Palm device ready for sync"}

    usb_devices()
    |> case do
      {:ok, %{}} ->
        no_device

      {:ok, items} ->
        Enum.filter(items, fn map -> is_palm_device?(map) end)
        |> case do
          [] -> no_device
          devices -> {:ok, devices}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp usb_devices do
    case SystemCmd.cmd("system_profiler", ["SPUSBDataType", "-json"]) do
      {output, 0} ->
        json = Jason.decode!(output)
        IO.inspect(json)

        items =
          json["SPUSBDataType"]
          |> Enum.find(fn map -> Map.has_key?(map, "_items") end)
          |> case do
            nil -> %{}
            map -> Map.get(map, "_items")
          end

        {:ok, items}

      {output, _} ->
        {:error, output}
    end
  end

  defp is_palm_device?(map) do
    Map.get(map, "vendor_id")
    |> String.contains?(@vendor_id)
  end
end
