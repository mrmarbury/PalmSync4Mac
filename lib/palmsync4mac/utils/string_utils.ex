defmodule PalmSync4Mac.Utils.StringUtils do
  @moduledoc """
  Utility module to test a string for emptiness.
  """

  @list [
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "0"
  ]

  def blank?(nil), do: true
  def blank?(""), do: true
  def blank?(<<h, t::binary>>) when h in ~c" \t\n\r", do: blank?(t)
  def blank?(_), do: false

  def generate_random_string(length \\ 5) do
    for _ <- 1..length, into: "", do: Enum.random(@list)
  end
end
