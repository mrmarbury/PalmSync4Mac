# PalmSync4Mac Agent Rules

Supersedes CLAUDE.md and INSTRUCTIONS.md (see git history for previous review-only rules). ADP-driven development mode.

## Hard Constraints

- NEVER introduce behavior not specified in the active Contract Sheet
- NEVER skip the stop-and-escalate rule when encountering a contract gap
- NEVER guess — flag gaps, propose options, wait for engineer decision
- NEVER touch files outside the task scope (scope guardrails)
- ALWAYS run `mix format && mix credo --strict && mix compile && mix test` before reporting done
- ALWAYS trace tests to contract items: `# Contract: <module> — <invariant/error/IO>`
- ALWAYS use `{:ok, result}` / `{:error, reason}` tuples (never raise on expected errors)
- ALWAYS clean up resources: sockets, DB handles, pi_buffer, malloc'd strings

## ADP Stage Awareness

Current stage and AI role (set per session):
- BOUND → Consultant (surfaces context, doesn't decide scope)
- SPECIFY → Consultant (probes gaps, doesn't write contracts)
- ARCHITECT → Consultant (proposes options, doesn't select)
- BUILD → Executor (generates code from Contract Sheet + Architecture Decision)
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

## Second Brain Integration

Vault root: `/Users/marbury/Library/Mobile Documents/iCloud~md~obsidian/Documents/Vault`

This repo is connected to a Second Brain vault (Obsidian). The vault holds domain context, decisions, learnings, and the ADP protocol itself. READ these vault files automatically at the indicated triggers — do not wait to be asked.

**On EVERY session start:**
- Read `LEARNINGS.md` — corrections and preferences that override default behavior

**Before BOUND stage (every ADP cycle):**
- Read `Projects/palmSync4Mac/ADP Transition.md` — transition status, open tasks, known issues
- Read `Decisions.md` — grep for `PalmSync` entries, past decisions constrain new choices
- Read `wiki/ai-engineering/agentic-development-protocol.md` — the full 6-stage protocol

**Before SPECIFY stage:**
- Read `wiki/elixir/` pages — domain patterns (why-elixir, phoenix-framework, hot-code-reloading, durableserver)
- Read `LEARNINGS.md` again if it was updated during BOUND

**After VERIFY/INTEGRATE (cycle complete):**
- Append new learnings to `LEARNINGS.md` (vault root)
- Log architecture decisions to `Decisions.md` (vault root)
- Update `Projects/palmSync4Mac/ADP Transition.md` — mark completed tasks
- Suggest wiki promotions if reusable knowledge emerged

**Vault files by path:**

| Path | Content | When to read |
|---|---|---|
| `LEARNINGS.md` | Corrections, preferences, patterns | Every session start + before SPECIFY |
| `Decisions.md` | Decision log | Before BOUND |
| `Projects/palmSync4Mac/ADP Transition.md` | Transition plan, status | Before BOUND |
| `wiki/ai-engineering/agentic-development-protocol.md` | Full ADP protocol | Before BOUND |
| `wiki/elixir/why-elixir.md` | BEAM concurrency, actor model | Before SPECIFY (if relevant) |
| `wiki/elixir/phoenix-framework.md` | Phoenix patterns | Before SPECIFY (if relevant) |
| `wiki/elixir/hot-code-reloading.md` | BEAM module swap | Before SPECIFY (if relevant) |
| `wiki/elixir/durableserver.md` | Fault-tolerant GenServer | Before SPECIFY (if relevant) |
| `Inbox.md` | Uncaptured ideas | When context seems incomplete |
