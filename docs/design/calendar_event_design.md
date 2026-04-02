# Calendar Event Sync Design — Multi-Device Support

## Status: Proposed (Revised to use Ash many_to_many)

## Problem Statement

The current design stores `rec_id` and `sync_to_palm_date` directly on `CalendarEvent`. This creates a 1:1 relationship between a calendar event and a Palm device. When syncing to a second Palm device, the first device's `rec_id` is overwritten, breaking the ability to reference or update the record on the original device.

```
Current: CalendarEvent ──(1:1)──> Palm Device
Needed:  CalendarEvent ──(1:N)──> Palm Devices
```

## Design Goals

1. Support syncing calendar events to multiple Palm devices simultaneously
2. Track per-device sync state (rec_id, sync date, version, success)
3. Preserve design space for future bidirectional sync (Palm → Mac)
4. Use PalmUser.username as device identity (unique in our domain)
5. PalmSync4Mac is the authoritative source — if a user names two Palms identically, that's not our problem

## Approach: Ash many_to_many Relationships

This design uses Ash's `many_to_many` relationship pattern instead of manually managing a join table. This provides:

**Benefits:**
- **Declarative relationships** — Ash handles the foreign key management and join logic
- **Simpler queries** — Load related data with `load()`, filter with `exists()` on relationship paths
- **Automatic preloading** — Access `event.palm_users` or `palm_user.calendar_events` naturally
- **Better type safety** — Ash validates relationship integrity at compile and runtime
- **Future-proof** — Ash optimizes join queries; we don't manually write SQL

**How it works:**
- `PalmUser` and `CalendarEvent` both declare `many_to_many` relationships
- `EkCalendarDatebookSyncStatus` is the "through" resource with `belongs_to` to both sides
- Sync metadata (`rec_id`, `last_synced`, etc.) lives on the through resource
- Ash treats the through resource as a first-class entity we can query and upsert directly

**Mental model:**
- Not a "join table" — it's a "sync status per device-event pair" resource
- Each sync status record answers: "What's the state of event X on device Y?"
- Relationships are bidirectional: query from either side

## Current Data Model

```
┌─────────────────────────────┐
│       CalendarEvent         │
├─────────────────────────────┤
│ id              (PK, UUID)  │
│ apple_event_id  (unique)    │
│ source          (string)    │
│ title           (string)    │
│ start_date      (datetime)  │
│ end_date        (datetime)  │
│ notes           (string?)   │
│ url             (string?)   │
│ location        (string?)   │
│ last_modified   (datetime)  │
│ calendar_name   (string)    │
│ invitees        ([string]?) │
│ deleted         (bool)      │
│ version         (int)       │
│ sync_to_palm_date (datetime?) ◄── Problem: only one device
│ rec_id            (int)       ◄── Problem: only one device
└─────────────────────────────┘

┌─────────────────────────────┐
│         PalmUser            │
├─────────────────────────────┤
│ id              (PK, UUID)  │
│ username        (unique)    │
│ password        (string?)   │
│ password_length (int)       │
│ user_id         (int)       │
│ viewer_id       (int)       │
│ last_sync_pc    (int)       │
│ successful_sync_date (int)  │
│ last_sync_date       (int)  │
└─────────────────────────────┘

┌──────────────────────────────────────┐
│  EkCalendarDatebookSyncStatus        │
│  (exists but not wired up)           │
├──────────────────────────────────────┤
│ id                    (PK, UUID)     │
│ palm_device_uuid      (UUID)         │
│ calendar_event_uuid   (UUID)         │
│ last_synced           (datetime)     │
│ last_synced_version   (int)          │
│ last_sync_success     (bool)         │
│ ── missing: rec_id ──                │
│ ── missing: unique composite key ──  │
└──────────────────────────────────────┘
```

## Proposed Data Model

### Entity Relationship Diagram

