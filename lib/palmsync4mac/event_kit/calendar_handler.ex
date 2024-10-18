defmodule PalmSync4Mac.EventKit.CalendarHandler do
  @moduledoc """
  Handle access to EK Calendar events.
  """
  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Fetches calendar events for the specified number of days.

  `days` is an integer representing the number of
      days to fetch events for, starting from today. Where 0 means today only.
  """
  def get_events(days \\ 13) do
    GenServer.call(__MODULE__, {:get_calendar_events, days})
  end

  @impl true
  def init(_opts) do
    port =
      Port.open({:spawn, "./ports/ek_calendar_interface"}, [:binary, :exit_status, packet: 4])

    state = %{
      port: port,
      requests: %{},
      request_id: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(
        {:get_calendar_events, days},
        from,
        %{port: port, requests: requests, request_id: request_id} = state
      ) do
    new_request_id = request_id + 1

    command = %{
      "command" => "get_events",
      "days" => days,
      "request_id" => new_request_id
    }

    message = Jason.encode!(command)

    Port.command(port, message)

    timer_ref = Process.send_after(self(), {:timeout, new_request_id}, 5_000)
    new_requests = Map.put(requests, new_request_id, {from, timer_ref})
    new_state = %{state | requests: new_requests, request_id: new_request_id}

    {:noreply, new_state}
  end

  @impl true
  def handle_info({port, {:data, response}}, state) when port == state.port do
    requests = state.requests

    with {:ok, data} <- Jason.decode(response),
         %{"request_id" => request_id} = response_data <- data,
         {from, timer_ref} <- Map.get(requests, request_id) do
      Process.cancel_timer(timer_ref)
      GenServer.reply(from, {:ok, Map.delete(response_data, "request_id")})

      new_requests = Map.delete(requests, request_id)

      {:noreply, %{state | requests: new_requests}}
    else
      {:error, _} ->
        # JSON decoding failed
        {:noreply, state}

      %{} ->
        # Response data does not contain "request_id"
        {:noreply, state}

      nil ->
        # No matching request found in the requests map
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, state) when port == state.port_ref do
    IO.puts("Port exited with status: #{status}")
    {:stop, :port_terminated, state}
  end

  @impl true
  def handle_info({:timeout, request_id}, state) do
    case Map.pop(state.requests, request_id) do
      {{from, _timer_ref}, new_requests} ->
        # Send timeout error to the caller
        GenServer.reply(from, {:error, :timeout})

        {:noreply, %{state | requests: new_requests}}

      {nil, _requests} ->
        # No matching request; do nothing
        {:noreply, state}
    end
  end
end
