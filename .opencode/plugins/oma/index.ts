/**
 * oh-my-agent — opencode V2 plugin bridge.
 *
 * V2 port of oma.ts, the V1 bridge installed by oh-my-agent's
 * `installOpencodePlugin`. opencode v2 loads local plugins from directories
 * under `.opencode/plugins/` and requires a V2 entrypoint (`Plugin.define`
 * with id + setup); V1 handler maps do not run in v2 at all
 * (opencode.ai/v2/docs/build/plugins/migrate-v1). This file follows the
 * auto-discovery filename convention (`server`, else `index`), so the
 * directory loads with no `plugins` entry in opencode.jsonc. The V1-era
 * `plugin: ["./plugins/oma/oma.ts"]` registration this replaces is rejected
 * by v2 ("configured plugin path must be a directory") — see PalmSync4Mac
 * issue #44. oma.ts itself is left in place untouched: it is the installer's
 * SSOT copy, and the auto-discovery convention ignores non-entrypoint files.
 *
 * The bridge design is unchanged from the V1 original: opencode does NOT
 * register settings-file hooks like the other vendors. It loads in-process
 * TypeScript plugins, so this thin shim maps opencode lifecycle events onto
 * oma's existing, vendor-agnostic core scripts via subprocess. All matching
 * logic stays in the core scripts. They are not recognised as an opencode
 * vendor (no `.opencode` case in the shared `inferVendorFromScriptPath`), so
 * they resolve to the `claude` output dialect; extraction stays defensive
 * (top-level OR `hookSpecificOutput`) so a dialect shift does not silently
 * break the bridge. runCore fails OPEN (null) on any error — a broken hook
 * must never block the agent, with one deliberate exception noted below.
 *
 * V1→V2 event mapping (per the migration guide):
 *
 *   ctx.session.hook("prompt")        ← chat.message (UserPromptSubmit)
 *       Reads event.prompt.text — NEVER mutates it: prompt-hook edits become
 *       the canonical persisted user input. Runs keyword-detector (workflow
 *       activation) + skill-injector, and stashes the concatenated context
 *       per session (keyed by sessionID) for the context hook. The sessionID
 *       is forwarded so persistent-mode activation writes session-scoped
 *       state (an unresolved id would refuse to persist).
 *
 *   ctx.session.hook("context")       ← experimental.chat.system.transform
 *       Peeks (non-consuming) the context stashed by the prompt hook for
 *       event.sessionID and pushes it onto event.system. The stash is
 *       refreshed (or cleared) every prompt, so re-injection across model
 *       calls in a turn is harmless and an ordering race cannot permanently
 *       drop context.
 *
 *   ctx.tool.hook("execute.before")   ← tool.execute.before (bash only)
 *       Runs scm-guard first — throwing is opencode's documented block
 *       mechanism and is the ONE deliberate non-fail-open path (a likely-
 *       secret `git add` must not proceed). Then runs test-filter on the
 *       bash command and writes any rewrite back onto event.input.command.
 *       Non-bash tools pass through unchanged. Known upstream caveat
 *       inherited from V1: plugin hooks may not intercept subagent tool
 *       calls, so the guard covers the primary agent only.
 *
 *   ctx.event.subscribe("session.idle") ← Stop (BEST-EFFORT / re-entrant)
 *       Runs persistent-mode. If it returns a block decision, the workflow
 *       is still active: re-enter the loop by posting the block reason as a
 *       new prompt via ctx.session.prompt. Best-effort — every step is
 *       wrapped so a failure can never throw into opencode. persistent-mode's
 *       own reinforcement cap (5) is the primary terminator; the per-session
 *       consecutive-idle counter is a runaway backstop only.
 */

import { Plugin } from "@opencode/plugin";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

/** Absolute path to a core script copied next to this bridge at install time. */
function corePath(script: string): string {
  return fileURLToPath(new URL(`./${script}`, import.meta.url));
}

/**
 * Run an oma core hook script as a subprocess: feed it JSON on stdin, parse
 * its JSON stdout. Fail-open (returns null) on any error — a broken hook must
 * never block the agent. Spawns with `cwd` = the plugin's location directory
 * so the core scripts resolve the project (git) root the same way they do
 * for every other vendor. Non-zero exit (persistent-mode blocks with exit 2)
 * is expected: stdout is still captured and parsed. `bun` is expected on
 * PATH (homebrew: /opt/homebrew/bin/bun; verified resolvable inside nono).
 */