```
┌──────────────────┐                                            ┌──────────────────────┐
│    PalmUser      │                                            │    CalendarEvent      │
├──────────────────┤       ┌──────────────────────────────┐     ├──────────────────────┤
│ id         (PK)  │──┐    │ EkCalendarDatebookSyncStatus │  ┌──│ id            (PK)   │
│ username (unique)│  │    │     (through resource)       │  │  │ apple_event_id       │
│ user_id          │  └───>│ id                    (PK)   │<─┘  │ source               │
│ viewer_id        │       │ palm_user_id          (FK)   │     │ title                │
│ last_sync_pc     │       │ calendar_event_id     (FK)   │     │ start_date           │
│ password         │       │ rec_id          (int, def 0) │     │ end_date             │
│ password_length  │       │ last_synced     (datetime)   │     │ notes                │
│ successful_sync  │       │ last_synced_version   (int?) │     │ url                  │
│ last_sync_date   │       │ last_sync_success     (bool) │     │ location             │
│                  │       ├──────────────────────────────┤     │ last_modified         │
│ many_to_many     │       │ UNIQUE: (palm_user_id,       │     │ calendar_name        │
│ :calendar_events │       │         calendar_event_id)   │     │ invitees             │
│   through: ^     │       │                              │     │ deleted              │
│                  │       │ belongs_to :palm_user        │     │ version              │
└──────────────────┘       │ belongs_to :calendar_event   │     │ ── REMOVED ──        │
                           └──────────────────────────────┘     │ sync_to_palm_date    │
                                                                │ rec_id               │
                                                                │                      │
                                                                │ many_to_many         │
                                                                │ :palm_users          │
                                                                │   through: ^         │
                                                                └──────────────────────┘
```

### Ash Relationships

**PalmUser has many_to_many CalendarEvents:**
```elixir
many_to_many :calendar_events, CalendarEvent do
  through EkCalendarDatebookSyncStatus
  source_attribute :id
  destination_attribute :id
  source_attribute_on_join_resource :palm_user_id
  destination_attribute_on_join_resource :calendar_event_id
end
```

**CalendarEvent has many_to_many PalmUsers:**
```elixir
many_to_many :palm_users, PalmUser do
  through EkCalendarDatebookSyncStatus
  source_attribute :id
  destination_attribute :id
  source_attribute_on_join_resource :calendar_event_id
  destination_attribute_on_join_resource :palm_user_id
end
```

**EkCalendarDatebookSyncStatus belongs_to both:**
```elixir
belongs_to :palm_user, PalmUser do
  attribute :palm_user_id
  allow_nil? false
end

belongs_to :calendar_event, CalendarEvent do
  attribute :calendar_event_id
  allow_nil? false
end
```

### Changes Summary

| Resource                       | Change                                                     | Reason                                    |
| ------------------------------ | ---------------------------------------------------------- | ----------------------------------------- |
| `CalendarEvent`                | Remove `sync_to_palm_date`                                 | Moves to through resource (per-device)    |
| `CalendarEvent`                | Remove `rec_id`                                            | Moves to through resource (per-device)    |
| `CalendarEvent`                | Remove `:set_synced_to_palm` action                        | Replaced by sync_status upsert            |
| `CalendarEvent`                | Remove `rec_id` from `:create_or_update` accept list       | No longer on this resource                |
| `CalendarEvent`                | Add `many_to_many :palm_users` relationship                | Access synced devices via Ash             |
| `PalmUser`                     | Add `many_to_many :calendar_events` relationship           | Access synced events via Ash              |
| `EkCalendarDatebookSyncStatus` | Add `rec_id` (int, default 0)                              | Track Palm record ID per device           |
| `EkCalendarDatebookSyncStatus` | Rename `palm_device_uuid` → `palm_user_id`                 | Clarity: references PalmUser.id           |
| `EkCalendarDatebookSyncStatus` | Rename `calendar_event_uuid` → `calendar_event_id`         | Consistency with Ash conventions          |
| `EkCalendarDatebookSyncStatus` | Add `belongs_to :palm_user` relationship                   | Ash many_to_many requires belongs_to      |
| `EkCalendarDatebookSyncStatus` | Add `belongs_to :calendar_event` relationship              | Ash many_to_many requires belongs_to      |
| `EkCalendarDatebookSyncStatus` | Add unique identity on `{palm_user_id, calendar_event_id}` | Enable upsert per device+event pair       |
| `EkCalendarDatebookSyncStatus` | Add `:create_or_update` action                             | Upsert sync state after each sync attempt |

