defmodule PalmSync4Mac.Utils.String do
  @moduledoc false

  def blank?(nil), do: true
  def blank?(""), do: true
  def blank?(<<h, t::binary>>) when h in ~c" \t\n\r", do: blank?(t)
  def blank?(_), do: false
end
