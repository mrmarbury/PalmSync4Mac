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

- ```
  export ERTS_INCLUDE_DIR=/opt/homebrew/Cellar/erlang/27.2.1/lib/erlang/erts-15.2.1/include && \
  clang -I$ERTS_INCLUDE_DIR -dynamiclib -undefined dynamic_lookup -o priv/iohid_nif.so nifs/iohid_nif.c -framework IOKit -framework CoreFoundation ; \
  ```

- `iex -S mix`

## Dev Notes

### Fetch Apple Events and store them in the DB

```elixir
{:ok, data} = PalmSync4Mac.EventKit.CalendarHandler.get_events(0, "Calendar")
Enum.each(data["events"], fn cal_date -> PalmSync4Mac.Entity.CalendarEvent |> Ash.Changeset.for_create(:create_or_update, cal_date) |> Ash.create! end)
```