### Proposed EkCalendarDatebookSyncStatus Resource

```elixir
defmodule PalmSync4Mac.Entity.SyncStatus.EkCalendarDatebookSyncStatus do
  use Ash.Resource,
    domain: PalmSync4Mac.Entity.SyncStatus,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("ek_calendar_datebook_sync_status")
    repo(PalmSync4Mac.Repo)
  end

  identities do
    identity(
      :unique_device_event,
      [:palm_user_id, :calendar_event_id],
      eager_check?: true
    )
  end

  actions do
    defaults([:read, :destroy])

    create(:create_or_update) do
      upsert?(true)
      upsert_identity(:unique_device_event)

      accept([
        :palm_user_id,
        :calendar_event_id,
        :rec_id,
        :last_synced_version,
        :last_sync_success
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:rec_id, :integer) do
      description("Palm record ID. 0 = not yet written to device.")
      allow_nil?(false)
      default(0)
      public?(true)
    end

    attribute(:last_synced, :utc_datetime) do
      description("When this event was last synced to this device")
      writable?(false)
      default(&DateTime.utc_now/0)
      update_default(&DateTime.utc_now/0)
      match_other_defaults?(true)
      allow_nil?(false)
    end

    attribute(:last_synced_version, :integer) do
      description("CalendarEvent.version at time of last sync")
      allow_nil?(true)
      public?(true)
    end

    attribute(:last_sync_success, :boolean) do
      description("Whether the last sync attempt succeeded")
      allow_nil?(false)
      default(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :palm_user, PalmSync4Mac.Entity.Device.PalmUser do
      attribute :palm_user_id
      allow_nil? false
    end

    belongs_to :calendar_event, PalmSync4Mac.Entity.EventKit.CalendarEvent do
      attribute :calendar_event_id
      allow_nil? false
    end
  end
end
```

## Sync Logic Changes

### Current Sync Query (single device)

```elixir
# AppointmentWorker — current implementation
CalendarEvent
|> Ash.Query.filter(
  is_nil(sync_to_palm_date) || last_modified > sync_to_palm_date
)
|> Ash.read!()
```

### Proposed Sync Query (multi-device)

For a given `palm_user_id`, find events that need syncing:

```
Events to sync for PalmUser X:

  CalendarEvent WHERE:
    1. No sync_status exists for PalmUser X  → never synced to this device
    OR
    2. sync_status exists AND rec_id = 0     → previous write failed
    OR
    3. sync_status exists AND
       CalendarEvent.version >
       sync_status.last_synced_version       → event modified since last sync
```

Using Ash many_to_many relationships, we can query in multiple ways:

**Option A: Load relationship and filter in memory**
```elixir
# Load all events with their sync_statuses
events = CalendarEvent
|> Ash.Query.load(sync_statuses: [:palm_user])
|> Ash.read!()

# Filter for events needing sync to specific device
events
|> Enum.filter(fn event ->
  case Enum.find(event.sync_statuses, &(&1.palm_user_id == palm_user_id)) do
    nil -> true  # Never synced to this device
    %{rec_id: 0} -> true  # Previous write failed
    status -> event.version > status.last_synced_version  # Event updated
  end
end)
```

**Option B: Use Ash query filters with exists**
```elixir
# Direct filter using relationship path
CalendarEvent
|> Ash.Query.filter(
  not exists(sync_statuses, palm_user_id == ^palm_user_id)
  or exists(sync_statuses, palm_user_id == ^palm_user_id and rec_id == 0)
  or exists(sync_statuses, palm_user_id == ^palm_user_id and last_synced_version < parent(version))
)
|> Ash.read!()
```

**Option C: Query from PalmUser side**
```elixir
# Get the device, load its events, then filter
palm_user = PalmUser
|> Ash.Query.filter(id == ^palm_user_id)
|> Ash.Query.load(calendar_events: [:sync_statuses])
|> Ash.read_one!()

# All events the device has never seen
all_events = CalendarEvent |> Ash.read!()
synced_event_ids = MapSet.new(palm_user.calendar_events, & &1.id)
never_synced = Enum.reject(all_events, &MapSet.member?(synced_event_ids, &1.id))
```

