defmodule PalmSync4Mac.Utils.Date do
  @moduledoc """
  Utility to convert between Unix and Palm Epoch

  Palm Epoch is 2,082,844,800 seconds before Unix Epoch

  Palm Epoch is 1/1/1904 00:00:00
  Unix Epoch is 1/1/1970 00:00:00
  """
  @palm_to_unix_offset 2_082_844_800

  @spec unix_to_palm(non_neg_integer()) :: non_neg_integer()
  def palm_to_unix(palm_time) when is_integer(palm_time) and palm_time >= 0 do
    palm_time - @palm_to_unix_offset
  end

  @spec unix_to_palm(non_neg_integer()) :: non_neg_integer()
  def unix_to_palm(unix_time) when is_integer(unix_time) and unix_time >= 0 do
    unix_time + @palm_to_unix_offset
  end
end
