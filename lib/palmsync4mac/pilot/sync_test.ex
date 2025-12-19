defmodule PalmSync4Mac.Pilot.SyncTest do
  @moduledoc """
  Used for manual testing in the early stages of development
  """

  alias PalmSync4Mac.Pilot.SyncWorker.MainWorker
  alias PalmSync4Mac.Pilot.SyncWorker.MiscWorker
  alias PalmSync4Mac.Pilot.SyncWorker.MiscWorker
  alias PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker
  alias PalmSync4Mac.Pilot.SyncWorker.AppointmentWorker

  @sync_expired true

  # FIXME:#12 Remove this when the UI is ready and we have an integration test that can take this over
  def sync do
    pre_queue = [
      {MiscWorker, :time_sync, []},
      {UserInfoWorker, :pre_sync, ["PalmTX"]}
    ]

    post_queue = [
      {UserInfoWorker, :post_sync, []}
    ]

    main_queue = [
      {AppointmentWorker, :sync_to_palm, [@sync_expired]}
    ]

    psr = %PalmSync4Mac.Pilot.SyncWorker.MainWorker.PilotSyncRequest{
      pre_sync_queue: pre_queue,
      post_sync_queue: post_queue,
      sync_queue: main_queue
    }

    MainWorker.start_link(psr)
  end
end
