defmodule Palmsync4mac.Entity.Calendar do
  use Ash.Resource, domain: Palmsync4mac.Entity

  actions do
    defaults([:read, :destroy])
    create(:create)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string)
    attribute(:start_date, :integer)
    attribute(:end_date, :integer)
  end
end
