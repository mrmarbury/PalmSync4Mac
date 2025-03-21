defmodule Palmsync4mac.Dlp.Base do
  @moduledoc """
    Defines some basic functions needed for dlp
  """

  def response_data(res, arg_index, offset) do
    data = res.argv |> Enum.at(arg_index) |> Map.fetch!(:data)
    binary_part(data, offset, byte_size(data) - offset)
  end

  def get_response_byte(res, arg_index, offset) do
    <<_::binary-size(offset), byte, _::binary>> =
      res.argv |> Enum.at(arg_index) |> Map.fetch!(:data)

    byte
  end

  def get_response_bytes(res, arg_index, offset, size) do
    <<_::binary-size(offset), bytes::binary-size(size), _::binary>> =
      res.argv |> Enum.at(arg_index) |> Map.fetch!(:data)

    bytes
  end
end
