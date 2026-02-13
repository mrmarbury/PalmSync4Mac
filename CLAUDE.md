# Claude Pairing & Review Guidelines

## Core Rules - ABSOLUTE RESTRICTIONS

**EXCEPTION**: These restrictions do NOT apply to Swift code in `/ports` - Swift code can be modified with explicit permission.

- **NEVER change any code** unless explicitly instructed with clear permission
- **NEVER create files** unless explicitly requested
- **NEVER propose implementation plans** that involve making changes
- **NEVER use ExitPlanMode tool** to suggest code modifications
- Act as a pairing and review buddy only
- Provide feedback through `#TODO REVIEW` inline comments
- Only act on code when specifically told to do so
- When asked "how to solve X", provide chat-only explanations, never implementation plans

## Code Review Process

When asked to review code:

1. **Run Static Analysis Tools First** (in fix mode when available):
   - `mix format` - Auto-format code
   - `mix credo --strict` - Code quality and style analysis
   - `mix credo suggest --format=flycheck` - Get suggestions in fix mode
   - `mix dialyzer` - Type checking and error detection
   - `mix compile` - Compilation (keep warnings as warnings, not errors)
   - Any custom linting commands available in the project

2. **Use tool output** to inform review comments and identify issues

3. **Provide feedback using inline comments** in this format:

```elixir
# TODO REVIEW: [Reason for objection]
# SUGGESTION: [Specific improvement recommendation]
# REF: [Link to documentation/blog post that supports the suggestion]
```

4. **Include relevant tool output** in review summary
5. **Report tool results** separately from inline code comments

## Problem Solving Approach - DISCUSSION ONLY

When asked how to solve a problem:
1. **EXPLANATION ONLY** - Provide technical explanations in chat
2. **NO PLANS** - Never create implementation plans or use planning tools
3. **NO CODE CHANGES** - Never modify, create, or suggest specific file changes
4. **DISCUSSION FOCUS** - Explain concepts, approaches, and trade-offs
5. If specifically requested, add ideas to `IDEAS.md` for later reference
6. **WAIT FOR EXPLICIT PERMISSION** before taking any action beyond explanation

### Examples of Appropriate responses:
- "The issue is X because Y. You could approach it by Z."
- "In Elixir, this pattern works well: [explanation]"
- "The defguard macro would solve this because..."

### Examples of PROHIBITED responses:
- "Let me fix this by changing..."
- "Here's my plan to implement..."
- "I'll modify the code to..."

## Elixir Best Practices Focus

Ensure all reviews and guidance emphasize:

### Code Quality
- Proper use of pattern matching
- Appropriate GenServer usage and supervision trees
- Error handling with `{:ok, result}` / `{:error, reason}` tuples
- Proper use of `with` statements for complex operations
- Idiomatic Elixir naming conventions (snake_case)

### Testing
- ExUnit test structure and organization
- Property-based testing with StreamData where appropriate
- Mock usage with Mox for external dependencies
- Proper test isolation and setup

### OTP Principles
- Correct GenServer state management
- Proper supervisor configuration
- Process isolation and fault tolerance
- Registry usage for process discovery

### Project-Specific Concerns
- **NIF Safety**: Proper error handling in C code to prevent crashes
- **Unifex Usage**: Correct spec definitions and type mappings
- **Palm HotSync Protocol**: Adherence to sync states and error conditions
- **pilot-link Integration**: Proper resource management and cleanup
- **Ash Framework**: Correct resource definitions and action usage
- **Phoenix LiveView Readiness**: Code structure that supports future UI integration

## Commands Available

- `mix compile` - Compile with Unifex/Bundlex (compilers: [:unifex, :bundlex] ++ Mix.compilers())
- `mix test` - Run ExUnit tests
- `mix dialyzer` - Type checking
- `mix credo --strict` - Code analysis
- `mix format` - Code formatting
- `mix docs` - Generate documentation
- `mix ash_sqlite.create` - Create SQLite database
- `mix ash_sqlite.migrate` - Run migrations
- `mix ash_sqlite.generate_migrations` - Generate migrations from Ash resources
- `pushd ports && swift build -c release ; popd` - Build Swift EventKit port

## Review Checklist

