# Rocco channel repaired: tell-rocco skill fixed, discli-nono wrapper replaces relay script

Date: 2026-11-06
Touches: ~/.agents/skills/tell-rocco/SKILL.md, ~/.local/bin/discli-nono, ~/.config/nono/profiles/ps4m.json

## Decided
- Supersedes the "Watch out" guidance in 2026-11-06-writeback-gate-waived.md:
  the `tell-rocco` skill exists, loads automatically, and the writeback channel
  is `discli-nono` — NOT the relay script, which was deleted this session.
- `~/.local/bin/discord-relay.sh` was DELETED because it carried a hardcoded
  plaintext Discord bot token (exposed repeatedly in agent transcripts —
  rotation is an open engineer action). Do not reference or rebuild it.

## How the tell-rocco skill was invisible for weeks
- Its manifest was `SKILL.MD` (uppercase extension) — the only skill in
  `~/.agents/skills/` with wrong casing. opencode skill discovery is
  case-sensitive, so the folder was silently skipped and never surfaced in the
  available-skills list. Fixed by renaming to `SKILL.md`; the rename sits in
  `~/.dotfiles/.agents/skills/tell-rocco/` (commit pending — engineer action).
- `~/.agents` is a symlink to `~/.dotfiles/.agents` (stow-managed): they are
  the same files. Searching "~/.dotfiles/agents" vs "~/.agents" is a false
  dichotomy — there is exactly one skill tree.

## Why raw discli fails in-sandbox (do not re-derive)
- discli's stack is discord.py + aiohttp. aiohttp defaults to trust_env=False,
  so it ignores nono's HTTPS_PROXY and attempts direct sockets to
  discord.com:443 / gateway.discord.gg:443 → EPERM (correct sandbox behavior).
- Enabling trust_env fixes the REST calls, but the gateway websocket resolves
  the proxy per URL scheme and looks for `wss_proxy`, which nono does not
  export. Both are handled by the wrapper at `~/.local/bin/discli-nono`
  (maps wss_proxy=$https_proxy, patches ClientSession trust_env in-process,
  then calls discli's own main()).
- All traffic still flows through nono's CONNECT proxy and domain allowlist —
  the wrapper makes a proxy-blind client proxy-aware; it is NOT a bypass.
- The pipx entry script's shebang is `python -E` (ignores env), so the wrapper
  invokes the venv interpreter directly, resolved via readlink of the
  `~/.local/bin/discli` symlink (survives venv rebuilds).

## nono grant etiquette (engineer correction, 2026-11-06)
- When a grant is missing: ASK for it. Never engineer around the sandbox.
- `read` == `exec` on macOS Seatbelt (there is no separate execute right);
  the read-level grants on ~/.asdf and ~/.bun are what make mix/bun runnable.
- nono mediates on RESOLVED paths: a grant on the ~/.local/bin/discli symlink
  does NOT cover its pipx venv target — grant the venv directory itself.
- Profile edits go live only at opencode restart; `nono why --self` reports the
  LIVE policy. The built-in `user_tools` group grants read on ~/.local/bin
  independent of any profile, so directory listing there stays possible by
  design; the real protection is "no secrets in executable scripts".
- ps4m.json v1.6.0 read grants: `~/.discli`, the discord-cli-agent pipx venv,
  and file grants on `~/.local/bin/discli` + `~/.local/bin/discli-nono` only.

## Open items
- RESOLVED (engineer edit, same day): tell-rocco SKILL.md now carries a critical
  remark in "How It Works" — "Use `discli-nono` instead to communicate with Rocco
  from a nono sandbox; `discli` won't work in that case." One authoritative note
  at the top beats mass-substitution in the examples, and the examples stay
  correct for unsandboxed use. Deliberately NOT rewritten wholesale.
- Still stale in tell-rocco SKILL.md: the "Fallback: curl relay script" section
  (~9 lines at the end) advertises the DELETED ~/.local/bin/discord-relay.sh —
  remove it next time the file is open.
- Rotate the exposed relay bot token (engineer).
- Commit the SKILL.MD → SKILL.md rename in the dotfiles (engineer).
