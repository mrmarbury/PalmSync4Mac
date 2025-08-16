defmodule PalmSync4Mac.Utils.StringUtils do
  @moduledoc """
  Utility module to test a string for emptiness.
  """

  @doc """
  Use in a guard to make sure a string is not empty
  """
  defmacro is_not_blank(string) do
    quote do
      !blank?(string)
    end
  end

  @doc """
  Use in a guard to make sure a string is empty
  """
  defmacro is_blank(string) do
    quote do
      !blank?(string)
    end
  end

  def blank?(nil), do: true
  def blank?(""), do: true
  def blank?(<<h, t::binary>>) when h in ~c" \t\n\r", do: blank?(t)
  def blank?(_), do: false

  def generate_random_string(length \\ 5) do
    for _ in 1..length(), into: "", do: <<Enum.random("abcdefghijklmnopqrstuvwxyz1234567890")>>
  end
end
