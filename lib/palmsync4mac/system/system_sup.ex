defmodule PalmSync4Mac.System.SystemSup do
  use GenServer

  @moduledoc """
  This module is the supervisor for the PalmSync4Mac system.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    children = [
      {PalmSync4Mac.System.SyncFlagHandler, []}
      # {PalmSync4Mac.System.SystemProfiler, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
