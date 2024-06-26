defmodule PalmSync4Mac.Device.Palm do
  @moduledoc """
  Represents a Palm device that can be synced with a Mac
  """
  use Ash.Resource,
    domain: PalmSync4Mac.Device,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("palm")
    repo(PalmSync4Mac.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create(:create) do
      accept([:name, :id])
    end

    update :update_name do
      accept([:name])
    end

    update :set_synced do
      accept([:last_synced, :last_sync_status])
    end
  end

  attributes do
    attribute :id, :integer do
      description("Unique Palm device ID encoded as serial_number in system_profiler USB data")
      allow_nil?(false)
      primary_key?(true)
      public?(true)
    end

    attribute :name, :string do
      description("Aka HotSync Name of the Palm device")
      allow_nil?(false)
      public?(true)
    end

    attribute :last_synced, :date do
      description("Last time this Palm device was synced. Nil/empty if never synced")
      allow_nil?(true)
      public?(true)
    end

    attribute :last_sync_status, :string do
      description("Last sync status: ok, error. Nil/empty if never synced")
      allow_nil?(true)
      public?(true)
    end
  end
end
