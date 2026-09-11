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

## 4. Attachment Blob Sync (CalendarEvent.blob)

### Origin
CalendarDB's `CalendarEvent_t` struct has a `blob[MAX_BLOBS]` field for attachments. During the location-sync fix (Gate D), we identified that Apple Calendar events may have attachments that could theoretically be synced to Palm. Deliberately excluded because attachment handling introduces size and format constraints that need careful design.

### What It Should Do
Sync attachments from Apple Calendar events to Palm CalendarDB records, with safety constraints:

- **Format filter**: Only sync attachment types supported by the Palm device (e.g., vCard, text, images the Palm image viewer can open). Unsupported formats should be skipped with a log warning.
- **Size limit**: Only sync attachments below a configurable max size (suggested: 64KB per attachment, ~256KB total per event). Oversized attachments should be skipped with a log warning.
- **Fallback for DateBook**: DateBook v1 has no blob field — attachments are impossible on pre-5.2 devices. No note-appending fallback (unlike location/tz).

### Where to Implement
1. Add `blob` field to the `appointment` Unifex type and C struct (currently absent).
2. In `write_calendar_record`, pack blob data into `CalendarEvent_t.blob` via pilot-link's `pack_CalendarEvent`.
3. In Elixir, extract attachments from `EKEvent` via EventKit Swift port and encode into the blob field.
4. Add configuration for max attachment size and supported MIME types.

### Affected Contracts
- **New contract needed** for attachment sync (extends Gate D / CalendarDB path).
- **pidlp.spec.exs** — add `blob` field to `appointment` type.
- **DatebookAppointment** struct — add `blob` field.
- **Swift EventKit port** — attachment extraction.

### Priority
**Low** — Palm devices have limited storage and attachment support is spotty. Core sync (title, time, location, note, repeat rules) should be stable first. May become more important if users want to sync contacts or photos.

---

## Summary

| # | Item | Priority | New NIFs Needed | New Contracts |
|---|------|----------|----------------|---------------|
| 1 | sync_expired | Medium | No | No (extends C3, C4) |
| 2 | sync_from_palm | High | Yes (dlp_ReadRecordById, dlp_ReadRecordByIndex, dlp_ReadNextModifiedRec) | Yes (C6) |
| 3 | delete sync | Medium | Yes (dlp_DeleteRecord) | Possibly (extends C1, C3 or new) |
| 4 | attachment blob | Low | No (extends existing) | Yes (extends Gate D) |
