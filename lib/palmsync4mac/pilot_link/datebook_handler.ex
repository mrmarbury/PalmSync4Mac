defmodule PalmSync4Mac.PilotLink.DatebookHandler do
  @moduledoc """
  Convert Ek Calendar Data into Palm Datebook Data.
  """
  use GenServer

  @pilot_link_bin_path Application.compile_env!(:palmsync4mac, :pilot_link_bin_path)
  @pilot_link_tools Application.compile_env!(:palmsync4mac, :pilot_link_tools)
end
