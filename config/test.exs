import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :palm_sync_4_mac, PalmSync4Mac.Repo,
  database: Path.join(__DIR__, "../#{System.get_env("MIX_TEST_PARTITION")}.sqlite"),
  pool_size: 1
