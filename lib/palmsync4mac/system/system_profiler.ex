defmodule PalmSync4Mac.System.SystemProfiler do
  @moduledoc """
  Utility to query Mac system_profiler for USB devices
  """
  # FIXME: make Genserver and make System.cmd a Port.

  # Palm Vendor ID
  @vendor_id "0x0830"

  def palm_usb_devices do
    no_device = {:no_device, "No Palm device ready for sync"}

    usb_devices()
    |> case do
      {:ok, %{}} ->
        no_device

      {:ok, items} ->
        Enum.filter(items, fn map -> palm_device?(map) end)
        |> case do
          [] -> no_device
          devices -> {:ok, devices}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp usb_devices do
    case System.cmd("system_profiler", ["SPUSBDataType", "-json"]) do
      {output, 0} ->
        json = Jason.decode!(output)

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

  defp palm_device?(map) do
    Map.get(map, "vendor_id")
    |> String.contains?(@vendor_id)
  end
end