Implementation will determine the most efficient approach based on query planner behavior.

### Post-Write Update

After successfully writing a record to a Palm device:

```elixir
# Current — updates CalendarEvent directly
calendar_event
|> Ash.Changeset.for_update(:set_synced_to_palm, %{rec_id: rec_id})
|> Ash.update!()

# Proposed — upserts into join table
EkCalendarDatebookSyncStatus
|> Ash.Changeset.for_create(:create_or_update, %{
  palm_user_id: palm_user_id,
  calendar_event_id: calendar_event.id,
  rec_id: rec_id,
  last_synced_version: calendar_event.version,
  last_sync_success: true
})
|> Ash.create!()
```

On write failure:

```elixir
EkCalendarDatebookSyncStatus
|> Ash.Changeset.for_create(:create_or_update, %{
  palm_user_id: palm_user_id,
  calendar_event_id: calendar_event.id,
  rec_id: 0,
  last_synced_version: calendar_event.version,
  last_sync_success: false
})
|> Ash.create!()
```

## Worker Architecture Changes

### PilotSyncRequest State

The `PilotSyncRequest` typedstruct needs to carry the PalmUser identity so that workers know which device they're syncing to.

```
Current PilotSyncRequest fields:
  sync_queue, pre_sync_queue, post_sync_queue,
  client_sd, parent_sd, connect_wait_timeout, port

Add:
  palm_user_id (UUID, default nil)
  — Set during pre_sync after UserInfoWorker.pre_sync() reads+upserts user info
```

### Sync Flow Diagram

```
MainWorker
  │
  ├─ :connect
  │    └─ pilot_connect(port, timeout) → {client_sd, parent_sd}
  │
  ├─ Pre-sync Queue
  │    ├─ MiscWorker.time_sync()
  │    │    └─ set_sys_date_time(client_sd, now)
  │    │
  │    └─ UserInfoWorker.pre_sync()
  │         ├─ read_user_info(client_sd) → PilotUser data
  │         ├─ PalmUser.create_or_update(user_data) → %PalmUser{id: uuid}
  │         └─ *** Store palm_user_id in MainWorker state ***
  │
  ├─ Sync Queue
  │    └─ AppointmentWorker.sync_to_palm(palm_user_id)  ◄── NEW: receives palm_user_id
  │         ├─ Query: unsynced events for this palm_user_id
  │         ├─ For each event:
  │         │    ├─ DatebookAppointment.from_calendar_event(event)
  │         │    ├─ open_db("DatebookDB") → db_handle
  │         │    ├─ write_datebook_record(client_sd, db_handle, appointment)
  │         │    │    ├─ Success → upsert join row (rec_id, version, success=true)
  │         │    │    └─ Failure → upsert join row (rec_id=0, version, success=false)
  │         │    └─ close_db(client_sd, db_handle)
  │         └─ done
  │
  └─ Post-sync Queue
       ├─ UserInfoWorker.post_sync()
       │    └─ write_user_info(client_sd, updated_user_info)
       └─ end_of_sync(client_sd, 0)
```

### How palm_user_id Flows

The current MFA queue pattern (`{Module, :function, args}`) runs workers via `apply/3`. The `palm_user_id` needs to reach `AppointmentWorker`. Options:

1. **Add palm_user_id to the MFA args at queue setup time** — Not possible since we don't know the palm_user_id until pre_sync runs.
2. **Inject palm_user_id into MFA args dynamically after pre_sync** — MainWorker rewrites remaining queue entries to include palm_user_id.
3. **Store palm_user_id in MainWorker state, pass it when starting workers** — Workers receive it via their struct at `start_link` time. But workers are started before the queue runs.
4. **Workers query MainWorker state** — Coupling; avoid.
5. **Use process dictionary or Registry** — Already have `SyncWorkerRegistry`.

**Recommended: Option 2** — After `UserInfoWorker.pre_sync()` returns the `palm_user_id`, `MainWorker` injects it into the remaining queue MFA args. This keeps the MFA pattern clean and self-contained. The pre_sync return value would need to include the palm_user_id.

