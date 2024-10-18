import Config

config :palmsync4mac,
  ash_domains: [PalmSync4Mac.Entity, PalmSync4Mac.Device],
  ash_repos: [PalmSync4Mac.Repo],
  pilot_link_bin_path: "./assets/pilot_link/0.12.5/bin",
  pilot_link_tools: [
    calendar_write: "pilot-install-datebook"
  ]

import_config "#{config_env()}.exs"
