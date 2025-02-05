defmodule PalmSync4Mac.Type.PalmDatetime do
  @moduledoc """
  A custom Ash type for handling Palm datetime values.

  Converts between a UTC DateTime (in memory) and an integer representing
  the number of seconds since the Palm epoch (1904-01-01 00:00:00 UTC).
  """

  use Ash.Type

  # Define the Palm epoch as a naive datetime and as a UTC DateTime.
  @palm_epoch_naive ~N[1904-01-01 00:00:00]
  @palm_epoch DateTime.from_naive!(@palm_epoch_naive, "Etc/UTC")

  @impl Ash.Type
  def storage_type(_), do: :integer

  # When casting input (for example, when a user supplies a value),
  # accept nil, integers (seconds since epoch), DateTime, or NaiveDateTime.
  @impl Ash.Type
  def cast_input(nil, _), do: {:ok, nil}

  def cast_input(value, _) when is_integer(value) do
    # Assume the integer represents seconds since the Palm epoch.
    {:ok, DateTime.add(@palm_epoch, value, :second)}
  end

  def cast_input(%DateTime{} = dt, _) do
    {:ok, dt}
  end

  def cast_input(%NaiveDateTime{} = ndt, _) do
    {:ok, DateTime.from_naive!(ndt, "Etc/UTC")}
  end

  def cast_input(_value, _) do
    {:error, "Invalid value for PalmDatetime. Expected an integer, DateTime, or NaiveDateTime."}
  end

  # When casting stored values (from the database), we expect an integer.
  @impl Ash.Type
  def cast_stored(nil, _), do: {:ok, nil}

  def cast_stored(value, _) when is_integer(value) do
    {:ok, DateTime.add(@palm_epoch, value, :second)}
  end

  def cast_stored(_value, _) do
    {:error, "Invalid stored value for PalmDatetime. Expected an integer."}
  end

  # When dumping the in-memory value to the native (database) format,
  # convert the UTC DateTime into seconds since the Palm epoch.
  @impl Ash.Type
  def dump_to_native(nil, _), do: {:ok, nil}

  def dump_to_native(%DateTime{} = dt, _) do
    seconds = DateTime.diff(dt, @palm_epoch)
    {:ok, seconds}
  end

  # If an integer is somehow passed in (already representing seconds),
  # assume it’s already in the correct format.
  def dump_to_native(value, _) when is_integer(value) do
    {:ok, value}
  end

  def dump_to_native(_value, _) do
    {:error, "Invalid value for dumping PalmDatetime."}
  end

  def describe, do: "A Palm datetime stored as seconds since #{@palm_epoch_naive}"
end
