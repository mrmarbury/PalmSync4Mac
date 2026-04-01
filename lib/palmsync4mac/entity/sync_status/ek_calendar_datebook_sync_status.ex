defmodule PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus do
  @moduledoc """
  Keeping track of which EK calendar events have been synced to which Palm device.
  """

  use Ash.Resource,
    domain: PalmSync4Mac.Entity.SyncStatus,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("ek_calendar_datebook_sync_status")
    repo(PalmSync4Mac.Repo)
  end

  identities do
    identity(
      :unique_device_event,
      [:palm_user_id, :calendar_event_id],
      eager_check?: true
    )
  end

  actions do
    defaults([:read, :destroy])

    create(:create_or_update) do
      upsert?(true)
      upsert_identity(:unique_device_event)

      accept([
        :palm_user_id,
        :calendar_event_id,
        :datebook_rec_id,
        :last_synced_version,
        :last_sync_success
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:palm_device_uuid, :uuid) do
      description("The UUID of the synced Palm device entity")
      allow_nil?(false)
      public?(true)
    end

    attribute(:calendar_event_uuid, :uuid) do
      description("The UUID of the synced EK calendar event entity")
      allow_nil?(false)
      public?(true)
    end

    attribute(:datebook_rec_id, :integer) do
      description("Datebook Palm record  ID. 0 = not yet written to device")
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute(:last_synced, :utc_datetime) do
      description(
        "The last time the event synced to the Palm Device. Will be UTC now every time the entry is updated/created"
      )

      writable?(false)
      default(&DateTime.utc_now/0)
      update_default(&DateTime.utc_now/0)
      match_other_defaults?(true)
      allow_nil?(false)
    end

    attribute(:last_synced_version, :integer) do
      description("The version of the ek calendar event that was last synced to the Palm device")
      allow_nil?(true)
      public?(true)
    end

    attribute(:last_sync_success, :boolean) do
      description("Whether the last sync was successful")
      allow_nil?(false)
      default(false)
      public?(true)
    end
  end
end
