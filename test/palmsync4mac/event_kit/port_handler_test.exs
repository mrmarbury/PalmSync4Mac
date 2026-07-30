defmodule PalmSync4Mac.EventKit.PortHandlerTest do
  use ExUnit.Case, async: false
  use Patch

  alias PalmSync4Mac.EventKit.PortHandler

  @moduletag :capture_log

  # Contract: PortHandler — E1 port exit

  describe "handle_info port exit (E1)" do
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

      # Sending an exit_status from a different port should not trigger :port_terminated.
      # The function should either not match (FunctionClauseError) or handle it gracefully.
      # After C1 fix, the guard `port == state.port` correctly matches only the owned port.
      assert_raise FunctionClauseError, fn ->
        PortHandler.handle_info({other_port, {:exit_status, 1}}, state)
      end
    end
  end
end
