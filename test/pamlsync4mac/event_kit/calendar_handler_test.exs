defmodule PalmSync4Mac.EventKit.CalendarHandlerTest do
  use ExUnit.Case, async: true

  test "" do
    start_supervised(PalmSync4Mac.EventKit.CalendarHandler)
  end
end
