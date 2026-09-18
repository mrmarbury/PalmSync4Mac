# Learnings — PalmSync4Mac

Cross-cycle lessons (append-only, newest first). Per-feature decisions live in
`docs/contracts/<feature>/architecture-decision.md`; user-visible quirks in README.

## 2026-09-12 — #31 Layer 3 (EK alarms → Palm)

- **Check the WIRE format, not the C struct.** The blueprint said alarm advance was a 32-bit int with "no practical protocol cap" — true for pilot-link's in-memory struct, false for the Palm record layout: advance is ONE byte + unit byte (max 255 per unit). Unbounded values wrapped on-device (270 min → 14 min) or crashed the NIF path (bignums). Lesson: for interop boundaries, verify the serialization format, not the memory representation.
- **Swift/C are dumb providers; Elixir owns policy.** The Swift port ships raw alarm lists; cleaning, validation, unit choice, rounding policy, and configurability all live in pure Elixir (Utils.AlarmPicker) where they're testable. Keep the NIF/port layers thin transports.
- **Contract-as-SSOT beats the coordinator.** A build agent caught a arithmetic slip in the orchestrator's own task brief (90060s → 25h would fire 60s late) and implemented {26, :hours} per the contract instead. The discipline works — when prompt and contract conflict, the agent followed the contract.
- **Ceil-up for alarms: "better too early than too late" (snooze exists).** Rounding direction is a product decision, not a math one — floor/nearest were both on the table; "never fire later than requested" won because a late alarm is missed, an early one is snoozed.
- **Environment noise: ElixirLS and clangd diagnostics are unreliable here.** ElixirLS shows a stale `deps.loadpaths` Mix.Error; clangd can't see Unifex-generated headers (`UNIFEX_TERM`, `timehtm` "unknown"). Trust `mix compile`/`mix test` shell output over LSP diagnostics in this repo.
- **Loud failure for config typos.** Invalid `:pick_alarm` deliberately raises FunctionClauseError at sync time rather than silently defaulting (engineer decision Q3) — config mistakes should crash loudly, close to the cause.
