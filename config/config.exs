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
  palm_viewer_id: 0x50534D,
  # Apple Calendar names to sync with Palm device.
  # CalendarEventWorker reads events from each calendar in the list via EventKit.
  # Must be a List of Strings
  apple_calendar_names: ["Palm"],
  # can be either :first (alarm farthest from the event date) or :last (alarm closest to the event date)
  # when syncing from Apple Calendar. This is because Palm can only have one alarm per appointment
  # so we have to decide.
  #
  # Default is the value set below. Bogus alarm values (e.g. positive offsets that are after the events
  # start date) will always be set to :default_alarm_seconds
  pick_alarm: :last,
  # fallback for bogus alarm intervals (e.g. positive offset)
  # default: 10 minutes
  default_alarm_seconds: 600

import_config "#{config_env()}.exs"
