defmodule PalmSync4Mac.EventKit.PortHandlerTest do
  use ExUnit.Case, async: false
  use Patch

  alias PalmSync4Mac.EventKit.PortHandler

  @moduletag :capture_log

  # Port.open and Port.close are Erlang BIFs that Patch cannot intercept.
  # PortHandler wraps them in send_command/2 and close_port/1 (public functions)
  # which Patch CAN intercept. This allows unit testing without a real port.

  describe "handle_info port exit" do
    test "stops GenServer with :port_terminated when port exits" do
      fake_port = make_ref()
      state = %{port: fake_port, requests: %{}, request_id: 0}

      result = PortHandler.handle_info({fake_port, {:exit_status, 1}}, state)

      assert {:stop, :port_terminated, ^state} = result
    end

    test "does not match exit_status from a different port ref" do
      fake_port = make_ref()
      other_port = make_ref()
      state = %{port: fake_port, requests: %{}, request_id: 0}

      assert_raise FunctionClauseError, fn ->
        PortHandler.handle_info({other_port, {:exit_status, 1}}, state)
      end
    end
  end

  describe "handle_call get_calendar_events round-trip" do
    test "sends command to port and returns response via handle_info" do
      fake_port = make_ref()
      from = {self(), make_ref()}

      patch(PortHandler, :send_command, fn ^fake_port, _message -> true end)

      state0 = %{port: fake_port, requests: %{}, request_id: 0}

      {:noreply, state1} =
        PortHandler.handle_call({:get_calendar_events, 13, nil}, from, state0)

      assert state1.request_id == 1
      assert Map.has_key?(state1.requests, 1)

      response =
        Jason.encode!(%{
          "request_id" => 1,
          "events" => [%{"title" => "Meeting", "start_date" => "2026-01-01T10:00:00Z"}]
        })

      {:noreply, state2} =
        PortHandler.handle_info({fake_port, {:data, response}}, state1)

      assert state2.requests == %{}
    end
  end

  describe "handle_info malformed JSON" do
    test "drops response and preserves state when JSON decode fails" do
      fake_port = make_ref()
      from = {self(), make_ref()}
      state0 = %{port: fake_port, requests: %{1 => {from, make_ref()}}, request_id: 1}

      {:noreply, state1} =
        PortHandler.handle_info({fake_port, {:data, "not valid json"}}, state0)

      assert state1 == state0
    end
  end

  describe "handle_info missing request_id" do
    test "drops response and preserves state when request_id is absent" do
      fake_port = make_ref()
      from = {self(), make_ref()}
      state0 = %{port: fake_port, requests: %{1 => {from, make_ref()}}, request_id: 1}

      response = Jason.encode!(%{"events" => []})

      {:noreply, state1} =
        PortHandler.handle_info({fake_port, {:data, response}}, state0)

      assert state1 == state0
    end
  end

  describe "handle_info unknown request_id" do
    test "drops response when request_id not in requests map" do
      fake_port = make_ref()
      from = {self(), make_ref()}
      state0 = %{port: fake_port, requests: %{1 => {from, make_ref()}}, request_id: 1}

      response = Jason.encode!(%{"request_id" => 999, "events" => []})

      {:noreply, state1} =
        PortHandler.handle_info({fake_port, {:data, response}}, state0)

      assert state1 == state0
    end
  end

  describe "handle_info data from wrong port" do
    test "does not match data from a different port ref" do
      fake_port = make_ref()
      other_port = make_ref()
      state = %{port: fake_port, requests: %{}, request_id: 0}

      assert_raise FunctionClauseError, fn ->
        PortHandler.handle_info({other_port, {:data, "{}"}}, state)
      end
    end
  end

  describe "handle_info timeout" do
    test "replies {:error, :timeout} and removes request from map" do
      fake_port = make_ref()
      from = {self(), make_ref()}
      timer_ref = make_ref()

      state0 = %{port: fake_port, requests: %{1 => {from, timer_ref}}, request_id: 1}

      # Process.cancel_timer is a BIF that Patch cannot intercept, but it
      # returns false for non-existent timers, which is the correct behavior
      # for a fake timer_ref. GenServer.reply is patchable.
      patch(GenServer, :reply, fn
        ^from, {:error, :timeout} -> :ok
        ^from, {:ok, _} -> :ok
      end)

      {:noreply, state1} = PortHandler.handle_info({:timeout, 1}, state0)

      assert state1.requests == %{}
    end

    test "does nothing when timeout fires for unknown request_id" do
      fake_port = make_ref()
      state0 = %{port: fake_port, requests: %{}, request_id: 0}

      {:noreply, state1} = PortHandler.handle_info({:timeout, 999}, state0)

      assert state1 == state0
    end
  end

  describe "normalize_response_data" do
    test "adds source: :apple to each event and removes request_id" do
      data = %{
        "request_id" => 1,
        "events" => [
          %{"title" => "Meeting", "start_date" => "2026-01-01T10:00:00Z"},
          %{"title" => "Lunch", "start_date" => "2026-01-01T12:00:00Z"}
        ]
      }

      result = PortHandler.normalize_response_data(data)

      refute Map.has_key?(result, "request_id")
      assert length(result["events"]) == 2
      assert Enum.all?(result["events"], &(&1["source"] == :apple))
    end

    test "handles empty events list" do
      data = %{"request_id" => 42, "events" => []}

      result = PortHandler.normalize_response_data(data)

      refute Map.has_key?(result, "request_id")
      assert result["events"] == []
    end
  end

  describe "terminate/2" do
    test "closes the port on termination" do
      fake_port = make_ref()
      state = %{port: fake_port, requests: %{}, request_id: 0}

      patch(PortHandler, :close_port, fn ^fake_port -> true end)

      PortHandler.terminate(:shutdown, state)
    end
  end

  describe "request_id monotonic increment" do
    test "increments request_id across multiple handle_call invocations" do
      fake_port = make_ref()
      from1 = {self(), make_ref()}
      from2 = {self(), make_ref()}

      patch(PortHandler, :send_command, fn ^fake_port, _message -> true end)

      state0 = %{port: fake_port, requests: %{}, request_id: 0}

      {:noreply, state1} =
        PortHandler.handle_call({:get_calendar_events, 7, nil}, from1, state0)

      assert state1.request_id == 1

      {:noreply, state2} =
        PortHandler.handle_call({:get_calendar_events, 14, "Work"}, from2, state1)

      assert state2.request_id == 2
      assert Map.has_key?(state2.requests, 1)
      assert Map.has_key?(state2.requests, 2)
    end
  end

  describe "binary path config" do
    test "uses configured binary path when set" do
      custom_path = "/custom/path/to/binary"

      Application.put_env(:palm_sync_4_mac, :swift_port_binary, custom_path)

      assert PortHandler.resolve_binary_path() == custom_path
    after
      Application.delete_env(:palm_sync_4_mac, :swift_port_binary)
    end

    test "falls back to default path when not configured" do
      Application.delete_env(:palm_sync_4_mac, :swift_port_binary)

      assert PortHandler.resolve_binary_path() ==
               "./ports/.build/release/ek_calendar_interface"
    end
  end
end
