defmodule PalmSync4Mac.MixProject do
  use Mix.Project

  def project do
    [
      app: :palmsync4mac,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools, :observer, :wx],
      mod: {PalmSync4Mac.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_sqlite, "~> 0.1.3"},
      {:picosat_elixir, "~> 0.2"},
      {:jason, "~> 1.4.1"},
      # dev & test
      {:patch, "~> 0.12.0", only: [:test]},
      # {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
