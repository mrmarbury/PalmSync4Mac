defmodule PalmSync4Mac.Entity.SyncStatus do
  @moduledoc """
  The PalmSync4Mac SyncStatus domain
  """
  use Ash.Domain

  resources do
    resource(PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus)
  end
end
