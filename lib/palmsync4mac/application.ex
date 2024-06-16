defmodule Palmsync4mac.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Palmsync4mac.Worker.start_link(arg)
      # {Palmsync4mac.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Palmsync4mac.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
