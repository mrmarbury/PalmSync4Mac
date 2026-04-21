defmodule PalmSync4Mac.Pilot.DynamicSup do
  @moduledoc false

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
