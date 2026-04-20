## Contract — MainWorker MFA Injection

> **palm_user_id** = `PalmUser.id` (Ash-generated UUID primary key). NOT the Palm device's integer `user_id`. All contracts reference the UUID.

### Purpose
After UserInfoWorker.pre_sync() returns palm_user_id, inject it into the remaining sync queue MFA args so that AppointmentWorker receives it.

### Inputs → Outputs

| Input | Type | Constraints | Output | Type | Guarantee |
|-------|------|-------------|--------|------|-----------|
| pre_sync result | `{:ok, palm_user_id}` or `{:error, reason}` | palm_user_id: UUID | Updated sync queue | list of MFA tuples | palm_user_id injected into each MFA arg list |
| sync_queue | list of `{Module, :function, args}` | non-empty after pre_sync completes | Same tuples with palm_user_id prepended/appended to args | list | Workers receive palm_user_id as first/last arg |

### Invariants (MUST ALWAYS be true)
1. palm_user_id MUST be set before the sync queue executes
2. pre_sync MUST succeed — it is the gate for the entire sync. If pre_sync returns `{:error, _}`, the sync is fatal: skip sync_queue, run post_sync for protocol cleanup (sync date updated, NOT successful sync date), then terminate.
3. Every MFA tuple in the sync queue receives palm_user_id as the LAST argument after injection. Example: `{AppointmentWorker, :sync_to_palm, [client_sd, palm_user_id]}`
4. post_sync queue is NOT affected by palm_user_id injection (it doesn't need it)

### Error cases

| Condition | Behavior |
|-----------|----------|
| pre_sync returns `{:error, reason}` | Fatal — skip sync_queue. Always run post_sync (Palm protocol requires `end_of_sync`). UserInfoWorker.post_sync updates sync date but NOT successful sync date. |
| palm_user_id is nil after successful pre_sync | `{:error, :palm_user_id_missing}` — bug, not runtime condition |
| Sync queue is empty | No injection needed, skip to post_sync |

### Integration points
- Depends on: `UserInfoWorker.pre_sync/1` return value (must include palm_user_id)
- Depends on: `PilotSyncRequest` typedstruct (sync_queue, pre_sync_queue, post_sync_queue)
- Modifies: PilotSyncRequest.sync_queue (rewrites MFA args to include palm_user_id)
- Consumers: `AppointmentWorker.sync_to_palm/2` (receives palm_user_id as new argument)

### Prohibitions (MUST NEVER)
1. NEVER execute sync_queue if palm_user_id is not available — pre_sync failure is fatal. Sync_queue workers run linearly with continue-on-error; pre_sync failure is the only fatal exit.
2. NEVER inject palm_user_id into post_sync queue MFA args — post_sync doesn't need it. VERIFY: post_sync MFA tuples are unchanged after injection.
3. palm_user_id MUST be received as a function argument at every call site. NEVER obtain palm_user_id from process dictionary, Registry, Agent, or any global/shared state mechanism.
4. NEVER modify the MFA module or function — only the args list

### Design note
All workers MUST run linearly, one after another. No branching, no skipping. If a sync_queue worker fails, log and continue to the next. post_sync always runs. Only pre_sync failure is fatal (terminates after post_sync cleanup).

palm_user_id is extracted from UserInfoWorker.pre_sync's return value (`{:ok, user_info}`) — MainWorker looks up PalmUser by username after the upsert and injects `PalmUser.id` into remaining sync_queue args.
