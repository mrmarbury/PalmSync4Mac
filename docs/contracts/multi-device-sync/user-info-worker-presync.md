## Contract — UserInfoWorker.pre_sync

> **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key). NOT the Palm device's integer `user_id`. All contracts reference the UUID.

### Purpose
Read Palm user info from device, upsert PalmUser to database, and return palm_user_id so MainWorker can inject it into the sync queue.

### Inputs → Outputs

| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| client_sd | integer | valid NIF socket descriptor (GenServer state, not a function argument) | `{:ok, palm_user_id}` | UUID | PalmUser exists in DB with this palm_user_id |
| (implicit) Palm device | hardware | connected via USB, pre_sync queue running | PalmUser upserted | side effect | PalmUser row created or updated in SQLite |

### Invariants (MUST ALWAYS be true)
1. After successful return, palm_user_id is ALWAYS available (non-nil UUID)
2. PalmUser is upserted on `username` identity — same device always maps to same PalmUser
3. If `read_user_info` NIF fails, return `{:error, reason}` — do NOT create a PalmUser

### Error cases

| Condition | Behavior |
|-----------|----------|
| NIF `read_user_info` fails | `{:error, reason}` — do NOT upsert PalmUser |
| PalmUser upsert fails | `{:error, reason}` — propagate error, sync cannot proceed without palm_user_id |
| Device returns empty username | Generate username via existing `PalmSync4Mac.Utils.StringUtils.generate_random_string/1`. Upsert on this username. Collision on upsert returns existing PalmUser — correct behavior (same device reconnecting). Push improvements as GitHub issue. |

### Integration points
- Depends on: `PalmSync4Mac.Comms.Pidlp.read_user_info/1` NIF (reads user info from Palm)
- Depends on: `PalmSync4Mac.Entity.Device.PalmUser` (create_or_update upsert)
- Modifies: `palm_user` SQLite table (upsert on username)
- Consumers: `MainWorker` (receives palm_user_id from return value)

### Prohibitions (MUST NEVER)
1. NEVER return palm_user_id if the upsert failed — propagate the error
2. NEVER use `PilotUser.user_id` (Palm device integer) as the sync identifier. The sync identifier is always `PalmUser.id` (Ash UUID). PilotUser is input data from the device; PalmUser is the persistence source of truth.
3. NEVER proceed if read_user_info NIF fails — this means the device connection is broken
4. palm_user_id MUST be received as a function argument at every call site. NEVER obtain palm_user_id from process dictionary, Registry, Agent, or any global/shared state mechanism.

### Breaking Changes
1. `write_to_db!` (bang) MUST be replaced with `write_to_db` (non-bang) that returns `{:ok, _}` or `{:error, _}`. Bang functions violate the AGENTS.md hard constraint: "ALWAYS use `{:ok, result}` / `{:error, reason}` tuples."
2. Return value remains `{:ok, user_info}` (PilotUser struct). MainWorker extracts palm_user_id from user_info via PalmUser lookup after upsert. No change to return type.
