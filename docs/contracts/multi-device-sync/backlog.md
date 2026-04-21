# Backlog — Multi-Device Sync (Deferred Items)

> **ADP Stage**: BUILD → deferred
> **Date**: 2026-04-21
> **Status**: Documented, not implemented

Items identified during the multi-device-sync BUILD stage but deliberately excluded from the current implementation cycle. Each entry records the origin, intended behavior, implementation location, affected contracts, and priority.

---

## 1. sync_expired Flag

### Origin
Old `AppointmentWorker` had `sync_to_palm(sync_expired \\ false)` parameter that was unused. Removed during C3 rewrite. User asked to leave it out and document it for later.

### What It Should Do
Allow syncing past/expired appointments to Palm devices.

- When `sync_expired: false`, filter out events where `end_date < DateTime.utc_now()`.
- When `sync_expired: true`, include all events regardless of date.

### Where to Implement
- Add `sync_expired` option (keyword opts) to `AppointmentWorker.list_unsynced_for_device/1`.
- Filter in the `Enum.filter` call that follows the unsynced query.
- Add `sync_expired` option field to `PilotSyncRequest` so callers can pass it through.

### Affected Contracts
- **C3** (AppointmentWorker) — new option on query function
- **C4** (MainWorker) — pass option through sync_queue

### Priority
**Medium** — useful for historical data sync, but not critical for basic functionality.

---

## 2. sync_from_palm (Reverse Sync)

### Origin
Architecture Decision document (Section 9, "Out of Scope") explicitly defers bidirectional sync. Currently only Apple→Palm (`sync_to_palm`) is implemented.

### What It Should Do
Read appointments from Palm DatebookDB and create/update corresponding Apple Calendar events. Reverse of the current `sync_to_palm` flow.

- Read Palm records via NIF.
- Match to existing CalendarEvents (by `apple_event_id` or create new).
- Upsert via Ash.

### Where to Implement
New worker module (e.g., `AppointmentWorker.sync_from_palm/1`) or a new module entirely. Would need:

1. Read Palm records via NIF (`dlp_ReadRecordById`, `dlp_ReadRecordByIndex`, `dlp_ReadNextModifiedRec` — none of these NIFs exist yet; see architecture-decision.md Section 5).
2. Match to existing CalendarEvents by `apple_event_id` or create new events.
3. Upsert via Ash `CalendarEvent.create_or_update`.

### Affected Contracts
- **New contract needed** (C6 or similar) for the reverse sync flow.
- **C3** (AppointmentWorker) would need updates for bidirectional sync status tracking.
- **C1** (EkCalendarDatebookSyncStatus) would need updates for tracking Palm→Apple sync direction.

### Priority
**High** — users expect bidirectional sync, but architecturally complex. Requires conflict resolution strategy not yet designed.

---

## 3. Delete Sync (Deletion Propagation)

### Origin
CalendarEvent resource has a `deleted` boolean field (soft delete), but no deletion sync logic exists. Deletions on one side are not propagated to the other.

### What It Should Do
Propagate deletions between Palm and Apple Calendar.

- When a CalendarEvent is marked `deleted: true` on the Apple side, delete the corresponding record on Palm (and vice versa).
- Handle the case where `rec_id` exists in the join table — call NIF `dlp_DeleteRecord` to remove the Palm record.

### Where to Implement
Could extend AppointmentWorker with `sync_deletions/1`, or create a new DeleteSyncWorker. Would need:

1. Query CalendarEvents where `deleted: true` AND not yet deletion-synced (new join table field or flag).
2. Call NIF `dlp_DeleteRecord` for each matching record that has a `rec_id` in the join table.
3. Update join table to mark deletion as synced.

### Affected Contracts
- **C3** (AppointmentWorker) or **new contract** for deletion sync flow.
- **C1** (EkCalendarDatebookSyncStatus) would need a `deletion_synced` boolean field (default `false`).

### Priority
**Medium** — important for data consistency, but complex edge cases around soft-delete vs hard-delete and cross-device deletion conflict.

---

## Summary

| # | Item | Priority | New NIFs Needed | New Contracts |
|---|------|----------|----------------|---------------|
| 1 | sync_expired | Medium | No | No (extends C3, C4) |
| 2 | sync_from_palm | High | Yes (dlp_ReadRecordById, dlp_ReadRecordByIndex, dlp_ReadNextModifiedRec) | Yes (C6) |
| 3 | delete sync | Medium | Yes (dlp_DeleteRecord) | Possibly (extends C1, C3 or new) |
