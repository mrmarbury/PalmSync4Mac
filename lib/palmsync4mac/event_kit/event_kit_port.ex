defmodule PalmSync4Mac.EventKit.EventKitPort do
  @moduledoc """
  Port interface to query Mac EventKit for calendar events
  """
  def start do
    Port.open({:spawn, "./ports/ek_interface"}, [:binary, :exit_status, packet: 4])
  end

  # default is next 2 weeks
  def get_calendar_events(port, days \\ 13) do
    command = %{"command" => "get_events", "days" => days}
    message = Jason.encode!(command)
    Port.command(port, message)

    receive_response(port)
  end

  defp receive_response(port) do
    receive do
      {^port, {:data, response}} ->
        case Jason.decode(response) do
          # FIXME: We currently do not handle the response data. Remove ignore and inspect once we do something here
          # credo:disable-for-next-line
          {:ok, data} -> IO.inspect(data)
          {:error, _} -> IO.puts("Failed to decode response")
        end
    end
  end
end
