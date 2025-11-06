defmodule PalmSync4Mac.Pilot.SyncTest do
  def sync do
    pre_queue = [
      {PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker, :pre_sync, []}
    ]

    post_queue = [
      {PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker, :post_sync, []}
    ]

    psr = %PalmSync4Mac.Pilot.SyncWorker.MainWorker.PilotSyncRequest{
      terminate_after_sync: false,
      pre_sync_queue: pre_queue,
      post_sync_queue: post_queue
    }

    PalmSync4Mac.Pilot.SyncWorker.MainWorker.start_link(psr)
  end
end
