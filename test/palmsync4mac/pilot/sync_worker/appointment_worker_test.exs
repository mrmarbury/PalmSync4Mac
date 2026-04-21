defmodule PalmSync4Mac.Pilot.SyncWorker.AppointmentWorkerTest do
  @moduledoc """
  Contract 3 tests — AppointmentWorker.sync_to_palm rewrite.
  TDD: These tests define the contract invariants and error cases.
  """
  use ExUnit.Case, async: false
  use Patch

  alias PalmSync4Mac.Entity.Device.PalmUser
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent
  alias PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus
  alias PalmSync4Mac.Pilot.SyncWorker.AppointmentWorker

  # Contract: AppointmentWorker — all invariants and error cases

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

    {:ok, pid} = AppointmentWorker.start_link(%AppointmentWorker{client_sd: 42})
    Ecto.Adapters.SQL.Sandbox.allow(PalmSync4Mac.Repo, self(), pid)

    on_exit(fn ->
      case Process.whereis(AppointmentWorker) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end
    end)

    {:ok, palm_user: palm_user, calendar_event: calendar_event}
  end

  describe "list_unsynced_for_device/1 — Contract: AppointmentWorker — 3-case unsynced query" do
    test "returns events with no join row (new events)", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      {:ok, results} = AppointmentWorker.list_unsynced_for_device(palm_user.id)
      event_ids = Enum.map(results, & &1.id)
      assert calendar_event.id in event_ids
    end

    test "returns events with rec_id=0 (previously failed)", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      EkCalendarDatebookSyncStatus
      |> Ash.Changeset.for_create(:create_or_update, %{
        palm_user_id: palm_user.id,
        calendar_event_id: calendar_event.id,
        rec_id: 0,
        last_synced_version: 1,
        last_sync_success: false
      })
      |> Ash.create()

      {:ok, results} = AppointmentWorker.list_unsynced_for_device(palm_user.id)
      event_ids = Enum.map(results, & &1.id)
      assert calendar_event.id in event_ids
    end

    test "returns events when version > last_synced_version (event updated)", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      EkCalendarDatebookSyncStatus
      |> Ash.Changeset.for_create(:create_or_update, %{
        palm_user_id: palm_user.id,
        calendar_event_id: calendar_event.id,
        rec_id: 5,
        last_synced_version: -1,
        last_sync_success: true
      })
      |> Ash.create()

      assert calendar_event.version > -1

      {:ok, results} = AppointmentWorker.list_unsynced_for_device(palm_user.id)
      event_ids = Enum.map(results, & &1.id)
      assert calendar_event.id in event_ids
    end

    test "excludes events already synced with matching version", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      EkCalendarDatebookSyncStatus
      |> Ash.Changeset.for_create(:create_or_update, %{
        palm_user_id: palm_user.id,
        calendar_event_id: calendar_event.id,
        rec_id: 5,
        last_synced_version: calendar_event.version,
        last_sync_success: true
      })
      |> Ash.create()

      {:ok, results} = AppointmentWorker.list_unsynced_for_device(palm_user.id)
      event_ids = Enum.map(results, & &1.id)
      refute calendar_event.id in event_ids
    end

    test "does not return events from a different palm_user_id", %{
      calendar_event: calendar_event
    } do
      {:ok, other_user} =
        PalmUser
        |> Ash.Changeset.for_create(:create_or_update, %{
          username: "other_user_#{System.unique_integer()}",
          password_length: 0,
          user_id: System.unique_integer(),
          viewer_id: 0,
          last_sync_pc: 0,
          last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
        })
        |> Ash.create()

      EkCalendarDatebookSyncStatus
      |> Ash.Changeset.for_create(:create_or_update, %{
        palm_user_id: other_user.id,
        calendar_event_id: calendar_event.id,
        rec_id: 5,
        last_synced_version: calendar_event.version,
        last_sync_success: true
      })
      |> Ash.create()

      {:ok, results} = AppointmentWorker.list_unsynced_for_device(other_user.id)
      event_ids = Enum.map(results, & &1.id)
      refute calendar_event.id in event_ids
    end
  end

  describe "sync_to_palm/2 — Contract: AppointmentWorker — join row creation" do
    test "creates join row with rec_id on success", %{palm_user: palm_user} do
      patch(PalmSync4Mac.Comms.Pidlp, :open_db, fn _sd, _card, _mode, _name ->
        {:ok, 42, 1}
      end)

      patch(PalmSync4Mac.Comms.Pidlp, :write_datebook_record, fn _sd, _db, _apt ->
        {:ok, 42, 100, 42}
      end)

      patch(PalmSync4Mac.Comms.Pidlp, :close_db, fn _sd, _db -> {:ok, 42} end)

      result = AppointmentWorker.sync_to_palm(42, palm_user.id)
      assert result == :ok

      {:ok, rows} = Ash.read(EkCalendarDatebookSyncStatus)
      synced = Enum.find(rows, &(&1.palm_user_id == palm_user.id))
      assert synced.rec_id == 42
      assert synced.last_sync_success == true
    end

    test "creates join row with rec_id=0 on NIF write failure", %{palm_user: palm_user} do
      patch(PalmSync4Mac.Comms.Pidlp, :open_db, fn _sd, _card, _mode, _name ->
        {:ok, 42, 1}
      end)

      patch(PalmSync4Mac.Comms.Pidlp, :write_datebook_record, fn _sd, _db, _apt ->
        {:error, 42, -1, "write failed"}
      end)

      patch(PalmSync4Mac.Comms.Pidlp, :close_db, fn _sd, _db -> {:ok, 42} end)

      result = AppointmentWorker.sync_to_palm(42, palm_user.id)
      assert result == :ok

      {:ok, rows} = Ash.read(EkCalendarDatebookSyncStatus)
      failed = Enum.find(rows, &(&1.palm_user_id == palm_user.id))
      assert failed.rec_id == 0
      assert failed.last_sync_success == false
    end

    test "creates failed join rows for ALL pending events when open_db fails", %{
      palm_user: palm_user
    } do
      patch(PalmSync4Mac.Comms.Pidlp, :open_db, fn _sd, _card, _mode, _name ->
        {:error, 42, -1, "db open failed"}
      end)

      result = AppointmentWorker.sync_to_palm(42, palm_user.id)
      assert result == :ok

      {:ok, rows} = Ash.read(EkCalendarDatebookSyncStatus)
      failed = Enum.find(rows, &(&1.palm_user_id == palm_user.id))
      assert failed.rec_id == 0
      assert failed.last_sync_success == false
    end

    test "returns :ok when no unsynced events exist", %{
      palm_user: palm_user,
      calendar_event: calendar_event
    } do
      patch(PalmSync4Mac.Comms.Pidlp, :open_db, fn _sd, _card, _mode, _name ->
        {:ok, 42, 1}
      end)

      patch(PalmSync4Mac.Comms.Pidlp, :close_db, fn _sd, _db -> {:ok, 42} end)

      EkCalendarDatebookSyncStatus
      |> Ash.Changeset.for_create(:create_or_update, %{
        palm_user_id: palm_user.id,
        calendar_event_id: calendar_event.id,
        rec_id: 5,
        last_synced_version: calendar_event.version,
        last_sync_success: true
      })
      |> Ash.create()

      result = AppointmentWorker.sync_to_palm(42, palm_user.id)
      assert result == :ok
    end
  end
end
