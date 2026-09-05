# PalmSync4Mac

Sync your Palm devices with your Mac apps.

WARNING: DON'T USE YET! IT'S NOT DOING ANYTHING MEANINGFUL YET!

Please don't open any issues yet. I know that nothing is working. That's because there is nothing to work yet.

## Installation

- `brew install libusb pilot-link`
- `mix local.hex` (if you don't have hex installed)
- `mix deps.get`
- `mix deps.compile`
- `mix ash_sqlite.create`
- `mix ash_sqlite.migrate`
- `mix compile`
- `mix docs` (if you want dev docs)
- `pushd ports && swift build -c release ; popd`
- `iex -S mix`

### Test Database Setup

The test suite uses a separate SQLite database (`test_.sqlite`) with Ash migrations. After pulling new code or updating dependencies, run:

```bash
MIX_ENV=test mix ash_sqlite.create
MIX_ENV=test mix ash_sqlite.migrate
```

If you see "no such table" errors in tests, the test database is out of date — re-run the commands above.

### Stale Build Cache

If `mix` tasks fail with dependency version mismatches after updating deps (e.g. `ash 3.5.23 does not match ~> 3.7`), the `_build/` cache is stale. Mix reads compiled `.app` files for version info, not the lock file. Fix:

```bash
rm -rf _build
mix deps.compile
```

This is caused by `mix deps.update` or pulling code that updated `mix.lock` without cleaning `_build/`.

## Configuration

### Config Attibutes in `:palm_sync_4_mac`

- `:swift_port_binary` - Override default Swift Calendar Event port binary. Default `./ports/.build/release/ek_calendar_interface`

## Dev Notes

### Getting New Compilable Dependencies

Sometimes this might be needed to get new dependencies right:

1. mix deps.clean --all
1. mix deps.get
1. mix deps.compile

### Generate Migrations

`mix ash_sqlite.generate_migrations`

### Run the sync - for now, until there is a UI

1. `iex -S mix`
1. `PalmSync4Mac.Pilot.SyncTest.sync`

### Links

[howto: sqlite migrations](https://hexdocs.pm/ash_sqlite/migrations-and-tasks.html)
