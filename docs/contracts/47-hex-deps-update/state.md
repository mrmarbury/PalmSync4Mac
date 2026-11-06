# Verification Report — Issue #47 spike (Hex deps update)

- **Branch:** `spike/47-hex-deps-update` (from main @ 5f783b8)
- **Dates:** 2026-11-06, supervisor: Beezle
- **Status:** Verification complete. PR opened against #47. **DO NOT MERGE** — dependency
  bumps are on the permanent denylist; merge requires explicit engineer signoff.
- Supersedes the paused state.md from the pre-restart session (rebar3/nono blocker, resolved).

## What the bump does

- **ash 3.13.0 → 3.37.3** (the ticket target — patches GHSA-jjf9-w5vj-r6vp,
  EEF-CVE-2026-82745, EEF-CVE-2026-55736, EEF-CVE-2026-82740/82743)
- ash_sqlite 0.2.14 → 0.2.19, ash_sql 0.2.93 → 0.8.8, spark 2.4.0 → 2.7.9
- reactor 0.17.0 → 1.0.7 (major bump, pulled by ash itself; not used directly)
- igniter 0.8.0 → 0.8.5, telemetry 1.3.0 → 1.4.2, + ~40 transitive bumps
- `mix deps.unlock --unused` removed a stale orphan chain: **hackney 1.25.0**
  (CRITICAL CVE-2026-115693 and friends) + parse_trans, ssl_verify_fun,
  unicode_util_compat, picosat_elixir. Nothing in the tree pulled them.
- **`mix hex.audit`: "No retired or security advisory packages found"** ✅ (re-verified post-fix)

## Migration changes required by ash 3.37 (the only source changes)

1. **`config/config.exs`** — ash >= 3.37 hard-requires `config :ash, :default_string_length_count`
   (compile error without it). Set to **`:codepoints`** (engineer decision 2026-11-06):
   counts unicode codepoints, matching how SQLite counts length, so min_length/max_length
   validation is consistent between Elixir and SQL. Inert for existing code — no resource
   uses string length constraints; it only governs future string attributes.
2. **`lib/palmsync4mac/entity/event_kit/calendar_event.ex`** — `create_or_update`'s
   `upsert_condition` uses `^arg(:new_last_modified)` / `^arg(:new_alarms_seconds)`, which
   were never declared as `argument`s. ash 3.13 silently tolerated `set_argument/3` on
   undeclared names; ash 3.37 rejects them (`Ash.Error.Invalid.NoSuchInput`, 18 test
   failures) and binds NULL in the upsert SQL. Declared both arguments, types mirroring
   the corresponding attributes, **`allow_nil?` unset (true)**: nil binds SQL NULL →
   ON CONFLICT WHERE false → treated as stale, exactly the pre-3.37 semantics for
   callers that don't set them (seed fixtures in other resources' tests). The production
   path (`CalendarEventWorker`) always sets both.

## Verification results (all gates run post-migration-fix)

| Gate | Result |
|---|---|
| rebar3 sandbox grant | ✅ `rebar 3.22.0` runs (telemetry 1.4.2 compiles) |
| `mix compile` | ✅ app generated; only pre-existing warnings (typed_struct_nimble_options `validation_type` notices — from pinned deps typed_struct 0.3.0 / typed_struct_nimble_options 0.1.1, unchanged by this bump; NIF C `uint64_t*`→`unsigned long*` warnings, unchanged) |
| `mix test` | ✅ **128 tests, 10 properties, 0 failures** |
| `mix format` / `--check-formatted` | ✅ clean |
| `mix credo --strict` | ✅ no new findings; 1 refactor + 11 design suggestions all pre-existing on main (FIXME #12 tag, `list_unsynced_for_device` nesting in untouched `appointment_worker.ex`) |
| `mix dialyzer` | ⚠️ 1 warning: `datebook_appointment.ex:113` unknown type `DatebookAppointment.t/0`. **Pre-existing on main** (last touched in PR #41): the `@spec` self-references by bare alias which never expands into the beam's spec chunk. NOT caused by this bump — left untouched per engineer decision; follow-up ticket also adds dialyzer as a CI step. |
| Migration drift | ✅ none — diff adds only `argument` declarations (never schema-affecting). `generate_migrations --check` fails only with the pre-existing "dev migrations remain" message, identical on main. |
| Swift EventKit port | ✅ verified clean pre-restart (`swift build -c release --disable-sandbox`); nothing in the spike touches `ports/`, not re-run |
| `mix hex.audit` | ✅ no advisories |

## Gotchas discovered this session (do not repeat)

- **`mix ash_sqlite.generate_migrations --dry-run` DELETES the `_dev` migrations and
  snapshots.** Our migrations/snapshots are `_dev`-suffixed (dev workflow); running the
  generator without `--dev` triggers the "consolidate dev migrations" path which removes
  them, and `--dry-run` suppresses the new-file writes but NOT the removal. It emptied
  `priv/repo/migrations/` and `priv/resource_snapshots/` mid-session; restored via
  `git restore`. For a no-touch drift check use `--check` only.
- ash >= 3.37 rejects `set_argument/3` on undeclared argument names with NoSuchInput;
  any `^arg(:...)` in upsert_condition/atomic_update expressions now needs a matching
  `argument` declaration in the action.
- Slow network: use `HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=600000` for any Hex fetch.
  If a tarball fetch times out, curl from `https://repo.hex.pm/tarballs/<name>-<version>.tar`
  into `~/.hex/packages/hexpm/` directly.
- SwiftPM's nested `sandbox-exec` cannot apply under nono → always build the port with
  `swift build --disable-sandbox`.
- Per docs/learnings.md: trust `mix compile`/`mix test` output over ElixirLS/clangd diagnostics.
- `gh` CLI is blocked by nono (can't read `~/.config/gh/config.yml`) — PR/issue
  mechanics need a nono grant or manual step.

## Files NOT ours, left out of the PR (pre-existing working-tree noise)

- `AGENTS.md` (supervisor name "Beezle" note — user's, separate commit if desired)
- `run_nono.sh` (user's `--auto` edit for the nono fix)
- `docs/design/agentic_harness_design.md`, `opencode.json` (untracked, not ours)

## Next steps

1. PR merged only after explicit engineer signoff (denylist rule).
2. Follow-up ticket: fix `DatebookAppointment.t()` typespec self-reference AND add
   `mix dialyzer` to CI (`.github/workflows/elixir.yml`).
3. After merge + user tells me: Rocco writeback per AGENTS.md (hard gate — never preemptive).
