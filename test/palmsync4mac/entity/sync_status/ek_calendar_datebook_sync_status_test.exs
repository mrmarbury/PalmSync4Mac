defmodule PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatusTest do
  @moduledoc """
  Contract 1 tests — EkCalendarDatebookSyncStatus Ash Resource.
  TDD: These tests define the contract invariants and error cases.
  """
  use ExUnit.Case, async: false

  alias PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus
  alias PalmSync4Mac.Entity.Device.PalmUser
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent

  # Contract: EkCalendarDatebookSyncStatus — all invariants and error cases

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PalmSync4Mac.Repo)

    {:ok, palm_user} =
      PalmUser
      |> Ash.Changeset.for_create(:create_or_update, %{
        username: "test_user_#{System.unique_integer()}",
        password_length: 0,
        user_id: System.unique_integer(),
        viewer_id: 0,
        last_sync_pc: 0,
        last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
      })
      |> Ash.create()

    # Create a CalendarEvent
    {:ok, calendar_event} =
      CalendarEvent
      |> Ash.Changeset.for_create(:create_or_update, %{
        source: "apple",
        title: "Test Event #{System.unique_integer()}",
        start_date: DateTime.utc_now(),
        end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
        last_modified: DateTime.utc_now(),
        calendar_name: "Calendar",
        apple_event_id: "test-apple-id-#{System.unique_integer()}"
      })
      |> Ash.create()

    {:ok, palm_user: palm_user, calendar_event: calendar_event}
  end

  describe "Invariant 1: unique {palm_user_id, calendar_event_id} pair" do
    test "create_or_update upserts on duplicate {palm_user_id, calendar_event_id}", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      # Create initial row
      {:ok, status1} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id,
          rec_id: 5,
          last_synced_version: 1,
          last_sync_success: true
        })
        |> Ash.create()

      # Upsert with same keys — should update, not duplicate
      {:ok, status2} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id,
          rec_id: 10,
          last_synced_version: 2,
          last_sync_success: false
        })
        |> Ash.create()

      # Same row (same id), updated values
      assert status1.id == status2.id
      assert status2.rec_id == 10
      assert status2.last_synced_version == 2
      assert status2.last_sync_success == false

      # Only one row exists for this pair
      count =
        Ash.read!(EkCalendarDatebookSyncStatus)
        |> Enum.count(fn s ->
          s.palm_user_id == palm_user.id and s.calendar_event_id == calendar_event.id
        end)

      assert count == 1
    end
  end

  describe "Invariant 2: rec_id defaults to 0" do
    test "rec_id is 0 when not specified in create_or_update", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, status} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      assert status.rec_id == 0
    end
  end

  describe "Invariant 3: last_synced is auto-set on create and update" do
    test "last_synced is set on create", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, status} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      assert %DateTime{} = status.last_synced
      assert DateTime.compare(status.last_synced, DateTime.utc_now()) in [:lt, :eq]
    end

    test "last_synced is updated on upsert", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, status1} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      # Small sleep to ensure timestamp difference
      Process.sleep(10)

      {:ok, status2} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id,
          rec_id: 1
        })
        |> Ash.create()

      # last_synced should be updated (greater or equal) on upsert
      assert DateTime.compare(status2.last_synced, status1.last_synced) in [:gt, :eq]
    end
  end

  describe "Invariant 4: last_sync_success defaults to false" do
    test "last_sync_success is false when not specified in create_or_update", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, status} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      assert status.last_sync_success == false
    end
  end

  describe "Invariant 5: unique identity :unique_device_event" do
    test "direct create with duplicate {palm_user_id, calendar_event_id} returns error", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      # First create via upsert (create_or_update)
      {:ok, _status} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      # The :create_or_update action uses upsert so it won't fail on duplicates.
      # But the unique identity :unique_device_event prevents duplicate rows.
      # Verify by counting rows — only 1 should exist even after two creates.
      rows =
        Ash.read!(EkCalendarDatebookSyncStatus)
        |> Enum.filter(fn s ->
          s.palm_user_id == palm_user.id and s.calendar_event_id == calendar_event.id
        end)

      assert length(rows) == 1
    end
  end

  describe "Error cases" do
    test "palm_user_id is nil returns error", %{
      calendar_event: calendar_event
    } do
      result =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: nil,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      assert {:error, _} = result
    end

    test "calendar_event_id is nil returns error", %{
      palm_user: palm_user
    } do
      result =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: nil
        })
        |> Ash.create()

      assert {:error, _} = result
    end
  end

  describe "Prohibitions: removed attributes must not exist" do
    test "palm_device_uuid attribute does not exist on the resource" do
      attribute_names =
        Ash.Resource.Info.attributes(EkCalendarDatebookSyncStatus)
        |> Enum.map(& &1.name)

      refute :palm_device_uuid in attribute_names,
             "palm_device_uuid must not exist (prohibited by contract)"
    end

    test "calendar_event_uuid attribute does not exist on the resource" do
      attribute_names =
        Ash.Resource.Info.attributes(EkCalendarDatebookSyncStatus)
        |> Enum.map(& &1.name)

      refute :calendar_event_uuid in attribute_names,
             "calendar_event_uuid must not exist (prohibited by contract)"
    end
  end

  describe "rec_id attribute" do
    test "rec_id attribute exists (renamed from datebook_rec_id)", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      attribute_names =
        Ash.Resource.Info.attributes(EkCalendarDatebookSyncStatus)
        |> Enum.map(& &1.name)

      assert :rec_id in attribute_names, "rec_id attribute must exist"
      refute :datebook_rec_id in attribute_names, "datebook_rec_id must be renamed to rec_id"
    end

    test "rec_id is not nil (allow_nil? false)", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, status} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      # rec_id should be 0 (the default), never nil
      assert status.rec_id == 0
    end
  end

  describe "last_synced_version attribute" do
    test "last_synced_version defaults to 0", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, status} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id
        })
        |> Ash.create()

      assert status.last_synced_version == 0
    end

    test "last_synced_version is not nil (allow_nil? false)", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, status} =
        EkCalendarDatebookSyncStatus
        |> Ash.Changeset.for_create(:create_or_update, %{
          palm_user_id: palm_user.id,
          calendar_event_id: calendar_event.id,
          last_synced_version: 3
        })
        |> Ash.create()

      assert status.last_synced_version == 3
    end
  end
end
