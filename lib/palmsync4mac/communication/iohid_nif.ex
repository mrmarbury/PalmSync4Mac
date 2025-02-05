defmodule PalmSync4Mac.Communication.IOHidNif do
  @moduledoc """
  A NIF wrapper around IOKit's HID Manager for enumerating HID devices and sending data.
  """

  @on_load :load_nif

  def load_nif do
    path = Path.join(:code.priv_dir(:palmsync4mac), 'iohid_nif')
    :erlang.load_nif(path, 0)
  end

  @doc """
  Enumerate HID devices.

  Returns a list of tuples: {Manufacturer, Product, VendorID, ProductID}
  """
  def enumerate_devices, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Send binary data to a device matching the given vendor and product IDs.

  Arguments:
    - vendor (integer)
    - product (integer)
    - data (binary)

  Returns {:ok, :sent} or {:error, Reason}
  """
  def send_data(_vendor, _product, _data), do: :erlang.nif_error(:nif_not_loaded)
end
