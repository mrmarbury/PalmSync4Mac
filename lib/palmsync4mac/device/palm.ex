defmodule PalmSync4Mac.Device.Palm do
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
      accept([:name, :device_id])
    end

    update :update_name do
      accept([:name])
    end

    update :set_synced do
      accept([:last_synced])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:name, :string) do
      allow_nil?(false)
      public?(true)
    end

    attribute(:device_id, :integer) do
      allow_nil?(false)
      public?(true)
    end

    attribute(:last_synced, :date) do
      allow_nil?(true)
      public?(true)
    end
  end
end