## Bidirectional Sync — Future Considerations

This design accommodates future Palm → Mac sync without structural changes:

### Sync Direction Cases

```
┌─────────────────────┬──────────────────────┬────────────────────────────────┐
│ Scenario            │ Detection            │ Action                         │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ Mac-only event      │ No join row for      │ Write to Palm                  │
│                     │ this device          │ Create join row                │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ Palm-only event     │ Record on Palm with  │ Read from Palm                 │
│                     │ no CalendarEvent     │ Create CalendarEvent           │
│                     │                      │ Create join row                │
│                     │                      │ Later: push to Apple Calendar  │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ Both exist,         │ CalendarEvent.version│ Write updated event to Palm    │
│ Mac changed         │ > join.last_synced_  │ Update join row                │
│                     │ version              │                                │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ Both exist,         │ Palm record dirty    │ Read from Palm                 │
│ Palm changed        │ bit set, version     │ Update CalendarEvent           │
│                     │ matches              │ Update join row                │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ Both exist,         │ Palm dirty AND       │ Conflict resolution needed     │
│ both changed        │ version mismatch     │ (future: strategy TBD)         │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ Deleted on Mac      │ CalendarEvent.deleted│ Delete record on Palm          │
│                     │ = true, join row     │ Remove join row                │
│                     │ has rec_id           │                                │
├─────────────────────┼──────────────────────┼────────────────────────────────┤
│ Deleted on Palm     │ Record absent or     │ Mark CalendarEvent deleted     │
│                     │ deleted flag on Palm │ Remove from Apple Calendar     │
│                     │ join row exists      │ Remove join row                │
└─────────────────────┴──────────────────────┴────────────────────────────────┘
```

### CalendarEvent.source Field Usage

- `":apple"` — Event originated from Apple Calendar
- `"<palm_username>"` — Event originated from a Palm device (future, for Palm → Mac sync)

This allows filtering events by origin and deciding sync direction. A Palm-originated event with `source: "PalmA"` would be synced *from* PalmA to Apple Calendar, but synced *to* PalmB normally via the join table.

### No Additional Schema Needed

The join table as designed already supports bidirectional sync:
- `rec_id` tracks the Palm-side identity
- `last_synced_version` tracks the Mac-side state at sync time
- `last_sync_success` tracks reliability
- Palm dirty bit detection happens at read time (pilot-link record attributes), not in our schema

## Migration Plan

### Database Changes

1. Add `rec_id` column to `ek_calendar_datebook_sync_status`
2. Rename `palm_device_uuid` → `palm_user_id` in `ek_calendar_datebook_sync_status`
3. Rename `calendar_event_uuid` → `calendar_event_id` in `ek_calendar_datebook_sync_status`
4. Add unique index on `(palm_user_id, calendar_event_id)`
5. Remove `sync_to_palm_date` from `calendar_event`
6. Remove `rec_id` from `calendar_event`

### Code Changes

1. **`EkCalendarDatebookSyncStatus`** — Add rec_id, rename fields, add belongs_to relationships, add identity, add create_or_update action
2. **`CalendarEvent`** — Remove sync_to_palm_date, rec_id, :set_synced_to_palm action; remove rec_id from :create_or_update accept list; add many_to_many :palm_users relationship
3. **`PalmUser`** — Add many_to_many :calendar_events relationship
4. **`PilotSyncRequest`** — Add palm_user_id field
5. **`MainWorker`** — Store palm_user_id after pre_sync; inject into sync queue MFA args
6. **`UserInfoWorker.pre_sync/0`** — Return palm_user_id after upsert
7. **`AppointmentWorker`** — Accept palm_user_id; rewrite sync query using Ash relationships; write to EkCalendarDatebookSyncStatus instead of CalendarEvent after sync
8. **`DatebookAppointment.from_calendar_event/1`** — No change needed (doesn't depend on rec_id/sync_to_palm_date from CalendarEvent; rec_id comes from sync_status or defaults to 0 for new records)
9. **Generate migration** — `mix ash_sqlite.generate_migrations`
