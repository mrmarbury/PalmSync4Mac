#!/usr/bin/env sh
# PalmSync4Mac — canonical launch for interactive opencode development
# under the nono sandbox (ps4m profile). All app work (features, debugging,
# docs) runs through this script; only harness/meta work (nono profiles,
# global opencode config) happens outside nono.
#
# --allow-cwd   grant this repo as the sandbox workdir; ps4m sets
#               workdir.access=readwrite, so the whole checkout is
#               writable inside the sandbox.
# --standalone  REQUIRED for containment: opencode starts its own private
#               server INSIDE the sandbox. Without it the TUI would connect
#               to the shared background service on the host (outside the
#               sandbox) and tool execution would escape the sandbox — the
#               session would look sandboxed without being sandboxed.
#
# Future supervisor runs (once the agentic harness exists) boot detached:
#   nono run --allow-cwd --profile ps4m --detach -- opencode --standalone
nono run --allow-cwd --profile ps4m -- opencode --standalone "$@"
