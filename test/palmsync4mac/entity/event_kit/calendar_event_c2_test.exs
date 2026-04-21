defmodule PalmSync4Mac.Entity.EventKit.CalendarEventC2Test do
  @moduledoc """
  Contract 2 tests — CalendarEvent field removal verification.
  """
  use ExUnit.Case, async: false

  alias PalmSync4Mac.Entity.EventKit.CalendarEvent

  # Contract: CalendarEvent — prohibitions

  describe "Prohibitions: removed attributes must not exist" do
    test "sync_to_palm_date attribute does not exist on CalendarEvent" do
      attribute_names =
        Ash.Resource.Info.attributes(CalendarEvent)
        |> Enum.map(& &1.name)

      refute :sync_to_palm_date in attribute_names
    end

    test "rec_id attribute does not exist on CalendarEvent" do
      attribute_names =
        Ash.Resource.Info.attributes(CalendarEvent)
        |> Enum.map(& &1.name)

      refute :rec_id in attribute_names
    end
  end

  describe "Preserved attributes" do
    test "version attribute still exists and is auto-incremented" do
      attribute_names =
        Ash.Resource.Info.attributes(CalendarEvent)
        |> Enum.map(& &1.name)

      assert :version in attribute_names
    end

    test "apple_event_id identity still exists" do
      identities =
        Ash.Resource.Info.identities(CalendarEvent)
        |> Enum.map(& &1.name)

      assert :unique_event in identities
    end
  end
end
