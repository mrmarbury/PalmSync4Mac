import Config

config :palm_sync_4_mac,
  ash_domains: [
    PalmSync4Mac.Entity.EventKit,
    PalmSync4Mac.Entity.Device,
    PalmSync4Mac.Entity.SyncStatus
  ],
  # Ash-native repo declaration. Used by Ash internals for domain→repo resolution.
  # Not read by ash_sqlite mix tasks (they use ecto_repos below).
  ash_repos: [PalmSync4Mac.Repo],
  # Required by ash_sqlite.create and ash_sqlite.migrate — these tasks delegate to
  # Ecto's Mix.Tasks.Ecto.Create/Migrate, which read ecto_repos to find the repo.
  # Source: AshSqlite.Mix.Helpers.repos!/2 calls Application.get_env(:ecto_repos, [])
  ecto_repos: [PalmSync4Mac.Repo],
  # Viewer ID written to Palm during sync to identify this client application.
  # Must be a non-negative integer (unsigned long in pilot-link C API).
  # 0x50534D = ASCII "PSM" (PalmSync4Mac), displayed as 5263635 decimal.
  # The Palm OS uses this to track which application last synced with the device.
  palm_viewer_id: 0x50534D

import_config "#{config_env()}.exs"
