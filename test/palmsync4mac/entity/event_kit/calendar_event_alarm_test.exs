defmodule PalmSync4Mac.Entity.EventKit.CalendarEventAlarmTest do
  @moduledoc """
  Tests for CalendarEvent alarm fields — verifies that alarms_seconds is
  stored, sorted, and triggers upserts correctly (including alarm-only changes
  that don't bump last_modified).
  """
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias PalmSync4Mac.Entity.EventKit.CalendarEvent

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PalmSync4Mac.Repo)
    :ok
  end

  def create_event(overrides \\ %{}) do
    defaults = %{
      source: "apple",
      title: "Test Event #{System.unique_integer()}",
      start_date: DateTime.utc_now(),
      end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
      last_modified: DateTime.utc_now(),
      calendar_name: "Calendar",
      apple_event_id: "test-apple-id-#{System.unique_integer()}",
      alarms_seconds: []
    }

    CalendarEvent
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_argument(:new_last_modified, Map.merge(defaults, overrides)[:last_modified])
    |> Ash.Changeset.set_argument(:new_alarms_seconds, Map.merge(defaults, overrides)[:alarms_seconds])
    |> Ash.Changeset.for_create(:create_or_update, Map.merge(defaults, overrides))
    |> Ash.create()
  end

  def upsert_event(apple_id, overrides) do
    CalendarEvent
    |> Ash.Changeset.new()
    |> Ash.Changeset.set_argument(:new_last_modified, overrides[:last_modified])
    |> Ash.Changeset.set_argument(:new_alarms_seconds, overrides[:alarms_seconds])
    |> Ash.Changeset.for_create(:create_or_update, %{
      source: "apple",
      title: overrides[:title] || "Updated Event",
      start_date: overrides[:start_date] || DateTime.utc_now(),
      end_date: overrides[:end_date] || DateTime.add(DateTime.utc_now(), 3600, :second),
      last_modified: overrides[:last_modified],
      calendar_name: "Calendar",
      apple_event_id: apple_id,
      alarms_seconds: overrides[:alarms_seconds]
    })
    |> Ash.create()
  end

  describe "alarm storage" do
    test "no alarms set — stored as []" do
      {:ok, event} = create_event(%{alarms_seconds: []})
      assert event.alarms_seconds == []
    end

    test "single alarm — stored as [offset]" do
      {:ok, event} = create_event(%{alarms_seconds: [-900]})
      assert event.alarms_seconds == [-900]
    end

    test "multiple alarms — stored as given (Swift pre-sorts)" do
      {:ok, event} = create_event(%{alarms_seconds: [-900, 0, 600]})
      assert event.alarms_seconds == [-900, 0, 600]
    end
  end

  describe "upsert behavior with alarms" do
    test "changing alarms with last_modified bump — updates" do
      {:ok, event} = create_event(%{alarms_seconds: [-900]})
      old_modified = event.last_modified

      new_modified = DateTime.add(old_modified, 60, :second)
      {:ok, updated} = upsert_event(event.apple_event_id, %{
        last_modified: new_modified,
        alarms_seconds: [-1800]
      })

      assert updated.id == event.id
      assert updated.alarms_seconds == [-1800]
      assert DateTime.compare(updated.last_modified, old_modified) == :gt
    end

    test "alarm-only change (same last_modified, different alarms) — updates" do
      {:ok, event} = create_event(%{alarms_seconds: [-900]})
      old_modified = event.last_modified

      {:ok, updated} = upsert_event(event.apple_event_id, %{
        last_modified: old_modified,
        alarms_seconds: [-1800]
      })

      assert updated.id == event.id
      assert updated.alarms_seconds == [-1800]
    end

    test "no change at all (same last_modified + same alarms) — rejected as stale" do
      {:ok, event} = create_event(%{alarms_seconds: [-900]})

      result = upsert_event(event.apple_event_id, %{
        last_modified: event.last_modified,
        alarms_seconds: [-900]
      })

      assert {:error, %Ash.Error.Invalid{}} = result
    end
  end

  describe "property tests" do
    property "upsert stores any integer list as given" do
      check all(alarms <- list_of(integer(-86400..0))) do
        {:ok, event} = create_event(%{alarms_seconds: alarms})
        assert event.alarms_seconds == alarms
      end
    end

    property "different alarms trigger update even with same last_modified" do
      check all(
              alarms_a <- list_of(integer(-86400..0), min_length: 1, max_length: 5),
              alarms_b <- list_of(integer(-86400..0), min_length: 1, max_length: 5),
              max_runs: 50
            ) do
        # Skip if lists happen to be equal
        if alarms_a != alarms_b do
          {:ok, event} = create_event(%{alarms_seconds: alarms_a})

          {:ok, updated} = upsert_event(event.apple_event_id, %{
            last_modified: event.last_modified,
            alarms_seconds: alarms_b
          })

          assert updated.alarms_seconds == alarms_b
        end
      end
    end
  end
end
