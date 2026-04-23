import Config

config :palm_sync_4_mac, PalmSync4Mac.Repo,
  database: Path.join(__DIR__, "../test_#{System.get_env("MIX_TEST_PARTITION")}.sqlite"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

# Disable supervisors that require runtime-only resources (Swift port, Palm hardware).
# The Swift EventKit port binary is not built in CI, and Palm sync workers
# need a physical device connection — both crash the supervision tree if started.
config :palm_sync_4_mac, start_event_kit_sup: false
config :palm_sync_4_mac, start_pilot_sync_sup: false
