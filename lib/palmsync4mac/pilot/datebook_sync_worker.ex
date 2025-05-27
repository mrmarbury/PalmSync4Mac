defmodule Palmsync4mac.Pilot.DatebookSyncWorker do
  @moduledoc """
  Syncs Apple Calendar Events from the database to the Palm Pilot
  """
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:sync, _from, state) do
    {:reply, :ok, state}
  end
end
