defmodule PalmSync4Mac.MixProject do
  use Mix.Project

  def project do
    [
      app: :palmsync4mac,
      version: "0.1.0",
      elixir: "~> 1.18",
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
      {:usb, "~> 0.2.1"},
      # dev & test
      {:patch, "~> 0.12.0", only: [:test]},
      {:mox, "~> 1.2.0", only: [:test], runtime: false},
      {:ex_doc, "~> 0.36", only: [:test], runtime: false},
      # {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
