import Config

# Configure your database
config :palmsync4mac, PalmSync4Mac.Repo,
  database: Path.join(__DIR__, "../dev.sqlite"),
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
