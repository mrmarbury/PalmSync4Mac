defmodule PalmSync4Mac.Pilot.SyncWorker.UserInfoWorker do
  @moduledoc """
  Handles reading and writing of the PalmUserInfo during a sync.

  pre_sync classifies every connected Palm by its device username and runs
  the onboarding state machine (KNOWN / ADOPT / ONBOARD / RANDOM_FALLBACK /
  RE_ONBOARD, see the contract in docs/contracts/palm-identity-onboarding/)
  so each physical device maps to exactly one stable palm_user row. The
  returned palm_user_id is the only identity channel downstream workers get
  — before it existed, every sync minted a fresh random row and the whole
  calendar was re-pushed as duplicates.
  """

  use GenServer, restart: :transient

  require Logger

  import PalmSync4Mac.Pilot.Helper.UserInfo.UserInfoHelper

  alias PalmSync4Mac.Entity.Device.PalmUser

  defstruct client_sd: -1,
            user_info: %PalmSync4Mac.Comms.Pidlp.PilotUser{},
            username: nil,
            palm_user_id: nil,
            pre_sync_ok: false

  def start_link(worker_info \\ %__MODULE__{}) do
    GenServer.start_link(__MODULE__, worker_info, name: __MODULE__)
  end

  def pre_sync(username \\ nil) do
    GenServer.call(__MODULE__, {:pre_sync, username})
  end

  def post_sync do
    GenServer.call(__MODULE__, :post_sync)
  end

  @impl true
  def init(worker_info) do
    Logger.info("Started #{__MODULE__} for #{worker_info.client_sd}")
    {:ok, worker_info}
  end

  @impl true
  def handle_call({:pre_sync, username}, _from, state) do
    client_sd = state.client_sd
    Logger.info("Pre-sync: Reading user info for client_sd: #{client_sd}")

    # The device user info is read exactly once here; every classification
    # decision below works on that snapshot, and every device write carries
    # the username bytes derived from it, so the round-trip stays exact.
    with {:ok, user_info} <- read_user_info(client_sd),
         :ok <- validate_username(username),
         {:ok, palm_user_id, session_user_info} <- classify(client_sd, user_info, username) do
      {:reply, {:ok, palm_user_id},
       %{state | user_info: session_user_info, palm_user_id: palm_user_id, pre_sync_ok: true}}
    else
      {:error, message} ->
        Logger.error("Error Pre-Syncing User Info")

        # A failed pre_sync strips the session identity so the post_sync
        # guard below can never mistake a stale/blank user info for a valid
        # one and write garbage to the device or the database.
        {:reply, {:error, message}, %{state | palm_user_id: nil, pre_sync_ok: false}}
    end
  end

  @impl true
  def handle_call(:post_sync, _from, state) do
    client_sd = state.client_sd

    if state.pre_sync_ok do
      Logger.info(
        "Post-sync: Writing updated user info to the device with client_sd: #{client_sd}"
      )

      # The struct written back is the one that survived pre_sync: it either
      # is the device's own read-back state (KNOWN) or the identity we
      # provisioned onto it, so the username bytes always round-trip exactly
      # what the device currently holds.
      with with_sync_dates <- update_last_sync_date(state.user_info),
           with_successful_sync_date <- update_successful_sync_date(with_sync_dates),
           {:ok, _user_info} <- write_user_info(client_sd, with_successful_sync_date),
           {:ok, _palm_user_id} <-
             update_sync_dates(state.palm_user_id, with_successful_sync_date) do
        {:reply, :ok, %{state | user_info: with_successful_sync_date}}
      else
        {:error, message} ->
          Logger.error("Error Post-Syncing User Info: #{message}")
          {:reply, {:error, message}, state}
      end
    else
      # Invariant: post_sync performs zero device writes and zero database
      # writes unless pre_sync succeeded in this same session. A post_sync
      # after a failed pre_sync would upsert the default (blank) PilotUser —
      # writing an empty username to the device and potentially resurrecting
      # a row that the ONBOARD compensation just deleted.
      Logger.warning("Post-sync skipped: pre-sync did not complete for this session")

      {:reply, {:error, :pre_sync_not_completed}, state}
    end
  end

  # Classification runs on the device's own username: a device that already
  # carries a name is matched against the database byte for byte, a nameless
  # device is provisioned with the explicit argument or a generated fallback
  # name. Palm hardware silently drops username writes on established
  # devices, so a named device must keep exactly the name it reports — the
  # row key and the device can never be allowed to diverge.
  defp classify(client_sd, user_info, username) do
    if nameless?(user_info.username) do
      classify_nameless(client_sd, user_info, username)
    else
      known_or_adopt(client_sd, user_info)
    end
  end

  # KNOWN: the device's name matches an existing row — the happy path. No
  # identity writes go to the device; a user_id mismatch only warns, because
  # a foreign tool may have rewritten the device's integer (proven on the
  # wire) and the name remains the authoritative identity either way. Two
  # physical devices genuinely sharing one name is a documented gap left
  # for the UI round.
  defp known_or_adopt(client_sd, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    case find_palm_user(user_info.username) do
      {:ok, %PalmUser{id: palm_user_id, user_id: row_user_id}} ->
        if row_user_id != user_info.user_id do
          Logger.warning(
            "Device '#{user_info.username}' reports user_id #{user_info.user_id} but our " <>
              "row holds #{row_user_id}. The name wins as identity; if this is not the " <>
              "same physical device, its data may cross-contaminate this row."
          )
        end

        {:ok, palm_user_id, user_info}

      {:ok, nil} ->
        adopt(client_sd, user_info)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ADOPT: a named device we have never seen. The device's own name becomes
  # the row key (it can never be renamed), and a fresh user_id is minted
  # database-side. The user_id write to the device is best-effort: Palm OS
  # accepts the integer on every device tested, but if it is dropped the
  # sync still continues because the identity is the name.
  defp adopt(client_sd, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    with {:ok, next_id} <- next_user_id(),
         provisioned = %{user_info | user_id: next_id},
         with_dates = update_last_sync_date(update_last_sync_pc(provisioned)),
         {:ok, palm_user_id} <- write_to_db(with_dates) do
      case write_user_info(client_sd, with_dates) do
        {:ok, _user_info} ->
          {:ok, palm_user_id, with_dates}

        {:error, message} ->
          Logger.warning(
            "Could not write provisioned user_id #{next_id} to device " <>
              "'#{user_info.username}' (#{message}). Identity is the device name; " <>
              "continuing the sync."
          )

          {:ok, palm_user_id, provisioned}
      end
    end
  end

  # A nameless device: either the explicit argument decides its new name
  # (RE_ONBOARD when a row already holds it, ONBOARD otherwise) or, with no
  # argument, a random fallback name is generated.
  defp classify_nameless(client_sd, user_info, nil) do
    with {:ok, name} <- generate_unique_name() do
      onboard(client_sd, user_info, name)
    end
  end

  defp classify_nameless(client_sd, user_info, username) do
    case find_palm_user(username) do
      {:ok, %PalmUser{} = row} ->
        re_onboard(client_sd, user_info, row)

      {:ok, nil} ->
        onboard(client_sd, user_info, username)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ONBOARD: the database row is created FIRST and the device is written
  # second, so a failed device write can never leave hardware permanently
  # mutated with no row tracking it. If the device refuses the write, the
  # just-created row is deleted again (compensating delete) and the sync
  # aborts. The loops close by themselves: if the device actually took the
  # write despite the error report, the next sync finds a named device and
  # takes the ADOPT path; if it did not, retrying with the same name simply
  # reuses the (deleted) slot cleanly.
  defp onboard(client_sd, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info, name) do
    with {:ok, next_id} <- next_user_id(),
         provisioned = update_username(user_info, name) |> Map.put(:user_id, next_id),
         with_dates = update_last_sync_date(update_last_sync_pc(provisioned)),
         {:ok, palm_user_id} <- write_to_db(with_dates) do
      case write_user_info(client_sd, with_dates) do
        {:ok, _user_info} ->
          {:ok, palm_user_id, with_dates}

        {:error, _message} ->
          Logger.error(
            "Onboarding '#{name}' failed: the device did not accept the identity " <>
              "write. Deleting the provisioned row so the retry starts clean."
          )

          _ = delete_palm_user(palm_user_id)
          {:error, :device_write_failed}
      end
    end
  end

  # RE_ONBOARD: a nameless device asking for a name our row already holds —
  # typically a known device that was hard-reset or wiped. Here the DEVICE is
  # written first: the row and its join rows are still valid until the
  # device accepts the identity, so a failed write leaves everything
  # untouched. Only after a successful write do the join rows get reset —
  # they reference Palm record ids that no longer exist on the wiped
  # device, and keeping them would make every later sync believe its work
  # is done while the device's calendar stays empty.
  defp re_onboard(client_sd, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info, %PalmUser{} = row) do
    provisioned =
      update_username(user_info, row.username)
      |> Map.put(:user_id, row.user_id)

    with_dates = update_last_sync_date(update_last_sync_pc(provisioned))

    case write_user_info(client_sd, with_dates) do
      {:ok, _user_info} ->
        case reset_sync_status_rows(row.id) do
          :ok ->
            {:ok, row.id, with_dates}

          {:error, reason} ->
            # The device accepted the identity, so the join reset failure
            # only means stale bookkeeping survives; surface the error and
            # let the operator retry rather than silently corrupting the
            # device view of what is synced.
            {:error, reason}
        end

      {:error, _message} ->
        {:error, :device_write_failed}
    end
  end
end
