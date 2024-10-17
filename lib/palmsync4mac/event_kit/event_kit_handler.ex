defmodule PalmSync4Mac.EventKit.EventKitHandler do
  @moduledoc """
  EventKit handler to query Mac EventKit for calendar events
  """
  use GenServer

  alias PalmSync4Mac.EventKit.EventKitPort

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__] ++ opts)
  end

  @spec get_calendar_events(integer) :: {:ok, list} | {:error, term}
  def get_calendar_events(days \\ 13) do
    GenServer.call(__MODULE__, {:get_calendar_events, days})
  end

  @impl true
  def init(_) do
    state = %{port: nil}

    {:ok, state, {:continue, :start_ek_interface}}
  end

  @impl true
  def handle_continue(:start_ek_interface, state) do
    port = EventKitPort.start()
    state = Map.put(state, :port, port)
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_calendar_events, days}, _from, state) do
    port = state.port
    events = EventKitPort.get_calendar_events(port, days)
    {:reply, events, state}
  end
end
