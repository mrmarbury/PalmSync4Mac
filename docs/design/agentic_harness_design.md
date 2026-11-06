# Agentic Harness Design — Self-Running Development Under nono

## Status: Consented (2026-11-06) — build-out tracked in GitHub Issues

## Problem Statement

PalmSync4Mac development is currently human-prompted: every session needs the
developer to drive it. The goal is a self-running project — a supervisor that
starts work, hands tickets to workers, runs impl/review loops, and prepares
releases — while keeping two invariants:

1. **The security boundary**: everything that drives the app forward runs
   inside the nono sandbox (ps4m profile). Only harness/meta work (nono and
   opencode configuration) runs outside, because the sandbox correctly forbids
   modifying its own configuration from within.
2. **The quality boundary**: ADP discipline (contracts as the single source
   of truth, test-first, full gate) survives the automation.

## Core Decisions (grilling session 2026-11-06)

1. **Nono-only by activity, enforced at one choke point.** All app work —
   features, debugging, docs, and the `.opencode/`/`.agents/` machinery inside
   the repo — is done inside nono under ps4m. Harness/meta work (profiles,
   global opencode config) is done outside. Enforcement is structural: the
   supervisor can only be born via its launch command, and the seatbelt
   sandbox propagates down the process tree — every worker it spawns is
   contained, with no per-worker enforcement needed.
2. **The supervisor is a run, not a process.** No resident daemon. One command
   boots a supervisor run under ps4m (detached nono session so long batches
   survive terminal closes); the run drains the queue and exits. Scheduled
   behavior, if ever wanted, goes through `oma schedule` — never residency.
3. **GitHub Issues are the queue's source of truth.** Labels are the state
   machine (`ready` → `in-progress` → `in-review` → closed-on-merge);
   supervisor comments are the audit log; the merge closes the issue natively
   (`Closes #N` on the PR). Live run state lives in the supervisor's memory
   channel (`.agents/state/memories`), never in gh — durable queue state and
   ephemeral run state have different lifetimes and different homes. Workers
   report; only the supervisor writes queue state.
4. **Merge gate: signoff-first, graduated later.** Every merge requires the
   dev PO's signoff initially. Flipping to auto-merge (routine tickets only)
   is a deliberate, PO-owned change made after the judge is calibrated.
   Permanent denylist (never auto-merges): harness/meta changes, dependency
   bumps, AGENTS.md.
5. **The supervisor is the full engineer and the starter; the dev PO gates
   the front.** The SV's context advantage is the codebase itself (graft
   graph, serena, hexdocs) — not external memory, which may be flaky or have
   gaps. Rocco is demoted to writeback-only: it never starts anything and
   never informs planning. Per ticket: SV picks a groomed issue → BOUND with
   the PO (interactive) → ARCHITECT via grill-me (interactive) → SPECIFY
   drafted by the SV, PO joins when warranted → contract locked → PO
   detaches → autonomous tail.
6. **Serial first, pipelined later.** One ticket in flight; the "mob" is the
   impl↔review↔doc worker loop within a ticket, not parallel stories.
   Worktree-per-ticket from day one, so parallel tails are a knob rather than
   a rewrite. Rationale: calibration attribution — with one ticket in
   flight, every anomaly is attributable.

## The Run (per-ticket lifecycle)

```
issue (ready, groomed by PO)
  └─ supervisor run boots: nono run --profile ps4m --detach, PO attaches
      ├─ precondition check (issue groomed, no conflicting in-flight work)
      ├─ BOUND          interactive — PO attached
      ├─ ARCHITECT      interactive — grill-me between PO and SV
      ├─ SPECIFY        SV drafts the Contract Sheet; PO joins if flagged
      ├─ contract locked → PO detaches
      ├─ BUILD          workers (oma implementation / documentation agents)
      ├─ VERIFY         review workers; impl↔review loop until the
      │                 independent judge is satisfied
      ├─ INTEGRATE      full gate: mix format && mix credo --strict &&
      │                 mix compile && mix test, plus the Swift port build
      │                 (swift build --disable-sandbox inside nono)
      └─ release agent  PR ("Closes #N") → PO merge signoff → next ticket
```

## Calibration Knobs (PO-owned, deliberately open)

- Auto-merge flip and its threshold (decision 4)
- SPECIFY attendance — always initially, relax later (decision 5)
- Pipelining / mob concurrency (decision 6)
- ADP adaptation for autonomous stages — parked until the harness works

## Infrastructure Prerequisites

- ps4m 1.4.0: project-config restoration (pack env-var override) and
  `~/.hexdocs_mcp` grant
- `oma` CLI grant (`~/.bun/bin/oma`) for `oma agent:spawn` / `oma schedule`
- serena + context7 MCP under nono (binary grant; `mcp.context7.com`
  allowlist decision)
- `.agents/state` directories inside the repo workdir
- oma plugin fix (currently fails to load in all modes)
