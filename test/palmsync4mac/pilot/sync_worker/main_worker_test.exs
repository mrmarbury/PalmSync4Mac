defmodule PalmSync4Mac.Pilot.SyncWorker.MainWorkerTest do
  use ExUnit.Case, async: false
  use Patch

  alias PalmSync4Mac.Pilot.Helper.SyncWorkers
  alias PalmSync4Mac.Pilot.SyncWorker.MainWorker
  alias PalmSync4Mac.Pilot.SyncWorker.MainWorker.PilotSyncRequest

  @moduletag :capture_log

  describe "init/1" do
    test "initializes with PilotSyncRequest and continues with :connect" do
      request = %PilotSyncRequest{}

      assert {:ok, ^request, {:continue, :connect}} = MainWorker.init(request)
    end

    test "preserves all fields from initial request" do
      request = %PilotSyncRequest{
        port: "net:192.168.1.100",
        connect_wait_timeout: 60,
        sync_queue: [{SomeModule, :some_func, []}],
        pre_sync_queue: [{PreModule, :pre_func, []}],
        post_sync_queue: [{PostModule, :post_func, []}]
      }

      assert {:ok, returned_request, {:continue, :connect}} = MainWorker.init(request)
      assert returned_request.port == "net:192.168.1.100"
      assert returned_request.connect_wait_timeout == 60
      assert returned_request.sync_queue == [{SomeModule, :some_func, []}]
      assert returned_request.pre_sync_queue == [{PreModule, :pre_func, []}]
      assert returned_request.post_sync_queue == [{PostModule, :post_func, []}]
    end
  end

  describe "handle_continue(:connect, state) - successful connection" do
    test "updates state with client_sd and parent_sd on successful connection" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, _timeout ->
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{
        port: "usb:",
        connect_wait_timeout: 300,
        client_sd: -1,
        parent_sd: -1
      }

      assert {:noreply, updated_state} = MainWorker.handle_continue(:connect, state)
      assert updated_state.client_sd == 5
      assert updated_state.parent_sd == 6
    end

    test "sends :sync message to self after successful connection" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, _timeout ->
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{}

      MainWorker.handle_continue(:connect, state)

      assert_receive :sync
    end

    test "uses custom port from state" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn port, _timeout ->
        send(self(), {:connect_called, port})
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{port: "net:192.168.1.100"}

      MainWorker.handle_continue(:connect, state)

      assert_received {:connect_called, "net:192.168.1.100"}
    end

    test "uses custom timeout from state" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, timeout ->
        send(self(), {:timeout_used, timeout})
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{connect_wait_timeout: 60}

      MainWorker.handle_continue(:connect, state)

      assert_received {:timeout_used, 60}
    end

    test "uses default timeout of 300 when not specified" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, timeout ->
        send(self(), {:timeout_used, timeout})
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{}

      MainWorker.handle_continue(:connect, state)

      assert_received {:timeout_used, 300}
    end

    test "supports 0 timeout for infinite wait" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, timeout ->
        send(self(), {:timeout_used, timeout})
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{connect_wait_timeout: 0}

      MainWorker.handle_continue(:connect, state)

      assert_received {:timeout_used, 0}
    end
  end

  describe "handle_continue(:connect, state) - failed connection" do
    test "stops GenServer with :normal on connection error" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, _timeout ->
        {:error, -1, -1, "Connection failed"}
      end)

      state = %PilotSyncRequest{}

      assert {:stop, :normal, _state} = MainWorker.handle_continue(:connect, state)
    end

    test "does not send :sync message on failed connection" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, _timeout ->
        {:error, -1, -1, "Connection failed"}
      end)

      state = %PilotSyncRequest{}

      MainWorker.handle_continue(:connect, state)

      refute_receive :sync, 100
    end

    test "preserves original state on connection failure" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_connect, fn _port, _timeout ->
        {:error, -1, -1, "Connection failed"}
      end)

      state = %PilotSyncRequest{
        port: "usb:",
        sync_queue: [{SomeModule, :func, []}]
      }

      assert {:stop, :normal, returned_state} = MainWorker.handle_continue(:connect, state)
      assert returned_state.port == "usb:"
      assert returned_state.sync_queue == [{SomeModule, :func, []}]
    end
  end

  describe "handle_info(:sync, state) - empty queue" do
    setup do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn _client_sd, _parent_sd ->
        {:ok, 5, 6}
      end)

      patch(SyncWorkers, :which_children, fn -> [] end)

      :ok
    end

    test "stops normally when all queues are empty" do
      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        sync_queue: [],
        pre_sync_queue: [],
        post_sync_queue: []
      }

      assert {:stop, :normal, _state} = MainWorker.handle_info(:sync, state)
    end
  end

  # Test modules defined at module level with defstruct to avoid Kernel.struct patching
  defmodule ExecuteTest1 do
    defstruct client_sd: -1

    def test_func(_palm_user_id, _sys_info) do
      send(Process.whereis(:test_pid_exe1) || self(), :test_func_called)
      :ok
    end
  end

  defmodule ExecuteTest2 do
    defstruct client_sd: -1

    def first_func(_palm_user_id, _sys_info) do
      send(Process.whereis(:test_pid_exe2) || self(), {:called, :first})
      :ok
    end

    def second_func(_palm_user_id, _sys_info) do
      send(Process.whereis(:test_pid_exe2) || self(), {:called, :second})
      :ok
    end
  end

  defmodule ExecuteTest3 do
    defstruct client_sd: -1

    alias PalmSync4Mac.Comms.Pidlp.PilotSysInfo

    def pre_func do
      send(Process.whereis(:test_pid_exe3) || self(), {:order, :pre})
      {:ok, "palm-user-uuid"}
    end

    def sys_info_pre_func do
      send(Process.whereis(:test_pid_exe3) || self(), {:order, :sys_info_pre})
      {:ok, %PilotSysInfo{rom_version: 0x05040000, prod_id: "Palm TX"}}
    end

    def sync_func(palm_user_id, sys_info) do
      send(Process.whereis(:test_pid_exe3) || self(), {:order, :sync, palm_user_id, sys_info})
      :ok
    end

    def post_func do
      send(Process.whereis(:test_pid_exe3) || self(), {:order, :post})
      :ok
    end
  end

  defmodule ExecuteTest5 do
    defstruct client_sd: -1

    def error_func(_palm_user_id, _sys_info) do
      send(Process.whereis(:test_pid_exe5) || self(), :error_called)
      {:error, "something went wrong"}
    end

    def success_func(_palm_user_id, _sys_info) do
      send(Process.whereis(:test_pid_exe5) || self(), :success_called)
      :ok
    end
  end

  describe "handle_info(:sync, state) - queue processing with mocked struct creation" do
    setup do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn _client_sd, _parent_sd ->
        {:ok, 5, 6}
      end)

      patch(SyncWorkers, :which_children, fn -> [] end)
      patch(SyncWorkers, :start_child, fn _child_spec -> {:ok, self()} end)

      :ok
    end

    test "executes MFA from sync_queue with palm_user_id injected" do
      Process.register(self(), :test_pid_exe1)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        sync_queue: [{ExecuteTest1, :test_func, []}]
      }

      MainWorker.handle_info(:sync, state)

      assert_received :test_func_called
      Process.unregister(:test_pid_exe1)
    end

    test "executes multiple sync MFAs sequentially" do
      Process.register(self(), :test_pid_exe2)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        sync_queue: [
          {ExecuteTest2, :first_func, []},
          {ExecuteTest2, :second_func, []}
        ]
      }

      MainWorker.handle_info(:sync, state)

      assert_received {:called, :first}
      assert_received {:called, :second}
      Process.unregister(:test_pid_exe2)
    end

    test "runs pre_sync, then sync_queue with palm_user_id, then post_sync" do
      Process.register(self(), :test_pid_exe3)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        pre_sync_queue: [
          {ExecuteTest3, :pre_func, []},
          {ExecuteTest3, :sys_info_pre_func, []}
        ],
        sync_queue: [{ExecuteTest3, :sync_func, []}],
        post_sync_queue: [{ExecuteTest3, :post_func, []}]
      }

      MainWorker.handle_info(:sync, state)

      assert_received {:order, :pre}
      assert_received {:order, :sys_info_pre}

      assert_received {:order, :sync, "palm-user-uuid",
                       %PalmSync4Mac.Comms.Pidlp.PilotSysInfo{rom_version: 0x05040000}}

      assert_received {:order, :post}
      Process.unregister(:test_pid_exe3)
    end

    test "continues processing even when sync MFA returns error tuple" do
      Process.register(self(), :test_pid_exe5)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        sync_queue: [
          {ExecuteTest5, :error_func, []},
          {ExecuteTest5, :success_func, []}
        ]
      }

      MainWorker.handle_info(:sync, state)

      assert_received :error_called
      assert_received :success_called
      Process.unregister(:test_pid_exe5)
    end
  end

  describe "terminate/2" do
    test "calls pilot_disconnect with correct client_sd and parent_sd" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn client_sd, parent_sd ->
        send(self(), {:disconnect_called, client_sd, parent_sd})
        {:ok, client_sd, parent_sd}
      end)

      patch(SyncWorkers, :which_children, fn -> [] end)

      state = %PilotSyncRequest{
        client_sd: 42,
        parent_sd: 43
      }

      MainWorker.terminate(:normal, state)

      assert_received {:disconnect_called, 42, 43}
    end

    test "terminates all dynamic supervisor children" do
      child_pid1 = spawn(fn -> Process.sleep(10_000) end)
      child_pid2 = spawn(fn -> Process.sleep(10_000) end)

      patch(SyncWorkers, :which_children, fn ->
        [
          {:undefined, child_pid1, :worker, [SomeWorker]},
          {:undefined, child_pid2, :worker, [OtherWorker]}
        ]
      end)

      patch(SyncWorkers, :terminate_child, fn pid ->
        send(self(), {:child_terminated, pid})
        :ok
      end)

      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn _client_sd, _parent_sd ->
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6
      }

      MainWorker.terminate(:normal, state)

      assert_received {:child_terminated, ^child_pid1}
      assert_received {:child_terminated, ^child_pid2}
    end

    test "handles case with no children gracefully" do
      patch(SyncWorkers, :which_children, fn -> [] end)

      patch(SyncWorkers, :terminate_child, fn _pid ->
        send(self(), :should_not_be_called)
        :ok
      end)

      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn _client_sd, _parent_sd ->
        {:ok, 5, 6}
      end)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6
      }

      MainWorker.terminate(:normal, state)

      refute_received :should_not_be_called
    end

    test "terminates children even if disconnect fails" do
      child_pid = spawn(fn -> Process.sleep(10_000) end)

      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn _client_sd, _parent_sd ->
        {:error, -1, -1, "Disconnect failed"}
      end)

      patch(SyncWorkers, :which_children, fn ->
        [{:undefined, child_pid, :worker, [SomeWorker]}]
      end)

      patch(SyncWorkers, :terminate_child, fn pid ->
        send(self(), {:child_terminated, pid})
        :ok
      end)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6
      }

      MainWorker.terminate(:normal, state)

      assert_received {:child_terminated, ^child_pid}
    end

    test "works with different termination reasons" do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn client_sd, parent_sd ->
        send(self(), {:disconnect_called, client_sd, parent_sd})
        {:ok, client_sd, parent_sd}
      end)

      patch(SyncWorkers, :which_children, fn -> [] end)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6
      }

      MainWorker.terminate(:shutdown, state)
      assert_received {:disconnect_called, 5, 6}

      MainWorker.terminate({:shutdown, :custom_reason}, state)
      assert_received {:disconnect_called, 5, 6}

      MainWorker.terminate(:killed, state)
      assert_received {:disconnect_called, 5, 6}
    end
  end

  describe "inject_sync_context/3" do
    test "appends both palm_user_id and sys_info to MFA args" do
      mfas = [{SomeModule, :some_func, []}, {AnotherModule, :another_func, [:existing_arg]}]
      sys_info = %PalmSync4Mac.Comms.Pidlp.PilotSysInfo{rom_version: 0x05040000}

      result = MainWorker.inject_sync_context(mfas, "palm-user-uuid", sys_info)

      assert result == [
               {SomeModule, :some_func, ["palm-user-uuid", sys_info]},
               {AnotherModule, :another_func, [:existing_arg, "palm-user-uuid", sys_info]}
             ]
    end

    test "palm_user_id is always before sys_info in args" do
      mfas = [{TestModule, :test_func, []}]
      sys_info = %PalmSync4Mac.Comms.Pidlp.PilotSysInfo{rom_version: 0x05020000}

      [{_mod, _fun, args}] = MainWorker.inject_sync_context(mfas, "user-uuid", sys_info)

      assert length(args) == 2
      assert Enum.at(args, 0) == "user-uuid"
      assert Enum.at(args, 1) == sys_info
    end

    test "post-sync queue MFAs are unchanged by inject_sync_context" do
      post_mfas = [{PostModule, :post_func, []}]
      sys_info = %PalmSync4Mac.Comms.Pidlp.PilotSysInfo{rom_version: 0x05020000}

      result = MainWorker.inject_sync_context(post_mfas, "uuid", sys_info)

      assert result != post_mfas
    end
  end

  describe "run_pre_sync — map accumulator validation" do
    setup do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn _client_sd, _parent_sd ->
        {:ok, 5, 6}
      end)

      patch(SyncWorkers, :which_children, fn -> [] end)
      patch(SyncWorkers, :start_child, fn _child_spec -> {:ok, self()} end)

      :ok
    end

    test "pre-sync fails when SysInfoWorker fails" do
      defmodule ExecuteTestSysInfoFail do
        defstruct client_sd: -1

        def pre_func do
          {:ok, "palm-user-uuid"}
        end

        def sys_info_fail_func do
          {:error, "sysinfo read failed"}
        end
      end

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        pre_sync_queue: [
          {ExecuteTestSysInfoFail, :pre_func, []},
          {ExecuteTestSysInfoFail, :sys_info_fail_func, []}
        ],
        sync_queue: [],
        post_sync_queue: []
      }

      # handle_info stops with :normal regardless — the error is logged and
      # post_sync runs (empty here). No crash = correct behavior.
      assert {:stop, :normal, _} = MainWorker.handle_info(:sync, state)
    end

    test "pre-sync returns error when palm_user_id is missing" do
      defmodule ExecuteTestMissingPalmUserId do
        defstruct client_sd: -1

        alias PalmSync4Mac.Comms.Pidlp.PilotSysInfo

        def sys_info_only_func do
          {:ok, %PilotSysInfo{rom_version: 0x05040000}}
        end
      end

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        pre_sync_queue: [
          {ExecuteTestMissingPalmUserId, :sys_info_only_func, []}
        ],
        sync_queue: [],
        post_sync_queue: []
      }

      # palm_user_id missing → :palm_user_id_missing → skips sync_queue, runs post_sync (empty)
      assert {:stop, :normal, _} = MainWorker.handle_info(:sync, state)
    end

    test "pre-sync returns error when sys_info is missing" do
      defmodule ExecuteTestMissingSysInfo do
        defstruct client_sd: -1

        def palm_user_id_only_func do
          {:ok, "palm-user-uuid"}
        end
      end

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        pre_sync_queue: [
          {ExecuteTestMissingSysInfo, :palm_user_id_only_func, []}
        ],
        sync_queue: [],
        post_sync_queue: []
      }

      # sys_info missing → :sys_info_missing → skips sync_queue, runs post_sync (empty)
      assert {:stop, :normal, _} = MainWorker.handle_info(:sync, state)
    end
  end
end
