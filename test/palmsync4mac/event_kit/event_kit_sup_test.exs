defmodule PalmSync4Mac.EventKit.EventKitSupTest do
  use ExUnit.Case, async: true

  alias PalmSync4Mac.EventKit.CalendarEventWorker

  describe "apple_calendar_names config" do
    test "returns a list of strings" do
      names = Application.fetch_env!(:palm_sync_4_mac, :apple_calendar_names)
      assert is_list(names)
      assert Enum.all?(names, &is_binary/1)
    end

    test "child spec passes calendar names as a flat list, not nested" do
      names = Application.fetch_env!(:palm_sync_4_mac, :apple_calendar_names)

      child_spec = {CalendarEventWorker, names}

      assert {CalendarEventWorker, ^names} = child_spec
      refute {CalendarEventWorker, [names]} == child_spec
    end
  end
end
