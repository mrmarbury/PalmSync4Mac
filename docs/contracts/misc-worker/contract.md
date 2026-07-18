# Contract Sheet — MiscWorker Test Coverage

**Feature**: MiscWorker — comprehensive test coverage for time_sync and future misc sync functions
**ADP Stage**: BOUND → SPECIFY (not yet started)
**Date**: 2026-07-08
**Origin**: Post-BUILD review of Gate D-1 (sys-info-worker) identified that MiscWorker has zero test coverage and is the canonical example for the `:ok` skip path in `run_pre_sync`.

---

## 1. Goal

Create comprehensive test coverage for `PalmSync4Mac.Pilot.SyncWorker.MiscWorker`, which currently has no test file despite being used in production (`sync_test.ex` places `{MiscWorker, :time_sync, []}` as the first item in `pre_sync_queue`).

---

## 2. Current State

**Module**: `lib/palmsync4mac/pilot/sync_worker/misc_worker.ex`

```elixir
defmodule PalmSync4Mac.Pilot.SyncWorker.MiscWorker do
  use GenServer
  defstruct client_sd: -1

  def time_sync, do: GenServer.call(__MODULE__, :time_sync)

  def handle_call(:time_sync, _from, state) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    case Pidlp.set_sys_date_time(state.client_sd, timestamp) do
      {:ok, _client_sd} -> {:reply, :ok, state}
      {:error, message} -> {:reply, {:error, message}, state}
    end
  end
end
```

**Problem**: No `misc_worker_test.exs` exists. The `:ok` return from `time_sync` is the canonical example in contract §4.4 for the `:ok → skip` path in `run_pre_sync`, but it's only tested indirectly via a fake module in the sys-info-worker gate.

---

## 3. Components (to be specified)

### 3.1 MiscWorker.time_sync/0

| Test | Behavior |
|------|----------|
| Returns `:ok` when NIF succeeds | Patches `Pidlp.set_sys_date_time` to return `{:ok, _}` |
| Returns `{:error, message}` when NIF fails | Patches `Pidlp.set_sys_date_time` to return `{:error, msg}` |
| Sends correct Unix timestamp | Verify the timestamp arg passed to `Pidlp.set_sys_date_time` is close to `DateTime.utc_now() \|> DateTime.to_unix()` |

### 3.2 Future misc functions

MiscWorker is a catch-all for sync functions that don't fit elsewhere. As new functions are added, they should be tested here.

---

## 4. Open Questions (to resolve during SPECIFY)

- Should MiscWorker remain a GenServer, or should simple stateless functions be moved to a plain module? (Erik would hate the GenServer for stateless calls — see existing moduledoc)
- Should the `:ok` skip path test in `main_worker_test.exs` be updated to use the real MiscWorker (with patched NIF) instead of a fake module once this gate is implemented?
- Are there other misc functions planned for the near future that should be included in this contract?

---

## 5. Dependencies

- `Pidlp.set_sys_date_time/2` NIF (must be patched in tests)
- `MainWorker.run_pre_sync/2` (consumes `:ok` return via the `:ok → skip` clause)

---

## 6. Status

**Not started.** This contract is a stub — the full SPECIFY stage has not been run. GitHub issue: https://github.com/mrmarbury/PalmSync4Mac/issues/29
