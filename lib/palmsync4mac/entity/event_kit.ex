defmodule PalmSync4Mac.Entity.EventKit do
  @moduledoc """
    The PalmSync4Mac EventKit Entity domain
  """
  use Ash.Domain

  resources do
    resource(PalmSync4Mac.Entity.EventKit.CalendarEvent)
  end
end
