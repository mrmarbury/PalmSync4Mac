defmodule PalmSync4Mac.Pilot.SyncWorker.MainWorkerC4Test do
  @moduledoc """
  Contract 4 tests — MainWorker palm_user_id injection and pre_sync failure behavior.
  TDD: These tests define the contract invariants and error cases.
  """
  use ExUnit.Case, async: false
  use Patch

  alias PalmSync4Mac.Pilot.DynamicSup
  alias PalmSync4Mac.Pilot.SyncWorker.MainWorker
  alias PalmSync4Mac.Pilot.SyncWorker.MainWorker.PilotSyncRequest

  # Contract: MainWorker — palm_user_id injection invariants

  describe "inject_palm_user_id/3 — Contract: MainWorker — client_sd and palm_user_id injected as last two args" do
    test "client_sd and palm_user_id are appended as last two args" do
      mfas = [{SomeMod, :some_fun, [1, 2]}]
      result = MainWorker.inject_palm_user_id(mfas, 5, "test-uuid-1234")

      assert [{SomeMod, :some_fun, [1, 2, 5, "test-uuid-1234"]}] = result
    end

    test "inject_palm_user_id with empty queue returns empty list" do
      result = MainWorker.inject_palm_user_id([], 5, "test-uuid-1234")
      assert result == []
    end

    test "inject_palm_user_id with multiple MFAs appends to each" do
      mfas = [
        {ModA, :fun_a, [10]},
        {ModB, :fun_b, [20, 30]}
      ]

      result = MainWorker.inject_palm_user_id(mfas, 5, "uuid-abc")

      assert [
               {ModA, :fun_a, [10, 5, "uuid-abc"]},
               {ModB, :fun_b, [20, 30, 5, "uuid-abc"]}
             ] = result
    end

    test "inject_palm_user_id with MFA having empty args list" do
      mfas = [{SomeMod, :some_fun, []}]
      result = MainWorker.inject_palm_user_id(mfas, 5, "uuid-single")

      assert [{SomeMod, :some_fun, [5, "uuid-single"]}] = result
    end

    test "palm_user_id is always the LAST arg (after client_sd)" do
      mfas = [{Foo, :bar, [1]}]
      result = MainWorker.inject_palm_user_id(mfas, 42, "uuid-last")

      assert [{Foo, :bar, [1, 42, "uuid-last"]}] = result
    end
  end

  describe "handle_info(:sync, state) — Contract: MainWorker — pre_sync failure behavior" do
    setup do
      patch(PalmSync4Mac.Comms.Pidlp, :pilot_disconnect, fn _client_sd, _parent_sd ->
        {:ok, 5, 6}
      end)

      patch(DynamicSup, :which_children, fn -> [] end)
      patch(DynamicSup, :start_child, fn _child_spec -> {:ok, self()} end)

      :ok
    end

    test "skips sync_queue and runs post_sync when pre_sync fails" do
      defmodule C4.FailingPreSync do
        defstruct client_sd: -1

        def pre_sync(_client_sd) do
          send(Process.whereis(:c4_test_pid) || self(), :pre_sync_called)
          {:error, "user info failed"}
        end
      end

      defmodule C4.ShouldNotRunSync do
        defstruct client_sd: -1

        def sync(_client_sd, _palm_user_id) do
          send(Process.whereis(:c4_test_pid) || self(), :sync_should_not_run)
          :ok
        end
      end

      defmodule C4.PostSyncCleanup do
        defstruct client_sd: -1

        def post_sync do
          send(Process.whereis(:c4_test_pid) || self(), :post_sync_called)
          :ok
        end
      end

      Process.register(self(), :c4_test_pid)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        pre_sync_queue: [{C4.FailingPreSync, :pre_sync, []}],
        sync_queue: [{C4.ShouldNotRunSync, :sync, []}],
        post_sync_queue: [{C4.PostSyncCleanup, :post_sync, []}]
      }

      MainWorker.handle_info(:sync, state)

      assert_received :pre_sync_called
      assert_received :post_sync_called
      refute_received :sync_should_not_run

      Process.unregister(:c4_test_pid)
    end

    test "runs sync_queue with injected client_sd and palm_user_id when pre_sync succeeds" do
      defmodule C4.SuccessfulPreSync do
        defstruct client_sd: -1

        def pre_sync(_client_sd) do
          send(Process.whereis(:c4_test_pid2) || self(), :pre_sync_called)
          {:ok, "palm-user-uuid-123"}
        end
      end

      defmodule C4.SyncWithPalmUserId do
        defstruct client_sd: -1

        def sync(client_sd, palm_user_id) do
          send(
            Process.whereis(:c4_test_pid2) || self(),
            {:sync_called, client_sd, palm_user_id}
          )

          :ok
        end
      end

      defmodule C4.PostSyncAfterSuccess do
        defstruct client_sd: -1

        def post_sync do
          send(Process.whereis(:c4_test_pid2) || self(), :post_sync_called)
          :ok
        end
      end

      Process.register(self(), :c4_test_pid2)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        pre_sync_queue: [{C4.SuccessfulPreSync, :pre_sync, []}],
        sync_queue: [{C4.SyncWithPalmUserId, :sync, []}],
        post_sync_queue: [{C4.PostSyncAfterSuccess, :post_sync, []}]
      }

      MainWorker.handle_info(:sync, state)

      assert_received :pre_sync_called
      assert_received {:sync_called, 5, "palm-user-uuid-123"}
      assert_received :post_sync_called

      Process.unregister(:c4_test_pid2)
    end

    test "post_sync queue MFAs are NOT modified by palm_user_id injection" do
      defmodule C4.PreSyncForPost do
        defstruct client_sd: -1

        def pre_sync(_client_sd) do
          {:ok, "uuid-post-test"}
        end
      end

      defmodule C4.PostSyncNoPalmUserId do
        defstruct client_sd: -1

        def post_sync do
          send(Process.whereis(:c4_test_pid3) || self(), :post_sync_original_args)
          :ok
        end
      end

      Process.register(self(), :c4_test_pid3)

      state = %PilotSyncRequest{
        client_sd: 5,
        parent_sd: 6,
        pre_sync_queue: [{C4.PreSyncForPost, :pre_sync, []}],
        sync_queue: [],
        post_sync_queue: [{C4.PostSyncNoPalmUserId, :post_sync, []}]
      }

      MainWorker.handle_info(:sync, state)

      assert_received :post_sync_original_args

      Process.unregister(:c4_test_pid3)
    end
  end
end
