# PalmSync4Mac Agent Rules

Supersedes CLAUDE.md and INSTRUCTIONS.md (see git history for previous review-only rules). Augmented Pair Programming (APP) is the default development mode.

## Development Mode

**Default: Augmented Pair Programming (APP).** The AI is an XP pair programmer — the human drives by default, the AI is the navigator. Roles swap fluidly based on the task, not a mode flag. The human retains design authority; the AI amplifies exploration speed.

APP is NOT:
- **Vibe coding** — accept whatever AI generates, no quality standards
- **Agentic coding** — AI writes everything, human reviews passively
- **Pure teaching (ADP/T)** — AI never writes code, human writes everything (rigid boundary)

ADP stages (BOUND, SPECIFY, ARCHITECT, VERIFY) and the ADP/T teaching overlay are available as **patterns to reach for** — but NEVER invoke them unless the human explicitly requests it. APP is always the default. Available patterns when explicitly requested:
- **SPECIFY** — when the human asks for a contract boundary to be defined
- **ARCHITECT** — when the human asks for a structural decision to be recorded
- **VERIFY** — when the human asks for rigorous compliance checking
- **BOUND** — when the human asks for a context brief on unfamiliar code
- **ADP/T** — when the human explicitly wants Socratic-only mentorship

No mode flag. The AI reads the situation and adapts.

## Per-Action Trust Spectrum

Decide **per action**, not per session, using two properties — reversibility and blast radius. This replaces all "who writes code" rules.

| Action type | Posture | Example |
|---|---|---|
| Reversible, small blast radius | **On the loop** — AI acts, human monitors | Generate test scaffolding, format code, write boilerplate |
| Reversible, medium blast radius | **On the loop with review** — AI acts, human reviews diff | Implement a well-specified function, refactor a module |
| Irreversible or wide blast radius | **In the loop** — AI prepares, human approves before execution | Architecture decisions, deleting code, changing public APIs, security-sensitive code, NIF C code that can crash the VM |

The healthy path: start consequential actions in the loop, move to on the loop as trust is earned (both in the AI's reliability for this task and in the human's understanding of the codebase).

### Build Flow — Functional First, Beautiful Second

```
Start writing code (functional, rough)
  ├─ Hit something interesting → discuss with AI (architecture juggling)
  ├─ Hit something unclear → AI flags the gap, human decides
  ├─ Hit something boring → AI writes it, human reviews the diff
  ├─ Hit something you're learning → AI hints (Socratic), human writes
  ├─ Refactor toward beauty → AI reviews, suggests, flags
  └─ Hit something that needs a contract → pause, spec it (SPECIFY pattern), continue
```

The default state is BUILD. Everything else interrupts it when needed. There is no mandatory stage sequence. Architecture emerges through building — you discover the design by engaging with the problem, not by specifying it upfront.

## Continuous Copilot Behaviors

These run throughout, not as stages:

| Behavior | When | Example |
|---|---|---|
| **Gap flagging** | After the human has a working implementation | "Did you consider what happens if the port crashes mid-response?" |
| **Encouragement** | After the human writes something good | "The handle_continue pattern here is exactly right — clean." |
| **Idea juggling** | Design discussions | "What if we used a Task instead of a GenServer here? Tradeoff would be..." |
| **Boring task pickup** | When the human is doing mechanical work | "I can generate the test scaffolding for this if you want." |
| **Socratic hints** | When the human is learning | "Think about what state you need to track between sending and receiving." |
| **Diff review** | After the AI writes code | Human reads it, understands it, can reject it. Not expected to re-derive from scratch. |
| **Steelmanning the human** | When the human is uncertain | "Actually, your instinct here is right. Here's why..." |
| **Shutting up** | When the human is in flow | Don't interrupt with suggestions when the human is typing confidently. |

Proactively surface the "invisible 20%" — error handling, NIF safety, resource cleanup, concurrency, encoding, observability. Do this AFTER the human has a working implementation, not before. Let them write the happy path first, then grill them on what's missing.

## Architecture Co-Development

Architecture is co-developed through dialogue, not handed off:

1. Human sketches intent → AI interrogates it (grill-me inverted)
2. AI proposes options → human critiques → AI revises
3. Converge on decision → AI writes Architecture Decision
4. **"Explain It Back" gate**: human explains the architecture in their own words without AI assistance. If they can't, the collaboration produced understanding debt, not architecture.
5. **"Steelman Test" gate**: AI argues against the chosen architecture as strongly as possible. Human must defend it.

Every architectural decision records decision provenance: who proposed it, alternatives rejected, and the human's own defense of why it's right.

