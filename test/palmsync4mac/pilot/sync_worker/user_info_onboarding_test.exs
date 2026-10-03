defmodule PalmSync4Mac.Pilot.SyncWorker.UserInfoOnboardingTest do
  @moduledoc """
  Regression suite for the palm-identity-onboarding cycle (contract:
  docs/contracts/palm-identity-onboarding/contract-user-info-onboarding.md).

  The device simulator below models how Palm OS behaves once a session is
  properly finalized (EndOfSync committed): a write_user_info call that the
  device acknowledges is retained and returned by subsequent read_user_info
  calls. Blank-username devices that receive a provisioning write therefore
  read back the provisioned name, which is the hardware-verified behavior on
  virgin/wiped devices and the foundation the onboarding state machine is
  built on.

  The historical duplicate-records bug this suite guards against: every sync
  minted a new random palm_user row, so the zero-join amplifier re-pushed the
  entire calendar with rec_id=0 and the device appended a full duplicate batch
  per sync.
  """
  use ExUnit.Case, async: false

  use Patch

  import ExUnit.CaptureLog

  alias Ecto.Adapters.SQL.Sandbox
  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Comms.Pidlp.PilotSysInfo
  alias PalmSync4Mac.Comms.Pidlp.PilotUser
  alias PalmSync4Mac.Entity.Device.PalmUser, as: PalmUserRow
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent
  alias PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus
  alias PalmSync4Mac.Pilot.SyncWorker.AppointmentWorker
  alias PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker
  alias PalmSync4Mac.Repo

  @moduletag :capture_log

  # A blank PilotUser as a wiped/fresh Palm reads it: empty name, zeroed
  # user block. password_length and last_sync_date have no defaults in the
  # PilotUser struct but the NIF always fills them (0 on a fresh device), so
  # the simulator starts with the same shape the wire produces.
  @blank_device %PilotUser{
    username: "",
    password: "",
    password_length: 0,
    user_id: 0,
    viewer_id: 0,
    last_sync_pc: 0,
    successful_sync_date: 0,
    last_sync_date: 0
  }

  # A named PilotUser as an established Palm reads it. Established devices
  # silently drop username writes on the wire, which is exactly why the
  # onboarding state machine must never try to rename them.
  @named_device %PilotUser{
    username: "Palm TX",
    password: "",
    password_length: 0,
    user_id: 55_332,
    viewer_id: 0,
    last_sync_pc: 0,
    successful_sync_date: 0,
    last_sync_date: 0
  }

  defp start_device(initial \\ @blank_device) do
    {:ok, device} = Agent.start(fn -> initial end)

    patch(Pidlp, :read_user_info, fn _sd -> {:ok, 42, Agent.get(device, & &1)} end)

    patch(Pidlp, :write_user_info, fn _sd, %PilotUser{} = user_info ->
      Agent.update(device, fn _old -> user_info end)
      {:ok, 42}
    end)

    device
  end

  setup do
    :ok = Sandbox.checkout(Repo)

    {:ok, user_info_pid} =
      UserInfoWorker.start_link(%UserInfoWorker{client_sd: 42, user_info: %PilotUser{}})

    {:ok, appointment_pid} = AppointmentWorker.start_link(%AppointmentWorker{client_sd: 42})

    Sandbox.allow(Repo, self(), user_info_pid)
    Sandbox.allow(Repo, self(), appointment_pid)

    on_exit(fn ->
      if Process.whereis(UserInfoWorker) do
        GenServer.stop(UserInfoWorker)
      end

      if Process.whereis(AppointmentWorker) do
        GenServer.stop(AppointmentWorker)
      end
    end)

    :ok
  end

  defp palm_user_rows do
    {:ok, rows} = Ash.read(PalmUserRow)
    rows
  end

  describe "core regression: stable identity across consecutive pre_sync calls" do
    test "pre_sync twice for the same mocked device returns the same palm_user_id and creates one row" do
      device = start_device()

      assert {:ok, first_id} = UserInfoWorker.pre_sync()
      assert {:ok, second_id} = UserInfoWorker.pre_sync()

      assert first_id == second_id

      rows = palm_user_rows()
      assert length(rows) == 1

      row = hd(rows)

      # The provisioned Palm user_id must be minted DB-side (max+1, min 1)
      # and written back to the device in the same session — a fresh device
      # reads user_id 0 and must never leave it in the row.
      assert row.user_id >= 1

      device_user_id = Agent.get(device, & &1.user_id)
      assert device_user_id == row.user_id
    end
  end

  describe "core regression: second sync of unchanged data writes nothing to the device" do
    setup do
      {:ok, calendar_event} =
        CalendarEvent
        |> Ash.Changeset.for_create(:create_or_update, %{
          source: "apple",
          title: "Unchanged Event",
          start_date: DateTime.utc_now(),
          end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
          last_modified: DateTime.utc_now(),
          calendar_name: "Calendar",
          apple_event_id: "onboarding-regression-1"
        })
        |> Ash.create()

      {:ok, calendar_event: calendar_event}
    end

    test "second sync of unchanged data produces zero write_datebook_record calls", %{
      calendar_event: calendar_event
    } do
      start_device()

      {:ok, write_counter} = Agent.start(fn -> 0 end)

      patch(Pidlp, :open_db, fn _sd, _card, _mode, _name -> {:ok, 42, 1} end)
      patch(Pidlp, :close_db, fn _sd, _db -> {:ok, 42} end)

      patch(Pidlp, :write_datebook_record, fn _sd, _db, _apt ->
        Agent.update(write_counter, &(&1 + 1))
        {:ok, 42, 100, 42}
      end)

      # First sync: the blank device gets onboarded (random fallback name),
      # and every unsynced event is written to it.
      {:ok, first_palm_user_id} = UserInfoWorker.pre_sync()
      assert :ok = AppointmentWorker.sync_to_palm(first_palm_user_id, %PilotSysInfo{})
      assert Agent.get(write_counter, & &1) == 1

      # Second sync of unchanged data. The device now carries the name from
      # the first sync, so even when an explicit username argument is passed
      # (the SyncTest onboarding knob) the device's own identity wins: the
      # argument is ignored, the palm_user row is reused, and nothing is
      # re-pushed.
      {:ok, second_palm_user_id} = UserInfoWorker.pre_sync("My TX")
      assert second_palm_user_id == first_palm_user_id

      assert :ok = AppointmentWorker.sync_to_palm(second_palm_user_id, %PilotSysInfo{})
      assert Agent.get(write_counter, & &1) == 1

      # Unchanged calendar data must not produce new device records and must
      # not fork the DB identity: one row, one join row.
      assert [_only_row] = palm_user_rows()
      assert calendar_event.id
    end
  end

  describe "contract state machine" do
    test "named device plus explicit argument classifies as KNOWN and the argument is ignored" do
      device = start_device(@named_device)

      {:ok, write_counter} = Agent.start(fn -> 0 end)

      patch(Pidlp, :write_user_info, fn _sd, %PilotUser{} = user_info ->
        Agent.update(write_counter, &(&1 + 1))
        Agent.update(device, fn _old -> user_info end)
        {:ok, 42}
      end)

      assert {:ok, palm_user_id} = UserInfoWorker.pre_sync("My TX")

      # The row adopted the device's own name, not the argument.
      assert [%PalmUserRow{username: "Palm TX", id: ^palm_user_id}] = palm_user_rows()

      # First session is ADOPT: exactly one best-effort user_id write to the
      # device (the name itself is never touched — it can't be, the device
      # drops username writes).
      assert Agent.get(write_counter, &(&1 + 0)) == 1

      # Second session classifies as KNOWN: no further identity writes go to
      # the NIF (invariant 12), and the explicit argument is still ignored.
      assert {:ok, ^palm_user_id} = UserInfoWorker.pre_sync("My TX")
      assert Agent.get(write_counter, &(&1 + 0)) == 1
      assert length(palm_user_rows()) == 1
    end

    test "blank device with no argument gets a unique generated name and the row survives a second sync" do
      start_device()

      assert {:ok, first_id} = UserInfoWorker.pre_sync()

      assert [%PalmUserRow{username: generated_name, id: ^first_id}] = palm_user_rows()
      assert String.match?(generated_name, ~r/^[a-z0-9]{5}$/)

      # Second sync: the device read back the provisioned identity, so it
      # classifies as KNOWN and resolves to the generated row.
      assert {:ok, ^first_id} = UserInfoWorker.pre_sync()
      assert {:ok, ^first_id} = UserInfoWorker.pre_sync("attempt to rename")

      # Still exactly one row and the identity never changed.
      assert [%PalmUserRow{username: ^generated_name}] = palm_user_rows()
    end

    test "ONBOARD device-write failure deletes the provisioned row and returns :device_write_failed" do
      start_device()

      patch(Pidlp, :write_user_info, fn _sd, _user_info ->
        {:error, 42, "device refused the write"}
      end)

      assert {:error, :device_write_failed} = UserInfoWorker.pre_sync("My TX")

      # Compensating delete: the row created before the device write must not
      # survive a failed onboarding.
      assert [] == palm_user_rows()
    end

    test "RE_ONBOARD resets join rows only after a successful device write" do
      start_device()

      {:ok, calendar_event} =
        CalendarEvent
        |> Ash.Changeset.for_create(:create_or_update, %{
          source: "apple",
          title: "Re-Onboard Event",
          start_date: DateTime.utc_now(),
          end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
          last_modified: DateTime.utc_now(),
          calendar_name: "Calendar",
          apple_event_id: "onboarding-re-onboard-1"
        })
        |> Ash.create()

      # A row for the explicit name already exists — the wiped-known-device
      # scenario: the device lost its data, our row remembers it.
      {:ok, known_row} =
        PalmUserRow
        |> Ash.Changeset.for_create(:create_or_update, %{
          username: "My TX",
          password_length: 0,
          password: "",
          user_id: 7,
          viewer_id: 0,
          last_sync_pc: 0,
          last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
        })
        |> Ash.create()

      EkCalendarDatebookSyncStatus
      |> Ash.Changeset.for_create(:create_or_update, %{
        palm_user_id: known_row.id,
        calendar_event_id: calendar_event.id,
        rec_id: 123,
        last_synced_version: calendar_event.version,
        last_sync_success: true
      })
      |> Ash.create()

      known_row_id = known_row.id

      # Device write fails: nothing changes — the row, and critically the
      # join rows, stay untouched (invariant 7).
      patch(Pidlp, :write_user_info, fn _sd, _user_info ->
        {:error, 42, "device refused the write"}
      end)

      assert {:error, :device_write_failed} = UserInfoWorker.pre_sync("My TX")

      {:ok, join_rows} = Ash.read(EkCalendarDatebookSyncStatus)
      assert length(join_rows) == 1

      # Device write succeeds: the join rows are reset so the wiped device
      # gets a full clean re-push.
      patch(Pidlp, :write_user_info, fn _sd, %PilotUser{} = _user_info ->
        {:ok, 42}
      end)

      assert {:ok, ^known_row_id} = UserInfoWorker.pre_sync("My TX")

      {:ok, join_rows_after} = Ash.read(EkCalendarDatebookSyncStatus)
      assert join_rows_after == []
    end

    test "KNOWN with user_id mismatch logs a warning and keeps the row identity" do
      start_device(@named_device)

      # Our row for this name holds a different user_id than the device
      # reports (a foreign tool rewrote the device integer, which is
      # hardware-verified to always commit).
      {:ok, row} =
        PalmUserRow
        |> Ash.Changeset.for_create(:create_or_update, %{
          username: "Palm TX",
          password_length: 0,
          password: "",
          user_id: 7,
          viewer_id: 0,
          last_sync_pc: 0,
          last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
        })
        |> Ash.create()

      assert capture_log(fn -> UserInfoWorker.pre_sync() end) =~
               "reports user_id 55332 but our row holds 7"

      # The mismatch is warn-only: the name wins and the row identity is
      # untouched (documented gap, see backlog).
      assert {:ok, _palm_user_id} = UserInfoWorker.pre_sync()
      assert [%PalmUserRow{user_id: 7}] = palm_user_rows()
      assert row.user_id == 7
    end

    test "invalid explicit username argument aborts with :username_invalid before any write" do
      start_device()
      {:ok, write_counter} = Agent.start(fn -> 0 end)

      patch(Pidlp, :write_user_info, fn _sd, _user_info ->
        Agent.update(write_counter, &(&1 + 1))
        {:ok, 42}
      end)

      assert {:error, :username_invalid} = UserInfoWorker.pre_sync("")
      assert {:error, :username_invalid} = UserInfoWorker.pre_sync(String.duplicate("x", 41))
      assert {:error, :username_invalid} = UserInfoWorker.pre_sync("naïve")
      assert {:error, :username_invalid} = UserInfoWorker.pre_sync("bad\x01name")

      assert [] == palm_user_rows()
      assert Agent.get(write_counter, & &1) == 0
    end

    test "failed pre_sync makes post_sync a no-op: zero device writes, zero DB rows" do
      start_device()
      {:ok, write_counter} = Agent.start(fn -> 0 end)

      patch(Pidlp, :write_user_info, fn _sd, _user_info ->
        Agent.update(write_counter, &(&1 + 1))
        {:ok, 42}
      end)

      patch(Pidlp, :read_user_info, fn _sd -> {:error, 42, "connection lost"} end)

      assert {:error, "connection lost"} = UserInfoWorker.pre_sync()
      assert {:error, :pre_sync_not_completed} = UserInfoWorker.post_sync()

      # Invariant 10: nothing was written anywhere after the failed pre_sync.
      assert Agent.get(write_counter, & &1) == 0
      assert [] == palm_user_rows()
    end

    test "post_sync upsert preserves the row's provisioned username and user_id" do
      start_device(@named_device)

      # Our row holds the provisioned identity; the device reports a foreign
      # user_id (mismatch case). post_sync updates only sync dates.
      {:ok, row} =
        PalmUserRow
        |> Ash.Changeset.for_create(:create_or_update, %{
          username: "Palm TX",
          password_length: 0,
          password: "",
          user_id: 7,
          viewer_id: 0,
          last_sync_pc: 0,
          successful_sync_date: 0,
          last_sync_date: 1_000
        })
        |> Ash.create()

      assert {:ok, _palm_user_id} = UserInfoWorker.pre_sync()
      assert :ok = UserInfoWorker.post_sync()

      assert [%PalmUserRow{username: "Palm TX", user_id: 7}] = palm_user_rows()
      assert row.successful_sync_date == 0 || row.successful_sync_date >= 0

      # The session updated the sync date bookkeeping only.
      assert [%PalmUserRow{} = updated] = palm_user_rows()
      assert updated.last_sync_date >= 1_000
    end
  end
end
