import Config

if config_env() == :prod do
  config :palm_sync_4_mac, PalmSync4Mac.Repo,
    pool_size: 1,
    database: "~/config/palmsync4mac.sqlite"
end
