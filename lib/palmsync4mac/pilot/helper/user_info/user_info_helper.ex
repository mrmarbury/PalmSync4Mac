defmodule PalmSync4Mac.Pilot.Helper.UserInfo.UserInfoHelper do
  @moduledoc """
  Contains all the utility methods used by the UserInfoWorker.
  read actions: reading from the Palm
  write actions: writing to the Palm
  """

  require Logger
  require Ash.Query

  alias PalmSync4Mac.Comms.Pidlp
  alias PalmSync4Mac.Entity.Device.PalmUser
  alias PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus
  alias PalmSync4Mac.Repo

  import PalmSync4Mac.Utils.StringUtils

  # The Palm wire format accepts usernames of at most 40 bytes, and only the
  # printable ASCII range 0x20..0x7E round-trips safely through the
  # ISO-8859-1 encoding the device uses. These bounds gate every name we
  # provision onto a device; generated names are 5-char [a-z0-9] and safe by
  # construction, but an operator can pass any explicit name via the sync
  # queue, so it must be checked before it ever reaches the wire.
  @max_username_length 40
  @printable_ascii_range 0x20..0x7E

  def read_user_info(-1), do: {:error, "Not connected to a Palm device?"}

  def read_user_info(client_sd) do
    case Pidlp.read_user_info(client_sd) do
      {:ok, _client_sd, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info} ->
        Logger.info("Read User Info: #{inspect(user_info)}")
        {:ok, user_info}

      {:error, _client_sd, message} ->
        Logger.error("Failed to read user info: #{message}")
        {:error, message}
    end
  end

  def write_user_info(-1, _user_info), do: {:error, "Not connected to Palm device?"}

  def write_user_info(client_sd, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    case(Pidlp.write_user_info(client_sd, user_info)) do
      {:ok, _client_sd} ->
        Logger.info("Wrote User Info for user #{user_info.username}")
        {:ok, user_info}

      {:error, _client_sd, message} ->
        Logger.error("Failed to write user info: #{message}")
        {:error, message}
    end
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      reraise error, __STACKTRACE__
  end

  @doc """
  Classifies a device username as nameless.

  A device counts as nameless when its username is empty or whitespace-only
  (`String.trim == ""`). This is deliberately the ONLY place where trimming
  is allowed: matching against existing rows is exact-byte (see
  `find_palm_user/1`), because two physical devices may legitimately differ
  by a single byte and normalization would silently merge them.
  """
  def nameless?(username), do: blank?(username)

  @doc """
  Validates an explicit username argument before it is provisioned onto a device.

  The Palm wire limit is 40 bytes and the device speaks ISO-8859-1; anything
  outside printable ASCII, an empty string, or a name longer than 40 bytes is
  rejected with `{:error, :username_invalid}` so the caller aborts before any
  row is created or any byte reaches the device.
  """
  def validate_username(username) when is_binary(username) do
    length_ok? = byte_size(username) in 1..@max_username_length
    printable_ascii? = Enum.all?(for(<<c <- username>>, do: c in @printable_ascii_range))

    if length_ok? and printable_ascii? do
      :ok
    else
      {:error, :username_invalid}
    end
  end

  # No argument at all is fine — the random fallback names the device — so
  # nil passes validation untouched; only a supplied name can be invalid.
  def validate_username(nil), do: :ok

  def validate_username(_), do: {:error, :username_invalid}

  @doc """
  Finds the palm_user row for a device username using exact byte comparison.

  Returns `{:ok, row}` when a row exists, `{:ok, nil}` when the name is
  unknown, or `{:error, reason}` when the lookup itself fails. No trimming,
  no case folding: the row key must equal the device's real name byte for
  byte, which is what makes the identity stable across sessions.
  """
  def find_palm_user(username) do
    PalmUser
    |> Ash.Query.filter(username == ^username)
    |> Ash.read()
    |> case do
      {:ok, [row]} ->
        {:ok, row}

      {:ok, []} ->
        {:ok, nil}

      {:ok, _multiple} ->
        # The unique index on username makes this unreachable in practice;
        # the explicit clause exists so a corrupted database surfaces as an
        # error instead of silently picking an arbitrary row.
        {:error, :username_ambiguous}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Mints the next Palm user_id: `max(existing user_id) + 1`, at least 1.

  The user_id is the integer the Palm device displays as its desktop-sync
  identity, so it is assigned here — database side — rather than taken from
  the device (a fresh or wiped device reads user_id 0, and two devices left
  at 0 would collide under the unique index). The read runs inside a
  transaction because SQLite serializes writers; the unique index on
  `palm_user.user_id` is the backstop if two onboardings still race to the
  same value: the second insert fails cleanly with `{:error, reason}` and
  the caller aborts before any byte reaches the device.
  """
  def next_user_id do
    Repo.transaction(fn ->
      PalmUser
      |> Ash.Query.sort(user_id: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read()
      |> case do
        {:ok, [%PalmUser{user_id: max_user_id} | _]} ->
          max(max_user_id + 1, 1)

        {:ok, []} ->
          1

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Generates a random fallback name that no palm_user row currently holds.

  The underlying generator produces 5-char [a-z0-9] strings (about 60
  million combinations), and this wrapper re-checks each candidate against
  the database and regenerates on a hit — a check-then-retry loop instead of
  hoping a collision never happens. The number of attempts is bounded so a
  broken database connection surfaces as an error rather than an infinite
  loop.
  """
  def generate_unique_name do
    generate_unique_name(0)
  end

  defp generate_unique_name(attempts) when attempts >= 100 do
    {:error, :unique_name_generation_failed}
  end

  defp generate_unique_name(attempts) do
    candidate = generate_random_string()

    case find_palm_user(candidate) do
      {:ok, nil} ->
        # No row holds this name, so it is safe to use as the device's new identity.
        {:ok, candidate}

      {:ok, _row} ->
        generate_unique_name(attempts + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Persists a new palm_user row (keyed by username) and returns its UUID.

  This is the row-creation half of onboarding: ONBOARD, ADOPT and the random
  fallback all funnel through here, upserting on username so a retry of a
  half-finished onboarding converges on the existing row instead of piling
  up duplicates. The StaleRecord fallback is the safety net for the
  eager-identity-check race: if the lookup that backs it cannot find the
  competing row, the call fails — it never returns `{:ok, nil}`, because a
  nil palm_user_id flowing into the sync workers is what historically turned
  one missing row into a full duplicate batch on the device.
  """
  def write_to_db(%PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    PalmUser
    |> Ash.Changeset.for_create(:create_or_update, Map.from_struct(user_info))
    |> Ash.create()
    |> case do
      {:ok, %PalmUser{id: palm_user_id}} ->
        {:ok, palm_user_id}

      {:error, %Ash.Error.Changes.StaleRecord{}} ->
        case find_palm_user(user_info.username) do
          {:ok, %PalmUser{id: palm_user_id}} ->
            {:ok, palm_user_id}

          {:ok, nil} ->
            {:error, :palm_user_row_missing}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a palm_user row, used to compensate a failed onboarding.

  ONBOARD creates the database row before writing to the device (so a failed
  device write can never leave the device permanently mutated with no row
  tracking it). When the device write then fails, the just-created row has
  to go again, otherwise the next attempt with the same explicit name would
  find a row claiming a name the device never took. Deletion failures are
  logged but do not mask the original `:device_write_failed` reason.
  """
  def delete_palm_user(palm_user_id) do
    case Ash.get(PalmUser, palm_user_id) do
      {:ok, row} ->
        Logger.info("Compensating failed onboarding: deleting palm_user row #{palm_user_id}")

        case Ash.destroy(row) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to delete compensating palm_user row: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error(
          "Could not load palm_user row #{palm_user_id} for compensation: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Updates only the sync/date fields of an existing palm_user row at the end
  of a session (post_sync).

  The row's identity — username and user_id — is authoritative and is
  re-read from the row itself before the upsert, so this call can never
  clobber a provisioned identity even if the device reports different
  values. Only the sync bookkeeping (sync dates and the desktop/PC fields
  the device tracks) follows the user info that was just written back to
  the device.
  """
  def update_sync_dates(palm_user_id, %PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    case Ash.get(PalmUser, palm_user_id) do
      {:ok, %PalmUser{} = row} ->
        attrs = %{
          username: row.username,
          user_id: row.user_id,
          password_length: row.password_length,
          password: row.password,
          viewer_id: user_info.viewer_id,
          last_sync_pc: user_info.last_sync_pc,
          successful_sync_date: user_info.successful_sync_date,
          last_sync_date: user_info.last_sync_date
        }

        PalmUser
        |> Ash.Changeset.for_create(:create_or_update, attrs)
        |> Ash.create()
        |> case do
          {:ok, %PalmUser{id: id}} -> {:ok, id}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        # A missing row here means the session's identity vanished mid-sync;
        # fail loudly instead of writing anything.
        {:error, reason}
    end
  end

  @doc """
  Deletes every ek_calendar_datebook_sync_status join row for a palm_user.

  RE_ONBOARD fires when a device that has lost its data (a hard reset, or a
  wipe) re-enters sync under a name we already know. The join rows still
  reference Palm record ids that no longer exist on the device, so keeping
  them would make every future sync think its work is done while the
  device's calendar stays empty. Resetting the joins makes the next sync a
  full, clean re-push. This runs only after the device accepted the
  identity write, so a failed write leaves all state untouched.
  """
  def reset_sync_status_rows(palm_user_id) do
    EkCalendarDatebookSyncStatus
    |> Ash.Query.filter(palm_user_id == ^palm_user_id)
    |> Ash.read()
    |> case do
      {:ok, rows} ->
        Logger.warning(
          "Re-onboarding palm_user #{palm_user_id}: deleting #{length(rows)} " <>
            "ek_calendar_datebook_sync_status join rows so the device gets a full clean re-push"
        )

        Enum.each(rows, &destroy_sync_status_row/1)

        :ok

      {:error, reason} ->
        Logger.error(
          "Re-onboarding palm_user #{palm_user_id}: join row reset skipped, " <>
            "sync status could not be read: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # A single join-row delete during a re-onboarding reset. Failures are logged
  # rather than raised so one stubborn row cannot abort the reset midway and
  # leave a half-reset bookkeeping table behind.
  defp destroy_sync_status_row(%EkCalendarDatebookSyncStatus{} = row) do
    case Ash.destroy(row) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to delete join row #{row.id} during re-onboarding: #{inspect(reason)}"
        )
    end
  end

  def update_username(%PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info, username \\ nil) do
    user_info_name = user_info.username

    cond do
      not nameless?(user_info_name) ->
        # A device that already carries a name is never renamed: Palm OS
        # hardware silently drops username writes on established devices,
        # and our row key must stay byte-identical to whatever the device
        # really reports. Any explicit argument is ignored here.
        user_info

      is_binary(username) ->
        # A nameless device being provisioned with an explicit name.
        %{user_info | username: username}

      true ->
        # A nameless device with no explicit name falls back to a generated
        # identity, unique-checked against existing rows.
        %{user_info | username: generate_random_string()}
    end
  end

  def update_last_sync_date(%PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    %{user_info | last_sync_date: DateTime.utc_now() |> DateTime.to_unix()}
  end

  def update_successful_sync_date(%PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    %{user_info | successful_sync_date: DateTime.utc_now() |> DateTime.to_unix()}
  end

  # This is always 0 for now. We can't send hostnames to the Palm and
  # this software is running on only one system for now anyway
  def update_last_sync_pc(%PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    hostname = 0
    %{user_info | last_sync_pc: hostname}
  end
end
