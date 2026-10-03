# Contract — MainWorker.terminate / Pidlp.end_of_sync (session teardown)

## Purpose

Every DLP session ends with an explicit `dlp_EndOfSync` so the device commits session state (sync status + successfulSyncDate) — instead of relying on pi_close's conditional auto-send, which only fires under clean socket state (evidence: `.agents/state/memories/result-investigate-20260913-094700.md`, pi-dlp.h:783).

## Inputs → Outputs

| Input | Type | Constraints | Output | Guarantee |
|---|---|---|---|---|
| `client_sd` | integer | ≥ 0 for real socket | `end_of_sync(sd, status)` called exactly once before disconnect | device finalizes session |
| `reason` | term | terminate reason | status 0 when `:normal`, 3 ("reasonable abort") otherwise | per pi-dlp.h dlpEndStatus docs |

## Invariants

1. `MainWorker.terminate/2` with a valid socket calls `end_sync` before `pilot_disconnect` — status 0 for `:normal`, 3 for any other reason.
2. `client_sd < 0` (no socket) → no NIF call, no crash.
3. `end_of_sync` failure is logged, never blocks the disconnect.
4. Probe REMOVED: `write_user_info_raw/5`, its mock additions (`dlp_request_new`/`dlp_exec`/`dlp_request_free`/`dlp_response_free`/`dlp_htopdate` functional mocks), and its wire tests are dropped from the branch (recoverable: wip commit 263edf2).

## Error cases

| Condition | Behavior |
|---|---|
| end_of_sync returns error | log + proceed to disconnect |
| no socket at terminate | skip silently |

## Prohibitions

1. Never raise from terminate.
2. Never disconnect before end_of_sync when a socket exists.
3. No raw-request probe code in the shipped NIF surface.

## Tests

Existing 4 tests from the wip commit (normal/abort/no-socket/error-path) stay green; probe tests removed with the probe.
