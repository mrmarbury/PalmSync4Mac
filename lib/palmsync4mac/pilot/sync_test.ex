defmodule PalmSync4Mac.Pilot.SyncTest do
  def sync do
    pre_queue = [{PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker, :pre_sync, []}]

    psr = %PalmSync4Mac.Pilot.SyncWorker.MainWorker.PilotSyncRequest{
      terminate_after_sync: false,
      pre_sync_queue: pre_queue
    }

    PalmSync4Mac.Pilot.SyncWorker.MainWorker.start_link(psr)
  end
end
