# PalmSync4Mac

Sync your Palm devices with your Mac apps.

WARNING: DON'T USE YET! IT'S NOT DOING ANYTHING MEANINGFUL YET!

## Installation

- `mix local.hex` (if you don't have hex installed)
- `mix deps.get`
- `mix deps.compile`
- `mix ash_sqlite.create`
- `mix ash_sqlite.migrate`
- `mix compile`
- `pushd ports && swift build -c release ; popd`
- `iex -S mix`
