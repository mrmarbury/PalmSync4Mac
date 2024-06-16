defmodule PalmSync4Mac.Entity.Calendar do
  use Ash.Resource, domain: PalmSync4Mac.Entity

  actions do
    defaults([:read, :destroy])

    create(:create) do
      accept([:title, :start_date, :end_date])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:title, :string) do
      allow_nil?(false)
      public?(true)
    end

    attribute(:start_date, :integer) do
      allow_nil?(false)
      public?(true)
    end

    attribute(:end_date, :integer) do
      allow_nil?(false)
      public?(true)
    end
  end
end