function runCore(
  script: string,
  payload: Record<string, unknown>,
  cwd: string,
): Record<string, unknown> | null {
  try {
    const res = spawnSync("bun", [corePath(script)], {
      input: JSON.stringify(payload),
      cwd,
      encoding: "utf-8",
      timeout: 5000,
      env: process.env,
    });
    const out = (res.stdout ?? "").trim();
    if (!out) return null;
    return JSON.parse(out) as Record<string, unknown>;
  } catch {
    return null;
  }
}

/**
 * Extract injected context from a prompt-hook (keyword-detector / skill-
 * injector) result. The core scripts emit the `claude` dialect, which carries
 * `additionalContext` both at the top level and under `hookSpecificOutput`;
 * read either so a dialect change does not silently drop context.
 */
function extractAdditionalContext(
  out: Record<string, unknown> | null,
): string | null {
  if (!out) return null;
  if (typeof out.additionalContext === "string" && out.additionalContext) {
    return out.additionalContext;
  }
  const hso = out.hookSpecificOutput;
  if (hso && typeof hso === "object") {
    const nested = (hso as Record<string, unknown>).additionalContext;
    if (typeof nested === "string" && nested) return nested;
  }
  return null;
}

/**
 * Extract the rewritten command from a test-filter (PreToolUse) result. The
 * `claude` dialect nests it under `hookSpecificOutput.updatedInput.command`;
 * a top-level `updatedInput.command` is also accepted for dialect resilience.
 */
function extractUpdatedCommand(
  out: Record<string, unknown> | null,
): string | null {
  if (!out) return null;
  const readCommand = (v: unknown): string | null => {
    if (v && typeof v === "object") {
      const cmd = (v as Record<string, unknown>).command;
      if (typeof cmd === "string" && cmd) return cmd;
    }
    return null;
  };
  const direct = readCommand(out.updatedInput);
  if (direct) return direct;
  const hso = out.hookSpecificOutput;
  if (hso && typeof hso === "object") {
    return readCommand((hso as Record<string, unknown>).updatedInput);
  }
  return null;
}

/**
 * Extract a PreToolUse deny reason from an scm-guard result. The core script
 * emits the `claude` dialect (`hookSpecificOutput.permissionDecision: "deny"`
 * + `permissionDecisionReason`); a top-level `permission: "deny"` +
 * `user_message`/`reason` is also accepted for dialect resilience.
 */
function extractDenyReason(out: Record<string, unknown> | null): string | null {
  if (!out) return null;
  const hso = out.hookSpecificOutput;
  if (hso && typeof hso === "object") {
    const h = hso as Record<string, unknown>;
    if (h.permissionDecision === "deny") {
      return typeof h.permissionDecisionReason === "string" &&
          h.permissionDecisionReason
        ? h.permissionDecisionReason
        : "Blocked by oma scm-guard.";
    }
  }
  if (out.permission === "deny" || out.decision === "deny") {
    const reason = out.user_message ?? out.reason;
    return typeof reason === "string" && reason
      ? reason
      : "Blocked by oma scm-guard.";
  }
  return null;
}

/**
 * `opencode run "<prompt>"` delivers the prompt text wrapped in literal
 * double quotes, which defeats keyword detection anchored at the prompt
 * start. A prompt that is entirely enclosed in one matching pair of quotes
 * is that CLI artifact — unwrap exactly one pair; interior quotes are
 * untouched. Local only: the unwrapped value is never written back to the
 * event, because prompt-hook edits persist as the canonical user input.
 */
function stripWrappingQuotes(text: string): string {
  const t = text.trim();
  if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
    return t.slice(1, -1);
  }
  return t;
}

// ── Per-session bridge state ──────────────────────────────────
//
// The plugin is loaded once per server process, so module-level maps persist
// across a session's hook invocations. Both maps are keyed by the opencode
// sessionID and bounded so a long-lived server cannot leak memory across
// many sessions.

const MAX_TRACKED_SESSIONS = 256;

/**
 * Context computed on the prompt hook, awaiting injection by the context
 * hook. Overwrite-per-session: each prompt replaces the entry (with `""`
 * when nothing matched), so the context hook never injects stale context
 * and a peek does not need to consume.
 */
const pendingContext = new Map<string, string>();

/**
 * Consecutive session.idle re-entries per session, reset by any new prompt.
 * A runaway backstop only — persistent-mode's reinforcement cap terminates
 * the loop first under normal operation.
 */
