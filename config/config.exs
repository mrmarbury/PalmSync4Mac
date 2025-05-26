import Config

config :palm_sync_4_mac,
  ash_domains: [
    PalmSync4Mac.Entity.EventKit,
    PalmSync4Mac.Entity.Device,
    PalmSync4Mac.Entity.SyncStatus
  ],
  # ash_repos: [PalmSync4Mac.Repo]
  ecto_repos: [PalmSync4Mac.Repo]

import_config "#{config_env()}.exs"
