import Config

config :palmsync4mac, :ash_domains, [PalmSync4Mac.Entity, PalmSync4Mac.Device]
config :palmsync4mac, :ash_repos, [PalmSync4Mac.Repo]

import_config "#{config_env()}.exs"
