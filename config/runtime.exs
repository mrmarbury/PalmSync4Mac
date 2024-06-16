import Config

if config_env() == :prod do
  config :palmsync4mac, PalmSync4Mac.Repo,
    pool_size: 1,
    database: "~/config/palmsync4mac.sqlite"
end
