defmodule PalmSync4Mac.EventKit.CalendarEventWorkerTest do
  @moduledoc """
  Tests for CalendarEventWorker.sync_calendar/2 alarm cleaning: raw Apple
  alarm offsets are cleaned once at the write path — positives discarded,
  defaults substituted — and the cleaned list becomes BOTH the stored
  attribute and the `new_alarms_seconds` upsert condition argument.
  """
  use ExUnit.Case, async: false
  use Patch

  import ExUnit.CaptureLog

  alias Ecto.Adapters.SQL.Sandbox
  alias PalmSync4Mac.Entity.EventKit.CalendarEvent
  alias PalmSync4Mac.EventKit.CalendarEventWorker
  alias PalmSync4Mac.EventKit.PortHandler
  alias PalmSync4Mac.Repo

  setup do
    :ok = Sandbox.checkout(Repo)

    # Set the default-substitution config explicitly (restoring the prior
    # value afterwards) instead of relying implicitly on config/config.exs —
    # mirrors how datebook_appointment_test.exs manages :pick_alarm.
    prior_default = Application.get_env(:palm_sync_4_mac, :default_alarm_seconds)
    Application.put_env(:palm_sync_4_mac, :default_alarm_seconds, 600)

    on_exit(fn ->
      Application.put_env(:palm_sync_4_mac, :default_alarm_seconds, prior_default)
    end)

    # The worker sends itself :auto_sync from init/1. The real PortHandler is
    # not running in MIX_ENV=test (start_event_kit_sup: false), so patch
    # get_events/2 with an empty event list BEFORE start_link — init's sync is
    # then deterministically harmless — and drain it with :sys.get_state/1 so
    # every test starts from a quiet worker.
    patch(PortHandler, :get_events, fn _interval, _calendar -> {:ok, %{"events" => []}} end)

    pid =
      start_supervised!(%{
        id: CalendarEventWorker,
        start: {CalendarEventWorker, :start_link, [[], 13]}
      })

    :ok = Sandbox.allow(Repo, self(), pid)
    :sys.get_state(pid)

    {:ok, pid: pid}
  end

  # Fixture shaped like the real Swift port payload (ISO8601 date strings,
  # string keys). `source` is added by PortHandler.normalize_response_data/1.
  defp event_fixture(apple_event_id, alarms_seconds) do
    now = DateTime.utc_now()

    %{
      "apple_event_id" => apple_event_id,
      "title" => "Worker Test Event",
      "source" => "apple",
      "last_modified" => DateTime.to_iso8601(now),
      "start_date" => DateTime.to_iso8601(now),
      "end_date" => DateTime.to_iso8601(DateTime.add(now, 3600, :second)),
      "calendar_name" => "Calendar",
      "deleted" => false,
      "alarms_seconds" => alarms_seconds
    }
  end

  defp unique_apple_id(prefix), do: "worker-test-#{prefix}-#{System.unique_integer()}"

  defp sync_once(pid, events) do
    patch(PortHandler, :get_events, fn _interval, _calendar -> {:ok, %{"events" => events}} end)
    send(pid, :auto_sync)
    # Barrier: the :sys.get_state system message is queued after :auto_sync, so
    # it is only answered once the whole sync (writes included) has completed.
    :sys.get_state(pid)
    :ok
  end

  defp fetch_event(apple_event_id) do
    {:ok, rows} = Ash.read(CalendarEvent)
    Enum.find(rows, &(&1.apple_event_id == apple_event_id))
  end

  describe "sync_calendar/2 alarm cleaning" do
    # A mixed offset list exercises the whole cleaning path at once:
    # positives are discarded, the cleaned list is stored, and the very
    # same list is used as the new_alarms_seconds upsert argument — a
    # re-sync of the unchanged event must therefore be rejected as
    # stale, not silently updated.
    test "mixed offsets keep only the valid ones in both attrs and upsert arg", %{pid: pid} do
      apple_id = unique_apple_id("mixed")
      event = event_fixture(apple_id, [-600, 300])

      sync_once(pid, [event])

      row = fetch_event(apple_id)
      refute is_nil(row)
      assert row.alarms_seconds == [-600]

      log =
        capture_log(fn -> sync_once(pid, [event]) end)

      assert log =~ "Failed to create or update calendar event"
      assert fetch_event(apple_id).alarms_seconds == [-600]
    end

    # A missing "alarms_seconds" key means "no alarm": stored as [] and NO
    # default is inserted — nil-to-[] handling is the worker's job, since
    # an absent key carries no "the user wanted an alarm" signal.
    test "missing alarms_seconds key stores [] without inserting a default", %{pid: pid} do
      apple_id = unique_apple_id("missing")
      event = event_fixture(apple_id, nil) |> Map.drop(["alarms_seconds"])

      sync_once(pid, [event])

      row = fetch_event(apple_id)
      refute is_nil(row)
      assert row.alarms_seconds == []
    end

    # An explicitly empty alarm list is a positive "user has no alarm"
    # statement, so no default may be smuggled in.
    test "explicit empty alarm list stays [] with no default", %{pid: pid} do
      apple_id = unique_apple_id("empty")
      sync_once(pid, [event_fixture(apple_id, [])])

      row = fetch_event(apple_id)
      refute is_nil(row)
      assert row.alarms_seconds == []
    end

    # The user did set alarms, they were just all unrepresentable
    # (positive); exactly the configured default is stored so the event
    # keeps having an alarm.
    test "all-positive offsets substitute the default alarm", %{pid: pid} do
      apple_id = unique_apple_id("all-positive")
      sync_once(pid, [event_fixture(apple_id, [300, 600])])

      row = fetch_event(apple_id)
      refute is_nil(row)
      assert row.alarms_seconds == [-600]
    end

    # Valid (non-positive) offsets need no processing at all: stored
    # as-is in original order, no default inserted.
    test "valid-only offsets are stored unchanged with no default", %{pid: pid} do
      apple_id = unique_apple_id("valid-only")
      sync_once(pid, [event_fixture(apple_id, [-3600, -60])])

      row = fetch_event(apple_id)
      refute is_nil(row)
      assert row.alarms_seconds == [-3600, -60]
    end

    # Offset 0 is valid user intent ("alarm at event start"): kept —
    # only positives are discarded.
    test "zero offset is a valid alarm and is kept", %{pid: pid} do
      apple_id = unique_apple_id("zero")
      sync_once(pid, [event_fixture(apple_id, [0, 300])])

      row = fetch_event(apple_id)
      refute is_nil(row)
      assert row.alarms_seconds == [0]
    end

    # The Swift port normally delivers a list of integers here, but a
    # stale port binary or protocol drift could deliver anything else. A
    # malformed payload must degrade to "no alarms" plus a debug note and
    # never crash the worker — a crash would abort the sync of every
    # remaining calendar and repeat on the next autosync tick.
    test "a non-list alarms_seconds payload stores [] without crashing the worker", %{pid: pid} do
      binary_id = unique_apple_id("non-list-binary")
      map_id = unique_apple_id("non-list-map")
      good_id = unique_apple_id("non-list-after")

      log =
        capture_log([level: :debug], fn ->
          sync_once(pid, [
            event_fixture(binary_id, "stale binary"),
            event_fixture(map_id, %{"drifted" => true}),
            event_fixture(good_id, [-600])
          ])
        end)

      # Both malformed events are still upserted — with no alarms.
      assert fetch_event(binary_id).alarms_seconds == []
      assert fetch_event(map_id).alarms_seconds == []

      # The loop continued past the bad payloads and the worker survived.
      assert fetch_event(good_id).alarms_seconds == [-600]
      assert log =~ "is not a list"
      assert log =~ ~s(got "stale binary")
      assert log =~ ~s(got %{"drifted" => true})
      assert Process.alive?(pid)
    end
  end

  describe "sync_calendar/2 cleaning log level" do
    # Discarding offsets and substituting defaults are routine data
    # bookkeeping, not sync progress: the messages must be visible at
    # :debug level...
    test "discard and substitution messages appear at debug level", %{pid: pid} do
      mixed_id = unique_apple_id("log-mixed")
      positive_id = unique_apple_id("log-positive")

      log =
        capture_log([level: :debug], fn ->
          sync_once(pid, [event_fixture(mixed_id, [-600, 300])])
          sync_once(pid, [event_fixture(positive_id, [300, 600])])
        end)

      assert log =~ "Discarded 1 positive alarm offset(s)"
      assert log =~ "Discarded 2 positive alarm offset(s)"
      assert log =~ "All alarm offsets positive"
      assert log =~ "substituted default alarm"
    end

    # ...and never at :info or above (an :info capture sees the sync
    # happen but no alarm cleaning messages).
    test "cleaning messages do not appear at info level", %{pid: pid} do
      positive_id = unique_apple_id("log-info")

      log =
        capture_log([level: :info], fn ->
          sync_once(pid, [event_fixture(positive_id, [300, 600])])
        end)

      # Sanity: the sync itself ran and was captured at :info.
      assert log =~ "Autosyncing Calendars"

      refute log =~ "positive alarm offset"
      refute log =~ "substituted default alarm"
    end
  end

  describe "sync_calendar/2 stale upsert rescue" do
    # Unchanged events (same last_modified + same cleaned alarms
    # re-synced) are rejected by the upsert condition and rescued by the
    # existing warning branch; that rescue must survive the cleaning
    # change unchanged.
    test "stale re-sync is rescued with the existing warning, row intact", %{pid: pid} do
      apple_id = unique_apple_id("stale")
      event = event_fixture(apple_id, [-600])

      sync_once(pid, [event])
      assert fetch_event(apple_id).alarms_seconds == [-600]

      log =
        capture_log(fn -> sync_once(pid, [event]) end)

      assert log =~ "Failed to create or update calendar event"

      row = fetch_event(apple_id)
      refute is_nil(row)
      assert row.alarms_seconds == [-600]
      assert Process.alive?(pid)
    end
  end
end
