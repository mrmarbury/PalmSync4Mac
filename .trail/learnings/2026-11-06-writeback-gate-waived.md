# Rocco writeback gate: explicit "send it" is waived — merge is the only trigger

Date: 2026-11-06
Touches: AGENTS.md, .agents/ (process), future ADP cycle closes

## Decided
- User (engineer/PO) permanently waived condition (2) of the Rocco writeback hard
  gate: "no need to await my yes ever". The writeback now fires on merge to main
  alone. AGENTS.md was amended the same day to codify this, so future sessions
  must not re-ask for confirmation after a merge.
- The gate that remains: writeback is still NEVER preemptive — an unmerged PR,
  awaiting review, or a locally finished cycle is not a trigger. Only merge to main.

## Watch out
- Rocco channel mechanics live in `~/.local/bin/discord-relay.sh`
  (`discord-relay.sh --file /path/to/writeback.txt "summary"`, auto-prefixes
  `[palm_sync_4_mac]`, auto-mentions the Hermes bot, auto-attaches long bodies).
  AGENTS.md references a `tell-rocco` skill that does not exist in the installed
  skill set — use the relay script directly.
