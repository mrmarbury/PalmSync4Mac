defmodule PalmSync4Mac.Entity.Device.PalmUser do
  @moduledoc """
  Represents a Palm user info in the database

  user_id is used as a unique event because it is the closest to a unique identifier.
  """
  use Ash.Resource,
    domain: PalmSync4Mac.Entity.Device,
    data_layer: AshSqlite.DataLayer

  require Logger

  alias Ash.Error.Changes.InvalidChanges
  alias Ash.Error.Changes.StaleRecord

  sqlite do
    table("palm_user")
    repo(PalmSync4Mac.Repo)
  end

  identities do
    identity(
      :unique_event,
      [
        :username
      ],
      eager_check?: true
    )
  end

  actions do
    defaults([:read, :destroy])

    create(:create_or_update) do
      upsert?(true)
      upsert_identity(:unique_event)

      accept([
        :password_length,
        :username,
        :password,
        :user_id,
        :viewer_id,
        :last_sync_pc,
        :successful_sync_date,
        :last_sync_date
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:password_length, :integer) do
      description(
        "Length of the password used to secure the Palm. This must match the actual length of the :password field"
      )

      allow_nil?(false)
      public?(true)
    end

    attribute(:username, :string) do
      description("The username for the device")
      allow_nil?(false)
      public?(true)
    end

    attribute(:password, :string) do
      description(
        "The password used to secure the Palm device. Not encrypted for now to remove overhead and it really does not matter that much at the moment"
      )

      allow_nil?(true)
      public?(true)
    end

    attribute(:user_id, :integer) do
      description(
        "Id of the Palm user/device. This is unique for each palm since it will be set on first hot sync. If this is changed, then the Palm is seen as a new device"
      )

      allow_nil?(false)
      public?(true)
    end

    attribute(:viewer_id, :integer) do
      description("Identifies the Client used for the last sync")

      allow_nil?(false)
      public?(true)
    end

    attribute(:last_sync_pc, :integer) do
      description(
        "Id or name of the PC used in the last sync. Should be set to the current hostname when writing. Will contain the last used hostname when reading."
      )

      allow_nil?(false)
      public?(true)
    end

    attribute(:successful_sync_date, :integer) do
      description("UTC datetime representing the last successfull sync date")
      allow_nil?(true)
      public?(true)
    end

    attribute(:last_sync_date, :integer) do
      description(
        "General date describing when the last sync was no matter if successfull or not"
      )

      allow_nil?(false)
      public?(true)
    end
  end
end
