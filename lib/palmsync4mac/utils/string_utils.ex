defmodule PalmSync4Mac.Utils.StringUtils do
  @moduledoc """
  Utility module to test a string for emptiness.
  """

  def blank?(nil), do: true
  def blank?(""), do: true
  def blank?(<<h, t::binary>>) when h in ~c" \t\n\r", do: blank?(t)
  def blank?(_), do: false
end
