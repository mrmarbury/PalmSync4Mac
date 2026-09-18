# Backlog — EK Alarms → Palm (deferred from reviews)

| # | From | Severity | Item | Disposition |
|---|------|----------|------|-------------|
| 1 | VERIFY Step 8 (2026-09-12) | MEDIUM | Legacy DB rows hold RAW alarm lists (pre-cleaning). Worker only re-cleans events inside the Swift fetch window; out-of-window rows would sync a flipped alarm via abs() on first Palm sync | Engineer decision: accepted/backlogged — dev DB can be wiped/re-synced; revisit if real data exists |
| 2 | SHIP Step 15 | LOW | Lost-write + retry with rec_id=0 can duplicate a Palm record (inherent DLP limitation, no ack idempotency) | Backlogged — document in README when deletion/dup handling gets its own contract |
| 3 | SHIP Step 15 | LOW | Every unchanged event logs a warning-level stale-upsert rescue on each 1-minute autosync cycle | Backlogged — needs its own contract cycle (touches the frozen rescue branch) |
| 4 | SHIP Step 15 | LOW | Deleted events: no `deleted: false` filter in AppointmentWorker; deletion propagation unimplemented | Backlogged — separate feature contract (feeds #34/epic #30 scope) |
| 5 | SHIP Step 16 | LOW | log_alarm_cleaning/2 runs on every event even when nothing was cleaned | Backlogged — trivial cost, contract-compliant |
| 6 | SHIP Step 14 v1 | LOW | Bignum property generator caps at 10^12; behavior manually verified to 10^19 | Backlogged — widen generator when the property suite is next touched |