const idleReentryCount = new Map<string, number>();
const MAX_CONSECUTIVE_IDLE_REENTRIES = 50;

/** Set a bounded map entry, evicting the oldest key when over capacity. */
function setBounded<V>(map: Map<string, V>, key: string, value: V): void {
  if (map.has(key)) map.delete(key);
  map.set(key, value);
  while (map.size > MAX_TRACKED_SESSIONS) {
    const oldest = map.keys().next().value;
    if (oldest === undefined) break;
    map.delete(oldest);
  }
}

export default Plugin.define({
  id: "oma",
  async setup(ctx) {
    const cwd = ctx.location.directory ?? process.cwd();

    // ctx.session.hook("prompt") ← chat.message (UserPromptSubmit)
    await ctx.session.hook("prompt", async (event) => {
      const sessionID = event.sessionID ?? "";
      // A genuine user turn resets the runaway idle backstop.
      if (sessionID) idleReentryCount.delete(sessionID);

      const prompt = stripWrappingQuotes(event.prompt.text ?? "");
      const payload = {
        prompt,
        cwd,
        sessionId: sessionID,
        hook_event_name: "UserPromptSubmit",
      };

      const parts: string[] = [];
      const kd = extractAdditionalContext(
        runCore("keyword-detector.ts", payload, cwd),
      );
      if (kd) parts.push(kd);
      const si = extractAdditionalContext(
        runCore("skill-injector.ts", payload, cwd),
      );
      if (si) parts.push(si);

      // Overwrite per session — even with "" — so the context hook reflects
      // this turn's detection and never re-injects a previous turn's context.
      if (sessionID) setBounded(pendingContext, sessionID, parts.join("\n\n"));
    });

    // ctx.session.hook("context") ← experimental.chat.system.transform
    await ctx.session.hook("context", (event) => {
      const text = pendingContext.get(event.sessionID);
      if (text) event.system.push({ type: "text", text });
    });

    // ctx.tool.hook("execute.before") ← PreToolUse (bash only)
    await ctx.tool.hook("execute.before", async (event) => {
      if (event.tool !== "bash") return;
      const input = event.input as { command?: string } | undefined;
      const command = input?.command;
      if (typeof command !== "string" || !command) return;

      const denyReason = extractDenyReason(
        runCore(
          "scm-guard.ts",
          {
            tool_name: "Bash",
            tool_input: { command },
            cwd,
            hook_event_name: "PreToolUse",
          },
          cwd,
        ),
      );
      if (denyReason) throw new Error(denyReason);

      const updated = extractUpdatedCommand(
        runCore(
          "test-filter.ts",
          {
            tool_name: "Bash",
            tool_input: { command },
            cwd,
            hook_event_name: "PreToolUse",
          },
          cwd,
        ),
      );
      if (updated && input) {
        input.command = updated;
      }
    });

    // ctx.event.subscribe("session.idle") ← Stop (BEST-EFFORT / re-entrant)
    const controller = new AbortController();
    void (async () => {
      try {
        for await (const ev of ctx.event.subscribe({
          types: ["session.idle"],
          signal: controller.signal,
        })) {
          const props = (ev as { properties?: Record<string, unknown> })
            .properties;
          const sessionID =
            (props as { sessionID?: string } | undefined)?.sessionID ??
            (ev as { sessionID?: string }).sessionID;
          if (!sessionID) continue;

          const count = idleReentryCount.get(sessionID) ?? 0;
          if (count >= MAX_CONSECUTIVE_IDLE_REENTRIES) continue;

          const pm = runCore(
            "persistent-mode.ts",
            { cwd, sessionId: sessionID, hook_event_name: "Stop" },
            cwd,
          );

          if (pm?.decision !== "block") {
            // Workflow complete / not active — clear the backstop counter.
            idleReentryCount.delete(sessionID);
            continue;
          }

          const reason =
            typeof pm.reason === "string" && pm.reason
              ? pm.reason
              : "The active OMA workflow is not complete. Continue executing it.";
          idleReentryCount.set(sessionID, count + 1);

          try {
            await ctx.session.prompt({ sessionID, text: reason });
          } catch {
            // Best-effort re-entry — never throw into opencode.
          }
        }
      } catch {
        // Stream aborted by cleanup or server shutdown — expected, not an error.
      }
    })();

    return () => controller.abort();
  },
});
