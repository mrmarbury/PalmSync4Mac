defmodule PalmSync4Mac.PalmStructures.DatebookDb do
  @moduledoc """
    Represents a Palm Datebook entries
  """

  use Ash.Resource,
    data_layer: :embedded

  actions do
    defaults([:read, :destroy, :create])
  end

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    #    has_one(:header, PalmSync4Mac.PalmStructures.PdbHeader)
    # has_many(:date_book_entries, Palmsync4mac.PalmStructures.DateBookEntry)
    # has_one(:attributes, Palmsync4mac.PalmStructures.PdbAttributes)
  end
end
