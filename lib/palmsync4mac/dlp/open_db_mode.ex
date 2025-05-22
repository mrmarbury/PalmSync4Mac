defmodule PalmSync4Mac.Dlp.OpenDbMode do
  @moduledoc """
  Represents Palm OS DlpOpenDBMode flags as a bitmask.
  """

  import Bitwise

  @flags %{
    # open for reading
    read: 0x80,
    # open for writing
    write: 0x40,
    # open with exclusive access
    exclusive: 0x20,
    # show secret records
    secret: 0x10
  }

  @type flag :: :read | :write | :exclusive | :secret
  @type t :: non_neg_integer()

  @doc "Build a bitmask from a list of flag atoms"
  @spec build([flag]) :: t
  def build(flags) do
    Enum.reduce(flags, 0, fn flag, acc ->
      acc ||| Map.fetch!(@flags, flag)
    end)
  end

  @doc "Decode a bitmask into a list of flag atoms"
  @spec decode(t) :: [flag]
  def decode(mask) do
    Enum.filter(@flags, fn {_k, v} -> (mask &&& v) != 0 end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc "Get the integer value of a single flag"
  @spec value(flag) :: t
  def value(flag), do: Map.fetch!(@flags, flag)
end
