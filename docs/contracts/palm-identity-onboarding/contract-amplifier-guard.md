# Contract — list_unsynced_for_device (zero-join amplifier guard)

## Purpose

`list_unsynced_for_device` treating "zero join rows" as "sync everything" is the amplifier that turned the identity bug into duplicate batches. Keep the behavior (it is the legitimate first-sync-after-onboarding path) but make it loud.

## Invariant

1. When the query returns "everything" because the device has zero `ek_calendar_datebook_sync_status` rows, emit one `Logger.warning` stating both possibilities: expected on first sync after onboarding, or unexpected sync-status/data loss — so a future silent amplifier is visible in logs.

## Prohibitions

1. No behavior change — the function still returns all events for a zero-join device (first sync must full-push).

## Test

Log assertion (Patch/ExUnit capture): zero join rows → warning emitted; join rows present → no warning.
