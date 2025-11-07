defmodule PalmSync4Mac.Pilot.SyncTest do
  @moduledoc """
  Used for manual testing in the early stages of development
  """
  # FIXME:#12 Remove this when the UI is ready and we have an integration test that can take this over
  def sync do
    pre_queue = [
      {PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker, :pre_sync, ["PalmTX"]}
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
