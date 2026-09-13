# PalmSync4Mac Agent Rules

Supersedes CLAUDE.md and INSTRUCTIONS.md (see git history for previous review-only rules). ADP-driven development mode.

## Development Mode

Full ADP (Agentic Development Protocol) — the original 6-stage pipeline. AI is executor in BUILD.

## Hard Constraints

- NEVER introduce behavior not specified in the active Contract Sheet
- NEVER skip the stop-and-escalate rule when encountering a contract gap
- NEVER guess — flag gaps, propose options, wait for engineer decision
- NEVER touch files outside the task scope (scope guardrails)
- ALWAYS run `mix format && mix credo --strict && mix compile && mix test` before reporting done
- ALWAYS write comments as standalone human-readable prose that a developer understands 1 year later with ALL data needed (why, constraints, context) — NEVER mechanical trace tags like `# Contract: <module> — <clause>`; traceability lives in docs/contracts/, not in code comments
- ALWAYS use `{:ok, result}` / `{:error, reason}` tuples (never raise on expected errors)
- ALWAYS clean up resources: sockets, DB handles, pi_buffer, malloc'd strings

## ADP Stage Awareness

Current stage and AI role (set per session):
- BOUND → Consultant (surfaces context, doesn't decide scope)
- SPECIFY → Consultant (probes gaps, doesn't write contracts)
- ARCHITECT → Consultant (proposes options, doesn't select)
- BUILD → Executor (implements contracts, writes code)
- VERIFY → Reviewer (runs compliance check, generates report)
- INTEGRATE → Reviewer (runs suite, reports results)

Contract Sheet is the single source of truth. Code follows contracts.

## Build/Test/Lint Commands

- `mix compile` — Compile with Unifex/Bundlex
- `mix test` — Run ExUnit tests
- `mix dialyzer` — Type checking
- `mix credo --strict` — Code analysis
- `mix format` — Code formatting
- `mix docs` — Generate documentation
- `mix ash_sqlite.create` — Create SQLite database
- `mix ash_sqlite.migrate` — Run migrations
- `mix ash_sqlite.generate_migrations` — Generate migrations from Ash resources
- `pushd ports && swift build -c release ; popd` — Build Swift EventKit port

## Contract-Driven Development Rules

- Tests first, traced to contracts
- No speculative code — implement exactly what the contract specifies
- Stop-and-escalate on contract gaps (absolute)
- One contract at a time for complex features
- Red-Green-Refactor isolation for critical contracts

## 4-Layer Guardrail Stack

| Layer | What It Catches |
|---|---|
| Scope | Agent doesn't touch files outside task scope |
| Pattern | Agent follows project conventions, not generic patterns |
| Quality | Tests pass, types check, build succeeds, linter clean |
| Human decision | Humans decide architecture, risk, priorities. Agents execute. |

## Forbidden Patterns

- No `as any` / `@ts-ignore` type suppression (if applicable)
- No empty catch blocks
- No `IO.inspect` in production code
- No hardcoded credentials or connection strings
- No deprecated PalmOS API patterns (use CalendarDB for newer devices)
- Palm encoding: ALWAYS ISO-8859-1 via codepagex, NEVER UTF-8
- TM struct: tm_mon is 0-11 (not 1-12), tm_year is years since 1900
- rec_id = 0 means "new record" — Palm assigns actual ID on write

## Project-Specific Concerns

- NIF safety: proper error handling in C code to prevent VM crashes
- Unifex: correct spec definitions and type mappings
- Palm HotSync protocol: adhere to sync states and error conditions
- pilot-link: proper resource management and cleanup
- Ash framework: correct resource definitions and action usage
- Phoenix LiveView readiness: code structure supports future UI integration

## Required Skills (ALWAYS load)

These skills MUST be loaded for ANY task in this repo. They encode domain-specific patterns that generic AI behavior will violate.

| Skill | Why It's Required |
|---|---|
| `elixir` | Core language — all application code is Elixir |
| `ash` | Ash framework is the data layer — resource definitions, actions, identities, relationships, SQLite migrations |
| `phoenix` | Phoenix LiveView readiness constraint — code structure must support future UI integration |
| `elixir-otp-patterns` | All sync workers are GenServer processes under DynamicSupervisor — OTP patterns are the architecture |
| `elixir-pattern-matching` | Core Elixir control flow — function clauses, with statements, case matching |
| `elixir-tdd` | Contract-driven development requires Red-Green-Refactor discipline — failing tests before implementation |
| `elixir-testing` | ExUnit with Patch library for NIF mocking, Mox for external deps — test patterns are non-obvious |
| `c-nifs-ports` | pidlp NIF bridge (Unifex/Bundlex), Erlang port for Swift — NIF safety and type mappings are critical |
| `swift` | Swift EventKit port at `ports/` — builds with `pushd ports && swift build -c release ; popd` |

**Enforcement**: Any `task()` delegation that touches Elixir, Ash, NIF, or Swift code MUST include all relevant skills in `load_skills`. When in doubt, include all of them.

## Rocco Integration

Rocco (Hermes Agent on Discord) is the project memory and vault interface. The vault lives on openclaw (FreeBSD) at `/home/hermes/vault/`. Rocco is the sole interface — do NOT try to read vault files locally.

**Before BOUND stage (every ADP cycle):**
- Ask Rocco via Discord: `[palm_sync_4_mac] context for <feature>`
- Rocco delivers: ADP Transition status, relevant Decisions, LEARNINGS.md, wiki patterns

**Before SPECIFY stage:**
- Ask Rocco via Discord: `[palm_sync_4_mac] learnings and pitfalls for <module>`
- Rocco delivers: project-specific pitfalls, patterns, and common mistakes from LEARNINGS.md
- These feed the "Common pitfalls" section of contract sheets

**After VERIFY/INTEGRATE (cycle complete):**
- HARD GATE: do NOT send any writeback on cycle completion alone. Send the writeback to Rocco ONLY when BOTH conditions hold: (1) the PR/branch has been finally merged to main, AND (2) the user explicitly tells me to send it (their signoff). Never send it preemptively — awaiting user review is not a trigger.
- Writeback via Discord: `[palm_sync_4_mac] WRITEBACK — <summary>`
- Include: what was done, key decisions, learnings, test results, open questions
- Rocco ingests: updates LEARNINGS.md, Decisions.md, ADP Transition.md, wiki pages

**How to talk to Rocco:**
- Use the `tell-rocco` skill (loaded automatically)
- @mention Rocco in `#general` to start a new thread
- Follow-ups go in the auto-created thread (same ID as the first message)
- Use `--file` for writebacks (avoids 2000 char limit)

<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