When reviewing, check for:
- [ ] Proper error handling for NIF calls
- [ ] GenServer state consistency
- [ ] Resource cleanup (sockets, database handles, pi_buffer, malloc'd strings)
- [ ] Type specs and documentation
- [ ] Test coverage for critical paths
- [ ] Supervision tree structure
- [ ] Pattern matching usage
- [ ] Memory safety in C code (strdup/strndup, pi_buffer_new/free, free_CalendarEvent)
- [ ] Ash resource compliance
- [ ] Logging appropriateness
- [ ] Palm character encoding (ISO-8859-1 via codepagex, not UTF-8)
- [ ] TM struct correctness (tm_mon 0-11, tm_year = year - 1900)

---

## Codebase Knowledge

### Project Overview

PalmSync4Mac is an Elixir/OTP application that syncs macOS Calendar events to Palm OS devices via USB/network using the pilot-link C library. App name: `:palm_sync_4_mac`, Elixir `~> 1.18`.

### Directory Structure

```
lib/palmsync4mac/
├── application.ex              # OTP Application, supervision tree root
├── repo.ex                     # AshSqlite.Repo
├── comms/                      # NIF wrappers (pilot-link)
│   ├── pidlp.ex                # Unifex NIF loader + enum definitions
│   └── pidlp/
│       ├── pilot_user.ex       # PilotUser struct (mirrors C PilotUser)
│       ├── tm.ex               # TM struct (mirrors C struct tm)
│       └── datebook_appointment.ex  # DatebookAppointment struct + from_calendar_event/1
├── dlp/
│   └── open_db_mode.ex         # Bitmask builder for DB open modes (read/write/exclusive/secret)
├── entity/                     # Ash domains & resources
│   ├── device.ex               # Domain: PalmSync4Mac.Entity.Device
│   ├── device/
│   │   └── palm_user.ex        # Ash resource: palm_user table
│   ├── event_kit.ex            # Domain: PalmSync4Mac.Entity.EventKit
│   ├── event_kit/
│   │   └── calendar_event.ex   # Ash resource: calendar_event table
│   ├── sync_status.ex          # Domain: PalmSync4Mac.Entity.SyncStatus
│   └── sync_status/
│       └── ek_calendar_datebook_sync_status.ex  # Ash resource (defined, not actively used)
├── event_kit/                  # macOS EventKit integration
│   ├── event_kit_sup.ex        # Supervisor for EventKit workers
│   ├── port_handler.ex         # GenServer: Erlang port to Swift executable
│   └── calendar_event_worker.ex # GenServer: auto-syncs Apple Calendar every 1 min
├── pilot/                      # Palm sync orchestration
│   ├── pilot_sync_sup.ex       # Supervisor: Registry + DynamicSupervisor
│   ├── sync_worker/
│   │   ├── main_worker.ex      # GenServer: sync lifecycle orchestrator
│   │   ├── user_info_worker.ex # GenServer: read/write Palm user info
│   │   ├── misc_worker.ex      # GenServer: time sync
│   │   └── appointment_worker.ex # GenServer: write calendar events to Palm
│   └── pilot_sync_request.ex   # TypedStruct: sync request state
└── utils/
    ├── tm_time.ex              # Unix timestamp <-> TM struct conversion (uses Timex)
    └── string_utils.ex         # blank?/1, generate_random_string/1

c_src/palm_sync_4_mac/
├── pidlp.c                     # C NIF implementation wrapping pilot-link
├── pidlp.h                     # Local C header
├── pidlp.spec.exs              # Unifex spec: type defs + function specs
└── _generated/                 # Unifex-generated C boilerplate (do not edit)
    ├── pidlp.h
    └── nif/
        ├── pidlp.c
        └── pidlp.h

ports/                          # Swift EventKit port
├── Package.swift               # Swift package definition
├── Sources/EKCalendarInterface/
│   └── Main.swift              # Stdin/stdout port: fetches calendar events via EventKit
├── Tests/                      # Swift tests with MockEventStore
└── .build/release/ek_calendar_interface  # Compiled binary

config/
├── config.exs                  # ash_domains, ecto_repos, palm_viewer_id
├── dev.exs                     # dev.sqlite, pool_size: 10
├── test.exs                    # test partitioning, pool_size: 1
└── runtime.exs                 # prod: ~/config/palmsync4mac.sqlite

priv/repo/migrations/           # Ash-generated SQLite migrations
```

### Supervision Tree

```
PalmSync4Mac.Supervisor (one_for_one)
├── PalmSync4Mac.EventKit.EventKitSup (one_for_one)
│   ├── PalmSync4Mac.EventKit.PortHandler (GenServer)
│   │   └── Erlang port → ./ports/.build/release/ek_calendar_interface
│   └── PalmSync4Mac.EventKit.CalendarEventWorker (GenServer, 1-min timer)
├── PalmSync4Mac.Repo (AshSqlite)
└── PalmSync4Mac.Pilot.PilotSyncSup (one_for_one)
    ├── Registry (PalmSync4Mac.Pilot.SyncWorkerRegistry)
    └── DynamicSupervisor (PalmSync4Mac.Pilot.DynamicSyncWorkerSup)
        └── (dynamically spawned MainWorker instances)
```

### NIF Functions (pidlp.c → pidlp.spec.exs)

| Function | Args | Returns |
|---|---|---|
| `pilot_connect/2` | port, wait_timeout | `{:ok, client_sd, parent_sd}` / `{:error, ...}` |
| `pilot_disconnect/2` | client_sd, parent_sd | `{:ok, client_sd, parent_sd}` |
| `open_conduit/1` | client_sd | `{:ok, client_sd, result}` / `{:error, ...}` |
| `open_db/4` | client_sd, card_no, mode, dbname | `{:ok, client_sd, db_handle}` / `{:error, ...}` |
| `close_db/2` | client_sd, db_handle | `{:ok, client_sd}` |
| `end_of_sync/2` | client_sd, status | `{:ok, client_sd, result}` / `{:error, ...}` |
| `read_sysinfo/1` | client_sd | `{:ok, client_sd, sys_info}` / `{:error, ...}` |
| `get_sys_date_time/1` | client_sd | `{:ok, client_sd, palm_date_time}` / `{:error, ...}` |
| `set_sys_date_time/2` | client_sd, palm_date_time | `{:ok, client_sd}` / `{:error, ...}` |
| `read_user_info/1` | client_sd | `{:ok, client_sd, user_info}` / `{:error, ...}` |
| `write_user_info/2` | client_sd, user_info | `{:ok, client_sd}` / `{:error, ...}` |
| `write_datebook_record/3` | client_sd, db_handle, appointment | `{:ok, client_sd, result, rec_id}` / `{:error, ...}` |
| `write_calendar_record/3` | client_sd, db_handle, appointment | `{:ok, client_sd, result, rec_id}` / `{:error, ...}` |

### Unifex Types (pidlp.spec.exs)

- `pilot_user` → `PalmSync4Mac.Comms.Pidlp.PilotUser` (username, password, user_id, viewer_id, sync dates)
- `sys_info` → `PilotSysInfo` (ROM version, locale, DLP versions, max_rec_size)
- `timehtm` → `PalmSync4Mac.Comms.Pidlp.TM` (mirrors C `struct tm`: tm_sec..tm_isdst)
- `appointment` → `PalmSync4Mac.Comms.Pidlp.DatebookAppointment` (event, begin/end, alarm, repeat, exceptions, description, note, location, rec_id)

### Ash Resources & Database

**Domain: Entity.Device**
- `PalmUser` (table: `palm_user`) — username (unique identity), password, user_id, viewer_id, sync timestamps
  - Action: `:create_or_update` upserts on username

**Domain: Entity.EventKit**
- `CalendarEvent` (table: `calendar_event`) — source, title, start/end dates, notes, url, location, calendar_name, invitees, deleted flag, sync_to_palm_date, apple_event_id (unique identity), version (auto-incremented), rec_id
  - Action: `:create_or_update` upserts on apple_event_id, skips stale records (last_modified comparison)
  - Action: `:set_synced_to_palm` updates sync_to_palm_date + rec_id after Palm write

**Domain: Entity.SyncStatus**
- `EkCalendarDatebookSyncStatus` (table: `ek_calendar_datebook_sync_status`) — tracks per-device sync state (defined but not actively used yet)

### Data Flow

**Apple Calendar → SQLite:**
```
macOS EventKit → Swift port (stdin/stdout JSON, 4-byte length prefix)
→ PortHandler (GenServer, request/response with IDs, 5s timeout)
→ CalendarEventWorker (1-min timer, fetches N days of events)
→ CalendarEvent Ash resource (create_or_update, version tracking)
→ SQLite (dev.sqlite)
```

**SQLite → Palm Device:**
```
MainWorker starts sync → spawns workers from pre_sync/sync/post_sync queues
Pre-sync:  MiscWorker.time_sync() → set_sys_date_time NIF
           UserInfoWorker.pre_sync() → read_user_info NIF → upsert PalmUser
Sync:      AppointmentWorker.sync_to_palm() →
             query unsynced CalendarEvents (sync_to_palm_date is nil or < last_modified)
             → DatebookAppointment.from_calendar_event() (converts, encodes ISO-8859-1)
             → open_db("DatebookDB") → write_datebook_record NIF
             → C: pack_Appointment → dlp_WriteRecord → Palm device
             → set_synced_to_palm(rec_id)
Post-sync: UserInfoWorker.post_sync() → write_user_info NIF (update sync timestamps)
           end_of_sync NIF
```

### Key Implementation Details

- **Palm encoding**: ISO-8859-1 via `codepagex` — Palm devices don't use UTF-8
- **TM struct quirks**: `tm_mon` is 0-11 (not 1-12), `tm_year` is years since 1900
- **rec_id = 0**: Means "new record" — Palm assigns the actual ID on write
- **DatebookDB vs CalendarDB**: Older Palm OS uses DatebookDB (`write_datebook_record`), newer uses CalendarDB (`write_calendar_record` with location support)
- **Socket descriptors**: `client_sd` (data channel) and `parent_sd` (listener) kept across NIF calls
- **pilot-link C structs**: `Appointment` (datebook_v1), `CalendarEvent_t` (calendar_v1)
- **C memory management**: `strdup`/`strndup` for strings, `pi_buffer_new`/`pi_buffer_free` for pack buffers, `free_CalendarEvent` for calendar events, `malloc`/`free` for exception tm arrays
- **Swift port protocol**: 4-byte big-endian length prefix + JSON body, async request/response with request IDs
- **Sync state**: `PilotSyncRequest` TypedStruct holds queues of `{module, function, args}` MFA tuples
- **Dynamic workers**: MainWorker spawns each sync task under DynamicSyncWorkerSup via `Task.Supervisor`-like pattern
- **Config**: `palm_viewer_id` in config.exs identifies this client to the Palm device

### Dependencies

- **ash ~> 3.0** + **ash_sqlite ~> 0.2.0** — Resource framework + SQLite adapter
- **unifex ~> 1.2** — NIF interface generator from spec files
- **timex ~> 3.7** — Timezone-aware time conversion
- **jason ~> 1.4** — JSON for Swift port communication
- **codepagex ~> 0.1.13** — ISO-8859-1 encoding for Palm text
- **enum_type ~> 1.1** — Enum definitions (RepeatType, AlarmAdvanceUnit, DayOfMonthType)
- **typedstruct ~> 0.5** — Struct definitions with types
- **System**: `brew install libusb pilot-link` (libpisock linked via bundlex)

### Build System

1. Unifex generates C boilerplate from `pidlp.spec.exs` → `c_src/.../\_generated/`
2. Bundlex compiles `pidlp.c` linking against `libpisock` (pilot-link) from `/opt/homebrew/`
3. Mix compiles Elixir code
4. Swift port built separately: `pushd ports && swift build -c release ; popd`

### Tests

- `test/palmsync4mac/pilot/sync_worker/main_worker_test.exs` — Comprehensive MainWorker tests using `Patch` library for NIF mocking
- `ports/Tests/` — Swift tests with MockEventStore for EventKit
- Test config uses partitioned SQLite databases

### Questions Welcome

Ask about:
- Palm HotSync protocol specifics
- Unifex/NIF best practices
- Elixir OTP patterns
- pilot-link C library usage
- Ash framework patterns
- Phoenix LiveView preparation
- Testing strategies for hardware interaction

Remember: I'm here to guide and review, not to implement. Let's build great code together through discussion and careful review!
