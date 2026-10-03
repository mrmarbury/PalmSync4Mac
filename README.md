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

The same applies to the dev database (`dev.sqlite`) at sync time: an error like
`no such column: c0.alarms_seconds` when syncing means the dev database predates
a schema change — run `mix ash_sqlite.migrate` (without `MIX_ENV=test`).

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

### Agent Tooling (graft context graph)

This repo is indexed by [graft](https://npmjs.com/package/graft): a context graph of every symbol and its callers, stored in `graft/` (git-ignored — run `graft build` to regenerate; deterministic, no API key, $0).

The optional LLM pass (`graft build --deep` — concept nodes + per-symbol summaries) talks to any OpenAI-compatible endpoint, configured via a `.env` file in the repo root (git-ignored):

```
GRAFT_PROVIDER=openai
GRAFT_BASE_URL=http://localhost:11434/v1
GRAFT_MODEL=qwen2.5-coder:32b
GRAFT_API_KEY=<any non-empty value for local endpoints>
```

The setup above uses a local [Ollama](https://ollama.com) server:

```bash
brew install ollama
ollama pull qwen2.5-coder:32b
ollama serve   # OpenAI-compatible API at http://localhost:11434/v1
```

`GRAFT_PROVIDER` selects the wire format: `openai` | `anthropic` | `litellm` | `orcarouter`. No embedding models are needed — graft's deep pass is summarization-only.

Other tooling (no configuration required): the hexdocs MCP server (`.opencode/opencode.jsonc`, fetched on demand via npx) and the igniter dev/test dependency.

## Device Onboarding — read this before your first sync

How a Palm gets its identity in PalmSync4Mac:

- **A device that already carries a name** (it was named on the Palm itself or
  by a previous sync) is **adopted as-is**. It **cannot be renamed** — this is
  a hardware limitation of Palm OS, which silently ignores username writes on
  established devices. The name it reports is the name it keeps, and it is the
  database key that ties the device to its sync history.
- **A blank/freshly wiped device** takes the explicit name you pass to the
  `UserInfoWorker.pre_sync` call in the sync queue (until there is a UI, edit
  the tuple in `PalmSync4Mac.Pilot.SyncTest.sync/0`):

  ```elixir
  {UserInfoWorker, :pre_sync, ["My TX"]}
  ```

  A device that already carries a name ignores the argument, so leaving or
  passing a name is always safe for established devices.

- **With no argument**, the sync generates a random 5-character name
  (`[a-z0-9]`, e.g. `q7f3m`).

> **⚠️ The name you first sync with becomes the device's PERMANENT identity.**
> Palm names are immutable after the first sync — the device keeps whatever
> name it received in that first session, forever. To get a nice label on your
> Palm, onboard with an explicit name as shown above. If you let a random
> generated name stick, the only way to change it is a hard reset plus a
> clean database (see below).

A re-onboarded device — hard-reset hardware that re-enters sync asking for a
name the database already knows — gets its full calendar re-pushed from
scratch: the per-device sync bookkeeping is deliberately reset so the empty
device is repopulated cleanly.

### Clean slate (forget a device entirely)

To make a device completely unknown to PalmSync4Mac again:

1. Hard-reset the Palm (so it reports a blank name), **and**
2. Delete the dev database files: `dev.sqlite` plus `dev.sqlite-wal` and
   `dev.sqlite-shm` if present, then `mix ash_sqlite.create && mix ash_sqlite.migrate`.

Doing only one of the two leaves a half-known device: a wiped Palm re-meeting
an old row triggers the re-onboard path (and a full re-push), and a blank
database meeting a named Palm adopts the device's old name again.

## Known Limitations

### Alarm Rounding (Palm Wire Format)

The Palm stores an appointment alarm as **one byte of advance + one byte of
unit** — at most 255 minutes (~4¼ h), 255 hours (~10½ days), or 255 days
(~8 months) before the event. Apple Calendar allows arbitrary alarm offsets,
so not every value survives the trip to the device:

- Cleanly divisible offsets (whole minutes up to 255, whole hours, whole days)
  are stored exactly, in the largest unit that fits.
- Odd values round **up** to the next whole minute below 4¼ h (e.g. a
  90-second alarm becomes 2 min), to the next whole hour beyond that (e.g. a
  270-minute alarm becomes 5 h), and to the next whole day beyond 10½ days.
- Values that round up onto an exact whole hour or day are stored in the
  larger unit (a 59-minute-59-second lead is stored as "1 hour", not
  "60 minutes" — same instant, coarser unit).
- Alarms more than 255 days out are capped at 255 days — the only case that
  alarms *later* than requested.

Rounding up is deliberate: an alarm that fires a little too early can be
snoozed; one that fires too late is simply missed. Alarms with a positive
offset (after event start) are discarded at ingestion; if an event had only
such alarms, a default 10-minute alarm (`:default_alarm_seconds`) is stored.

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
1. `PalmSync4Mac.Pilot.SyncTest.sync()` — for a blank device with no name argument this generates a random identity (see [Device Onboarding](#device-onboarding--read-this-before-your-first-sync)); to name it, put the name in the `UserInfoWorker` pre_sync tuple as described there

### Links

[howto: sqlite migrations](https://hexdocs.pm/ash_sqlite/migrations-and-tasks.html)
