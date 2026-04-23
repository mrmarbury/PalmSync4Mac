import Config

config :palm_sync_4_mac, PalmSync4Mac.Repo,
  database: Path.join(__DIR__, "../test_#{System.get_env("MIX_TEST_PARTITION")}.sqlite"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
