defmodule PalmSync4Mac.Pilot.SyncWorker.UserInfoWorkerTest do
  use ExUnit.Case, async: false

  use Patch

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Comms.Pidlp.PilotUser
  alias PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker
  alias PalmSync4Mac.Repo

  @moduletag :capture_log

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    {:ok, pid} =
      UserInfoWorker.start_link(%UserInfoWorker{
        client_sd: 42,
        user_info: %PilotUser{}
      })

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    on_exit(fn ->
      if Process.whereis(UserInfoWorker) do
        GenServer.stop(UserInfoWorker)
      end
    end)

    :ok
  end

  describe "pre_sync returns palm_user_id" do
    test "returns {:ok, palm_user_id} on success" do
      fake_user = %PilotUser{
        username: "test_user",
        password_length: 0,
        user_id: 12_345,
        viewer_id: 0,
        last_sync_pc: 0,
        last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
      }

      patch(Pidlp, :read_user_info, fn _sd ->
        {:ok, 42, fake_user}
      end)

      patch(Pidlp, :write_user_info, fn _sd, _ui ->
        {:ok, 42}
      end)

      result = UserInfoWorker.pre_sync()

      assert {:ok, palm_user_id} = result
      assert is_binary(palm_user_id)
      assert String.match?(palm_user_id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-/)
    end

    test "returns {:error, _} when read_user_info fails" do
      patch(Pidlp, :read_user_info, fn _sd ->
        {:error, 42, "connection lost"}
      end)

      result = UserInfoWorker.pre_sync()

      assert {:error, _} = result
    end

    test "generates random username when device returns empty" do
      fake_user = %PilotUser{
        username: "",
        password_length: 0,
        user_id: 12_345,
        viewer_id: 0,
        last_sync_pc: 0,
        last_sync_date: 0
      }

      patch(Pidlp, :read_user_info, fn _sd ->
        {:ok, 42, fake_user}
      end)

      patch(Pidlp, :write_user_info, fn _sd, _ui ->
        {:ok, 42}
      end)

      result = UserInfoWorker.pre_sync()

      assert {:ok, _palm_user_id} = result
    end

    test "calling pre_sync twice with same username returns same palm_user_id" do
      fake_user = %PilotUser{
        username: "stable_user",
        password_length: 0,
        user_id: 99_999,
        viewer_id: 0,
        last_sync_pc: 0,
        last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
      }

      patch(Pidlp, :read_user_info, fn _sd ->
        {:ok, 42, fake_user}
      end)

      patch(Pidlp, :write_user_info, fn _sd, _ui ->
        {:ok, 42}
      end)

      {:ok, first_id} = UserInfoWorker.pre_sync()
      {:ok, second_id} = UserInfoWorker.pre_sync()

      assert first_id == second_id
    end
  end

  describe "post_sync" do
    test "returns :ok on success" do
      fake_user = %PilotUser{
        username: "post_test_user",
        password_length: 0,
        user_id: 99_999,
        viewer_id: 0,
        last_sync_pc: 0,
        last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
      }

      patch(Pidlp, :read_user_info, fn _sd ->
        {:ok, 42, fake_user}
      end)

      patch(Pidlp, :write_user_info, fn _sd, _ui ->
        {:ok, 42}
      end)

      {:ok, _} = UserInfoWorker.pre_sync()
      result = UserInfoWorker.post_sync()

      assert result == :ok
    end
  end
end
