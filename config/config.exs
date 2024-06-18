import Config

config :palmsync4mac, :ash_domains, [PalmSync4Mac.Entity, PalmSync4Mac.Device]
config :palmsync4mac, :ash_repos, [PalmSync4Mac.Repo]
config :palmsync4mac, :system_cmd, [PalmSync4Mac.Utils.SystemCmd]

import_config "#{config_env()}.exs"
