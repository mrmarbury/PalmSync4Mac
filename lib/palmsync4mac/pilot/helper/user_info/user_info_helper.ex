defmodule Palmsync4mac.Pilot.Helper.UserInfo.UserInfoHelper do
  @moduledoc """
  Contains all the utility methods used by the UserInfoWorker
  """

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

  def write_user_info(-1, _username), do: {:error, "Not connected to Palm device?"}

  def write_user_info(_client_sd, username) when is_blank(username),
    do: {:error, "Username cannot be empty"}

  def write_user_info(client_sd, username) do
    {:ok, user_info} =
      case(Pidlp.write_user_info(client_sd, Enum.at(user_info, 0))) do
        {:ok, _client_sd} -> Logger.info("Wrote User Info for user #{username}")
      end
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      reraise error, __STACKTRACE__
  end

  def write_to_db!(%PalmSync4Mac.Comms.Pidlp.PilotUser{} = user_info) do
    PalmSync4Mac.Entity.Device.PalmUser
    |> Ash.Changeset.new()
    |> Ash.Changeset.for_create(:create_or_update, user_info)
    |> Ash.create!()
  end

  def find_user_by_username(username) when is_not_blank(username) do
    PalmSync4Mac.Entity.Device.PalmUser
    |> Ash.Query.filter(:username === username)
    |> Ash.Query.limit(1)
    |> Ash.read!()
  end

  def update_username(user_info, username \\ nil) do
    user_info_name = user_info.username

    case {blank?(user_info_name), blank?(username)} do
      {false, false} -> %{user_info | username: username}
      {true, false} -> %{user_info | username: username}
      {false, true} -> user_info
      {true, true} -> %{user_info | username: generate_random_string()}
    end
  end
end
