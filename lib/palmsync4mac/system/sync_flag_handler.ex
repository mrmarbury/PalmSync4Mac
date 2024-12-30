defmodule PalmSync4Mac.System.SyncFlagHandler do
  @moduledoc """
    Handles temporary sync flags in ets
  """
  use GenServer

  require Logger

  @table :sync_flags

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def lock_serial(serial) do
    GenServer.call(__MODULE__, {:lock_serial, serial})
  end

  def unlock_serial(serial) do
    GenServer.call(__MODULE__, {:unlock_serial, serial})
  end

  def sync_flag_table, do: @table

  @impl true
  def init(_) do
    {:ok, %{}, {:continue, :init_ets}}
  end

  @impl true
  def handle_continue(:init_ets, state) do
    :ets.new(@table, [:set, :protected, :named_table])
    {:noreply, state}
  end

  @impl true
  def handle_call({:lock_serial, serial}, _from, state) do
    case PalmSync4Mac.Utils.String.blank?(serial) do
      true -> {:reply, {:error, :blank}, state}
      false -> lock_or_fail(String.to_atom(serial), state)
    end
  end

  @impl true
  def handle_call({:unlock_serial, serial}, _from, state) do
    case PalmSync4Mac.Utils.String.blank?(serial) do
      true -> {:reply, {:ok, :blank}, state}
      _ -> {:reply, {:ok, :ets.delete(@table, String.to_atom(serial))}, state}
    end
  end

  defp lock_or_fail(serial, state) do
    case [{serial, :locked}] === :ets.lookup(@table, serial) do
      true -> {:reply, {:error, :locked}, state}
      _ -> {:reply, {:ok, :ets.insert(@table, {serial, :locked})}, state}
    end
  end
end
