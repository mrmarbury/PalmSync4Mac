defmodule PalmSync4Mac.Pilot.Helper.UserInfo.UserInfoHelperTest do
  @moduledoc """
  Unit tests for the onboarding helpers (contract:
  docs/contracts/palm-identity-onboarding/contract-user-info-onboarding.md).

  These target the building blocks the UserInfoWorker state machine leans
  on: user_id provisioning (max+1, min 1), nameless detection,
  explicit-argument validation, and the exact-byte row lookup that keeps
  device identity stable.
  """

  use ExUnit.Case, async: false

  use Patch

  alias Ecto.Adapters.SQL.Sandbox
  alias PalmSync4Mac.Entity.Device.PalmUser
  alias PalmSync4Mac.Pilot.Helper.UserInfo.UserInfoHelper
  alias PalmSync4Mac.Repo

  import PalmSync4Mac.Pilot.Helper.UserInfo.UserInfoHelper

  @moduletag :capture_log

  # The onboarding helpers read and write palm_user rows, so each test needs
  # its own sandboxed database connection (and the roll-back isolation that
  # comes with it) — otherwise cross-test rows collide under the unique
  # indexes on username and user_id.
  setup do
    :ok = Sandbox.checkout(Repo)
    :ok
  end

  defp create_row(username, user_id) do
    PalmUser
    |> Ash.Changeset.for_create(:create_or_update, %{
      username: username,
      password_length: 0,
      password: "",
      user_id: user_id,
      viewer_id: 0,
      last_sync_pc: 0,
      last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
    })
    |> Ash.create()
  end

  describe "next_user_id/0" do
    test "an empty table provisions the first device with user_id 1" do
      assert {:ok, 1} = UserInfoHelper.next_user_id()
    end

    test "a populated table provisions max(existing user_id) + 1" do
      assert {:ok, _row_one} = create_row("device-one", 1)
      assert {:ok, _row_three} = create_row("device-two", 3)

      assert {:ok, 4} = UserInfoHelper.next_user_id()
    end

    test "rows at zero (bug-era leftovers) never pull the provisioned id below 1" do
      # Old syncs could mint rows with user_id 0; max(0 + 1, 1) must still
      # start identity numbering at a nonzero value.
      assert {:ok, _row_zero} = create_row("legacy-device", 0)

      assert {:ok, 1} = UserInfoHelper.next_user_id()
    end
  end

  describe "nameless?/1" do
    test "empty and whitespace-only names are nameless" do
      assert UserInfoHelper.nameless?("")
      assert UserInfoHelper.nameless?(" ")
      assert UserInfoHelper.nameless?("\t\n\r ")
      assert UserInfoHelper.nameless?(nil)
    end

    test "any real character makes a device named" do
      refute UserInfoHelper.nameless?("x")
      refute UserInfoHelper.nameless?(" x ")
      refute UserInfoHelper.nameless?("My TX")
    end
  end

  describe "validate_username/1" do
    test "nil (no argument) is valid — the random fallback covers it" do
      assert :ok = UserInfoHelper.validate_username(nil)
    end

    test "printable ASCII within 40 bytes is accepted" do
      assert :ok = UserInfoHelper.validate_username("My TX")
      assert :ok = UserInfoHelper.validate_username("a b-c_d.e!1")
      assert :ok = UserInfoHelper.validate_username(String.duplicate("x", 40))
    end

    test "empty, too long, non-ASCII, and control characters are rejected" do
      assert {:error, :username_invalid} = UserInfoHelper.validate_username("")

      assert {:error, :username_invalid} =
               UserInfoHelper.validate_username(String.duplicate("x", 41))

      assert {:error, :username_invalid} = UserInfoHelper.validate_username("naïve")
      assert {:error, :username_invalid} = UserInfoHelper.validate_username("bad\x01name")
      assert {:error, :username_invalid} = UserInfoHelper.validate_username(123)
    end

    test "whitespace-only names are rejected — they would fork the identity on the next sync" do
      # A whitespace name passes the byte-length and printable-ASCII gates,
      # but nameless?/1 (String.trim) counts it as blank again on the next
      # sync, so the device would be onboarded a second time under a
      # different random name and duplicate its row. The validation must
      # close that gap at the entry point.
      assert {:error, :username_invalid} = UserInfoHelper.validate_username(" ")
      assert {:error, :username_invalid} = UserInfoHelper.validate_username("\t")
      assert {:error, :username_invalid} = UserInfoHelper.validate_username(" \n\r\t ")
    end
  end

  describe "find_palm_user/1" do
    test "matches the device's name byte for byte — no trim, no case folding" do
      assert {:ok, %PalmUser{username: "My TX"}} = create_row("My TX", 1)

      assert {:ok, %PalmUser{}} = UserInfoHelper.find_palm_user("My TX")
      assert {:ok, nil} = UserInfoHelper.find_palm_user("my tx")
      assert {:ok, nil} = UserInfoHelper.find_palm_user("My TX ")
      assert {:ok, nil} = UserInfoHelper.find_palm_user(" My TX")
      assert {:ok, nil} = UserInfoHelper.find_palm_user("My-TX")
    end
  end

  describe "update_username/2" do
    test "a named device is never renamed, even with an explicit argument" do
      user_info = %PalmSync4Mac.Comms.Pidlp.PilotUser{
        username: "Palm TX",
        password: "",
        password_length: 0,
        user_id: 7,
        viewer_id: 0,
        last_sync_pc: 0,
        successful_sync_date: 0,
        last_sync_date: 0
      }

      assert ^user_info = UserInfoHelper.update_username(user_info, "My TX")

      # The explicit name is mandatory: there is no nil-argument fallback
      # clause anymore. The historical unchecked random-name branch here was
      # the pre-fix bug shape (an identity minted without a uniqueness
      # check), so a nil argument must be a loud programming error, not a
      # silently accepted identity.
      assert_raise FunctionClauseError, fn ->
        UserInfoHelper.update_username(user_info, nil)
      end
    end

    test "a nameless device takes the explicit argument as its new name" do
      user_info = %PalmSync4Mac.Comms.Pidlp.PilotUser{
        username: "",
        password: "",
        password_length: 0,
        user_id: 0,
        viewer_id: 0,
        last_sync_pc: 0,
        successful_sync_date: 0,
        last_sync_date: 0
      }

      assert %{username: "My TX"} = UserInfoHelper.update_username(user_info, "My TX")
    end

    test "a nameless device without an explicit name raises — no invented identity" do
      # No code path may invent a username: the name is permanent on Palm
      # hardware (established devices silently drop username writes), so
      # only the operator can choose it consciously. Reaching
      # update_username/2 without a name is a caller bug that must surface
      # instead of silently provisioning an identity.
      user_info = %PalmSync4Mac.Comms.Pidlp.PilotUser{
        username: "",
        password: "",
        password_length: 0,
        user_id: 0,
        viewer_id: 0,
        last_sync_pc: 0,
        successful_sync_date: 0,
        last_sync_date: 0
      }

      assert_raise FunctionClauseError, fn ->
        UserInfoHelper.update_username(user_info, nil)
      end
    end
  end

  describe "write_to_db/1" do
    test "persists a row and returns its id — never {:ok, nil}" do
      user_info = %PalmSync4Mac.Comms.Pidlp.PilotUser{
        username: "Write Db",
        password: "",
        password_length: 0,
        user_id: 9,
        viewer_id: 0,
        last_sync_pc: 0,
        successful_sync_date: 0,
        last_sync_date: DateTime.utc_now() |> DateTime.to_unix()
      }

      assert {:ok, palm_user_id} = UserInfoHelper.write_to_db(user_info)
      assert is_binary(palm_user_id)

      assert {:ok, %PalmUser{id: ^palm_user_id, username: "Write Db"}} =
               UserInfoHelper.find_palm_user("Write Db")
    end
  end
end
