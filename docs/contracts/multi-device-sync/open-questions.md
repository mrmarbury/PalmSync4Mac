# Open Questions — Multi-Device Sync Contracts

## PilotUser vs PalmUser identity source (Contract 5, Prohibition 2)

**Status**: RESOLVED

**Resolution**:
- `PilotUser` (from NIF) = **input data**. Its `username` field is used to upsert `PalmUser`. Its integer `user_id` is the Palm device's own ID (unique per device, set on first HotSync) — distinct from the Ash UUID.
- `PalmUser` (Ash resource) = **persistence identity**. Its `id` (UUID) is the database PK.
- `palm_user_id` in all contracts = `PalmUser.id` (Ash UUID), **never** `PilotUser.user_id` (Palm integer).
- The current `EkCalendarDatebookSyncStatus` code is WIP — relationships may need fixing during BUILD, but the intent is unambiguous: `palm_user_id` FK references `PalmUser.id`, `calendar_event_id` FK references `CalendarEvent.id`.

**Contract 5 Prohibition 2 rewrites to**:
"NEVER use `PilotUser.user_id` (Palm device integer) as the sync identifier. The sync identifier is always `PalmUser.id` (Ash UUID). PilotUser is input data from the device; PalmUser is the persistence source of truth."
