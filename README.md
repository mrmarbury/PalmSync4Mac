# PalmSync4Mac

Sync your Palm devices with your Mac apps.

WARNING: DON'T USE YET! IT'S NOT DOING ANYTHING MEANINGFUL YET!

## Installation

- `brew install libusb`
- `mix local.hex` (if you don't have hex installed)
- `mix deps.get`
- `mix deps.compile`
- `mix ash_sqlite.create`
- `mix ash_sqlite.migrate`
- `mix compile`
- `pushd ports && swift build -c release ; popd`
- `iex -S mix`

## Dev Notes

### Getting New Compilable Dependencies

Sometimes this might be needed to get new dependencies right:

1. mix deps.clean --install
1. mix deps.get
1. mix deps.compile

### Fetch Apple Events and store them in the DB

```elixir
{:ok, data} = PalmSync4Mac.EventKit.CalendarHandler.get_events(0, "Calendar")
Enum.each(data["events"], fn cal_date -> PalmSync4Mac.Entity.CalendarEvent |> Ash.Changeset.for_create(:create_or_update, cal_date) |> Ash.create! end)
```
