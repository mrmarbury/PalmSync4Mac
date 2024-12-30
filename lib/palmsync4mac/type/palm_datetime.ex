defmodule PalmSync4Mac.Type.PalmDatetime do
  @moduledoc """
  A custom Ash type for handling Palm datetime values.
  """

  use Ash.Type

  @impl Ash.Type
  def storage_type(_), do: :integer

  @palm_epoch ~N[1904-01-01 00:00:00]

  @doc """
  Cast input to a valid timestamp based on the palm epoch.

  Acceptable inputs:
  - `DateTime` structs (converted to seconds since the palm epoch)
  - `NaiveDateTime` structs (converted to seconds since the palm epoch)
  - Integers (assumed to already be seconds since the palm epoch)
  """
  @impl Ash.Type
  def cast(value) do
    case value do
      %DateTime{} ->
        {:ok, DateTime.diff(value, DateTime.from_naive!(@palm_epoch, "Etc/UTC"))}

      %NaiveDateTime{} ->
        {:ok,
         DateTime.diff(
           DateTime.from_naive!(value, "Etc/UTC"),
           DateTime.from_naive!(@palm_epoch, "Etc/UTC")
         )}

      timestamp when is_integer(timestamp) ->
        {:ok, timestamp}

      _ ->
        {:error, "#{inspect(value)} is not a valid timestamp"}
    end
  end

  @doc """
  Dump the value to be stored in the database.

  The dumped value will always be an integer representing seconds since the palm epoch.
  """
  @impl Ash.Type
  def dump(value) when is_integer(value), do: {:ok, value}

  def dump(value) do
    case cast(value) do
      {:ok, timestamp} -> {:ok, timestamp}
      error -> error
    end
  end

  @doc """
  Load the value from the database.

  Converts the stored integer back to a `DateTime` based on the palm epoch.
  """
  @impl Ash.Type
  def load(value) when is_integer(value) do
    {:ok, DateTime.add(DateTime.from_naive!(@palm_epoch, "Etc/UTC"), value, :second)}
  end

  def load(_), do: {:error, "Invalid data loaded from storage"}

  @doc """
  Describe the type, which helps with introspection.
  """
  @impl Ash.Type
  def describe, do: "A timestamp representing seconds since #{@palm_epoch}"
end
