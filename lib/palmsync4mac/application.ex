defmodule PalmSync4Mac.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: PalmSync4Mac.Worker.start_link(arg)
      # {PalmSync4Mac.Worker, arg}
      PalmSync4Mac.Repo
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PalmSync4Mac.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
