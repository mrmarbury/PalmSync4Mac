defmodule PalmSync4Mac.Entity.EventKit.CalendarEvent do
  @moduledoc """
  Represents a calendar event in the Apple Calendar.
  """
  use Ash.Resource,
    domain: PalmSync4Mac.Entity.EventKit,
    data_layer: AshSqlite.DataLayer

  require Logger

  alias Ash.Error.Changes.InvalidChanges
  alias Ash.Error.Changes.StaleRecord

  sqlite do
    table("calendar_event")
    repo(PalmSync4Mac.Repo)
  end

  identities do
    identity(
      :unique_event,
      [
        :apple_event_id
      ],
      eager_check?: true
    )
  end

  actions do
    defaults([:read, :destroy])

    update(:set_synced_to_palm) do
      change(set_attribute(:sync_to_palm_date, DateTime.utc_now()))
      change(atomic_update(:version, expr(version + 1)))

      accept([
        :rec_id
      ])
    end

    create(:create_or_update) do
      upsert?(true)
      upsert_identity(:unique_event)

      change(set_attribute(:version, 0))
      change(atomic_update(:version, expr(version + 1)))

      upsert_condition(expr(last_modified < ^arg(:new_last_modified)))

      error_handler(fn
        _changeset, %StaleRecord{} ->
          InvalidChanges.exception(
            message: "The event not been modified since it was last written",
            fields: [:last_modified]
          )

        _changeset, other ->
          other
      end)

      accept([
        :source,
        :title,
        :start_date,
        :end_date,
        :notes,
        :url,
        :location,
        :last_modified,
        :invitees,
        :calendar_name,
        :deleted,
        :apple_event_id,
        :rec_id
      ])
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

    attribute(:notes, :string) do
      description(
        "The description of the event or also notes associated with the event, e.g. what it is about."
      )

      allow_nil?(true)
      public?(true)
    end

    attribute(:url, :string) do
      description("The URL of the event as added in the EK event")
      allow_nil?(true)
      public?(true)
    end

    attribute(:location, :string) do
      description("The location of the event, e.g. address, zoom link, etc")
      allow_nil?(true)
      public?(true)
    end

    attribute(:last_modified, :utc_datetime) do
      description("The last time the event was modified as stored by Apple")
      allow_nil?(false)
      public?(true)
    end

    attribute(:calendar_name, :string) do
      description("The name of the calendar the event belongs to")
      allow_nil?(false)
      public?(true)
    end

    attribute(:invitees, {:array, :string}) do
      constraints(remove_nil_items?: true)

      description(
        "The list of invitees for the event. It's an array of emails in the form of 'mailto:em@il'"
      )

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

    attribute(:sync_to_palm_date, :utc_datetime) do
      description("Set to the date the event was synced to the Palm device successfully")
      allow_nil?(true)
      public?(true)
      writable?(true)
    end

    attribute :apple_event_id, :string do
      description(
        "The Apple event uuid which is unique across all calendars. If it's set it means that the event is synced with the Apple Calendar"
      )

      allow_nil?(true)
      public?(true)
    end

    attribute :version, :integer do
      description("Version of the calendar event. Automatically incremented on each update")
      allow_nil?(false)
      public?(true)
      writable?(false)
    end

    attribute :rec_id, :integer do
      description(
        "The record id of the palm record. If the record is new, this will be zero by default. After writing the appointment to the palm it has a rec_id which should be used here when referring to that appointment later"
      )

      allow_nil?(false)
      public?(true)
      writable?(true)
      default(0)
    end
  end
end