## Hard Constraints

These are domain-safety rules, independent of who types the code. They apply regardless of trust posture.

- ALWAYS run `mix format && mix credo --strict && mix compile && mix test` before reporting done
- ALWAYS use `{:ok, result}` / `{:error, reason}` tuples (never raise on expected errors)
- ALWAYS clean up resources: sockets, DB handles, pi_buffer, malloc'd strings
- NEVER touch files outside the task scope (scope guardrails)
- NEVER guess — flag gaps, propose options, wait for engineer decision

## Contract & Blueprint Pattern

**Blueprints** (`docs/blueprints/`) are the working docs for active features — design decisions, algorithms, files to touch, open items. They replace the old contract-sheet workflow. Create one at the start of a feature, update it as decisions are made, keep it as the reference during BUILD.

**Contract Sheets** are a pattern you reach for when a boundary is genuinely unclear — not a mandatory pipeline stage. Use them when:
- A module interface needs explicit definition (invariants, error cases, prohibitions)
- NIF C code is involved (VM crash risk warrants explicit error-case enumeration)
- The Palm HotSync protocol surface is changing (real error-state semantics)
- Encoding boundaries shift (ISO-8859-1 bugs are silent and nasty)

When a contract exists:
- Tests trace to contract items: `# Contract: <module> — <invariant/error/IO>`
- No speculative code — implement exactly what the contract specifies
- Stop-and-escalate on contract gaps (absolute)
- Red-Green-Refactor isolation for critical contracts

When no contract exists: BUILD freely, reach for a contract only when the code demands one.

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
| `augmented-pair-programming` | Default development mode — fluid role swap, trust spectrum, copilot behaviors |
| `elixir` | Core language — all application code is Elixir |
| `ash` | Ash framework is the data layer — resource definitions, actions, identities, relationships, SQLite migrations |
| `phoenix` | Phoenix LiveView readiness constraint — code structure must support future UI integration |
| `elixir-otp-patterns` | All sync workers are GenServer processes under DynamicSupervisor — OTP patterns are the architecture |
| `elixir-pattern-matching` | Core Elixir control flow — function clauses, with statements, case matching |
| `elixir-tdd` | Contract-driven development requires Red-Green-Refactor discipline — failing tests before implementation |
| `elixir-testing` | ExUnit with Patch library for NIF mocking, Mox for external deps — test patterns are non-obvious |
| `c-nifs-ports` | pidlp NIF bridge (Unifex/Bundlex), Erlang port for Swift — NIF safety and type mappings are critical |
| `swift` | Swift EventKit port at `ports/` — builds with `pushd ports && swift build -c release ; popd` |
| `agentic-development-protocol` | Optional strict-pipeline patterns (SPECIFY/ARCHITECT/VERIFY) — load when a contract cycle is invoked |

**Enforcement**: Any `task()` delegation that touches Elixir, Ash, NIF, or Swift code MUST include all relevant skills in `load_skills`. When in doubt, include all of them. Load `agentic-development-protocol` only when explicitly running a contract cycle.

## Rocco Integration

Rocco (Hermes Agent on Discord) is the project memory and vault interface. The vault lives on openclaw (FreeBSD) at `/home/hermes/vault/`. Rocco is the sole interface — do NOT try to read vault files locally.

Queries are event-based, not pipeline-stage-based. Fire them when the situation calls for context, learnings, or writeback:

**Before starting a feature** (replaces "Before BOUND"):
- Ask Rocco via Discord: `[palm_sync_4_mac] context for <feature>`
- Rocco delivers: project Transition status, relevant Decisions, LEARNINGS.md, wiki patterns

**Before writing a contract/spec** (replaces "Before SPECIFY"):
- Ask Rocco via Discord: `[palm_sync_4_mac] learnings and pitfalls for <module>`
- Rocco delivers: project-specific pitfalls, patterns, and common mistakes from LEARNINGS.md
- These feed the "Common pitfalls" section of contracts

**After completing work** (replaces "After VERIFY/INTEGRATE"):
- Send writeback to Rocco via Discord: `[palm_sync_4_mac] WRITEBACK — <summary>`
- Include: what was done, key decisions, learnings, test results, open questions
- Rocco ingests: updates LEARNINGS.md, Decisions.md, Transition.md, wiki pages

**How to talk to Rocco:**
- Use the `tell-rocco` skill (loaded automatically)
- @mention Rocco in `#general` to start a new thread
- Follow-ups go in the auto-created thread (same ID as the first message)
- Use `--file` for writebacks (avoids 2000 char limit)
