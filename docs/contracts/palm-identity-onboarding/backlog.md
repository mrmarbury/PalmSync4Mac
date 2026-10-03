# Backlog — palm-identity-onboarding (deferred items)

- **Same-name device collision hardening** — currently warn-only (contract state machine row 1). Two physical devices sharing one username merge into one row and cross-contaminate sync status. Revisit when the UI round lands (engineer decision 2026-09-18: "documented gap for now").
- **Display label field on palm_user** — separate editable label from the immutable identity username (UI round).
- **`start_queue` double-start bug** — `{:already_started, pid}` when called twice; pre-existing, may bite onboarding tests (Rocco/LEARNINGS). Fix if it blocks this round's tests, else separate cycle.
- **`last_sync_pc` hardcoded 0** — hostname/PC id would improve device-side HotSync logs; low value.
- **Username normalization** — exact byte matching only; revisit if real devices show trim/case collisions.
- **Onboarding via UI** — LiveView flow to pass the username argument (currently `SyncTest` tuple: `{UserInfoWorker, :pre_sync, ["My TX"]}`).
- **On-device duplicate batches (T|C, UX50)** — operational, not code: hard-reset those devices for a clean slate (dev system).
