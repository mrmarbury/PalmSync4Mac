defmodule PalmSync4Mac.Entity.Calendar do
  @moduledoc """
  The Apple Calendar entity
  """
  use Ash.Resource,
    domain: PalmSync4Mac.Entity,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("calendar")
    repo(PalmSync4Mac.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create(:create) do
      accept([:source, :title, :start_date, :end_date, :description, :location, :deleted])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:source, :string) do
      description("The source of the event. Can be one of :apple, <palm device id>")
      allow_nil?(false)
      public?(true)
    end

    attribute(:title, :string) do
      description("The title of the event")
      allow_nil?(false)
      public?(true)
    end

    attribute(:start_date, :utc_datetime) do
      description("The start date of the event in UTC")
      allow_nil?(false)
      public?(true)
    end

    attribute(:end_date, :utc_datetime) do
      description("The end date of the event in UTC")
      allow_nil?(false)
      public?(true)
    end

    attribute(:description, :string) do
      description("The description of the event, e.g. what it is about")
      allow_nil?(true)
      public?(true)
    end

    attribute(:location, :string) do
      description("The location of the event, e.g. address, zoom link, etc")
      allow_nil?(true)
      public?(true)
    end

    attribute(:last_modified, :utc_datetime) do
      description("The last time the event was modified")
      allow_nil?(true)
      public?(true)
    end

    attribute(:deleted, :boolean) do
      description(
        "Whether the event has been deleted. It's a soft delete, i.e. the record still exists in the database but is not shown and will be synced as a deleted event"
      )

      default(false)
      public?(true)
    end
  end
end
