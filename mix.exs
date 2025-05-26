defmodule PalmSync4Mac.MixProject do
  use Mix.Project

  def project do
    [
      app: :palm_sync_4_mac,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      compilers: [:unifex, :bundlex] ++ Mix.compilers(),
      deps: deps(),

      # Docs
      name: "PalmSync4Mac",
      source_url: "https://github.com/mrmarbury/PalmSync4Mac",
      homepage_url: "https://github.com/mrmarbury/PalmSync4Mac",
      docs: &docs/0
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
      {:ash, "~> 3.5.12"},
      {:ash_sqlite, "~> 0.2"},
      {:ash_sql, "~> 0.2"},
      {:picosat_elixir, "~> 0.2"},
      {:jason, "~> 1.4"},
      {:usb, "~> 0.2"},
      {:simple_enum, "~> 0.1"},
      {:unifex, "~> 1.2"},
      {:timex, "~> 3.7"},
      {:typedstruct, "~> 0.5"},
      {:enum_type, "~> 1.1.0"},
      {:typed_struct_lens, "~> 0.1", runtime: false},
      {:typed_struct_nimble_options, "~> 0.1"},
      # dev & test
      {:patch, "~> 0.15", only: [:test]},
      {:mox, "~> 1.2", only: [:test], runtime: false},
      {:ex_doc, "~> 0.38", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "PalmSync4Mac",
      logo: "logo.png",
      extras: ["README.md"]
    ]
  end
end
