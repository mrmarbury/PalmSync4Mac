defmodule PalmSync4Mac.Pilot.SyncWorkers do
  @moduledoc """
  Convenience wrapper for managing sync worker processes under DynamicSyncWorkerSup.

  Provides a cleaner API for starting, listing, and terminating sync workers
  without repeatedly passing the DynamicSyncWorkerSup name.
  """

  alias PalmSync4Mac.Pilot.DynamicSyncWorkerSup

  def start_child(child_spec) do
    DynamicSupervisor.start_child(DynamicSyncWorkerSup, child_spec)
  end

  def which_children do
    DynamicSupervisor.which_children(DynamicSyncWorkerSup)
  end

  def terminate_child(pid) do
    DynamicSupervisor.terminate_child(DynamicSyncWorkerSup, pid)
  end
end
