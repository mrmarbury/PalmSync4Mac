import Config

config :palm_sync_4_mac,
  ash_domains: [PalmSync4Mac.Entity, PalmSync4Mac.Device],
  ash_repos: [PalmSync4Mac.Repo]

import_config "#{config_env()}.exs"
