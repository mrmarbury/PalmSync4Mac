defmodule Palmsync4mac.PalmStructures.PdbHeader do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:name, :string) do
      description(
        "A 32-byte long, null-terminated string containing the name of the database on the Palm Powered handheld. The name is restricted to 31 bytes in length, plus the terminator byte."
      )

      allow_nil?(false)
      public?(true)
    end

    attribute(:version, :integer) do
      description("The application-specific version of the database layout.")
      allow_nil?(false)
      public?(true)
      default(0)
    end

    attribute(:creation_date, :palm_datetime) do
      description(
        "The creation date of the database, specified as the number of seconds since 12:00 A.M. on January 1, 1904."
      )

      allow_nil?(false)
      public?(true)
      default(DateTime.utc_now())
    end

    attribute(:modification_date, :palm_datetime) do
      description(
        "The modification date of the database, specified as the number of seconds since 12:00 A.M. on January 1, 1904."
      )

      allow_nil?(false)
      public?(true)
      default(DateTime.utc_now())
    end

    attribute(:last_backup_date, :palm_datetime) do
      description(
        "The date of the most recent backup, specified as the number of seconds since 12:00 A.M. on January 1, 1904."
      )

      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    has_many(:date_book_entries, Palmsync4mac.PalmStructures.DateBookEntry)
    has_one(:attributes, Palmsync4mac.PalmStructures.PdbAttributes)
  end
end
