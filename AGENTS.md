# codeplow - Agent Guide

This file gives AI coding agents (Claude Code, Cursor, Codex, etc.) the context they need to work in this repository.

## What this repo is

codeplow is a **plugin marketplace** for AI coding agents. It bundles installable plugins (currently one: `obsidian-kb`) with native support for three platforms:

- Claude Code (`.claude-plugin/`)
- Cursor (`.cursor-plugin/`)
- Codex CLI (`.codex-plugin/` + `.agents/plugins/`)

Users install the marketplace once and get every plugin it contains.

## Why the plugins here exist

Understanding the product intent matters when editing skills - every design choice traces back to one of these problems.

- **`obsidian-kb`** fights two failure modes of AI coding workflows:
  - **Context rot between sessions.** Long sessions degrade - decisions made at token 2,000 get lost by token 50,000; starting a new session resets everything, including the decisions. The `/kb-offboard` → `/kb-onboard` loop externalizes the thread into a markdown handoff so new sessions start fresh *and* briefed.
  - **Doc rot inside the repo.** Markdown drifts from code, especially on AI-written projects where the agent generates docs that match a commit and nothing updates them later. `/kb-init` and `/kb-audit` build/refresh a KB from live code and flag every stale claim in existing markdown with `file:line` evidence.
- **Category positioning.** Not a vector DB (that's claude-mem, Mem0, Zep - different problem: chat retrieval). Not a CLAUDE.md replacement (too shallow by design). Closest sibling is Cline Memory Bank - also markdown - but Cline-only, fixed schema, no audit. See the top-level `README.md` "How it compares" section for the full matrix.
- **Ownership principle.** Vaults are plain markdown inside the user's project by default. Committable, grep-able, editable by hand, zero lock-in. This is load-bearing - if you're changing a skill and the change pushes content into a proprietary format or an opaque store, stop and reconsider.

## Repository layout

Flat - each plugin is a top-level folder at repo root (following the [ComposioHQ/awesome-claude-plugins](https://github.com/ComposioHQ/awesome-claude-plugins) pattern). No `plugins/` wrapper.

```
codeplow/
├── README.md, INSTALL.md, UNINSTALL.md, AGENTS.md, LICENSE, .gitignore
├── .claude-plugin/marketplace.json       # Claude Code marketplace manifest
├── .cursor-plugin/marketplace.json       # Cursor marketplace manifest
├── .agents/plugins/marketplace.json      # Codex marketplace manifest (open standard)
│
├── obsidian-kb/                          # Plugin - lives at root
│   ├── .claude-plugin/plugin.json        # Claude Code plugin manifest
│   ├── .cursor-plugin/plugin.json        # Cursor plugin manifest
│   ├── .codex-plugin/plugin.json         # Codex plugin manifest
│   ├── commands/                         # Thin slash-command wrappers (Claude Code + Cursor)
│   ├── skills/                           # Source of truth - all platforms read SKILL.md
│   ├── scripts/                          # Plugin-bundled scripts (e.g. register-vault.sh)
│   └── README.md                         # Plugin-level storefront
│
├── <future-plugin>/                      # Future plugins land as siblings at root
│
└── scripts/                              # Repo-level installers (install.sh/ps1, uninstall.sh/ps1)
```

Every marketplace-installable item is a full plugin - even "skill-only" or "hook-only" plugins sit at root with their own `.claude-plugin/plugin.json`. Folder names are product-named (like `obsidian-kb`, not `plugins/`), so a GitHub scroll through the root reveals what's installable at a glance.

## Key architectural conventions

### Skills are the source of truth; commands are thin wrappers

Every plugin has full workflow content inside `skills/<name>/SKILL.md`. Slash commands in `commands/<name>.md` are short files that just tell the agent to follow the matching skill - they exist only because Claude Code and Cursor support native slash commands. Codex reads the skills directly.

**If you change a workflow, update the SKILL.md - not the command.** Commands should stay as thin redirects.

### Three platform manifests per plugin

Every plugin ships `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, and `.codex-plugin/plugin.json`. They all point to the same `skills/` and (where applicable) `commands/` directories. Keep descriptions and version numbers in sync across all three.

### Three marketplace manifests per repo

`.claude-plugin/marketplace.json`, `.cursor-plugin/marketplace.json`, and `.agents/plugins/marketplace.json`. When adding a new plugin to the marketplace, update all three.

### Version bumps happen in 7 places

A single version bump touches: 3 marketplace manifests + 3 plugin manifests (per plugin) + `scripts/install.sh`. Use `sed` to update them together:

```bash
sed -i '' 's/"version": "OLD"/"version": "NEW"/g' \
  .claude-plugin/marketplace.json \
  .cursor-plugin/marketplace.json \
  .agents/plugins/marketplace.json \
  <plugin-name>/.claude-plugin/plugin.json \
  <plugin-name>/.cursor-plugin/plugin.json \
  <plugin-name>/.codex-plugin/plugin.json \
  scripts/install.sh
```

## When working in this repo

### Testing changes locally

The repo itself can be used as a marketplace:

```bash
# Register this repo as a local marketplace (run from inside the cloned repo)
claude plugin marketplace add "$PWD"

# Install a plugin from it
claude plugin install obsidian-kb@codeplow

# After any change, bump version and update
claude plugin update obsidian-kb@codeplow
```

### Testing vault-modifying skills

**Never test `/kb-init` or `/kb-scaffold` against real user vaults** - vaults you actually use for project knowledge can get polluted by test runs. Test against:

1. The codeplow repo itself - it has real code the skills can explore.
2. A temp directory (`/tmp/codeplow-test-project`) - for destructive tests.

### Obsidian CLI gotchas (learned the hard way)

**1. `vault=` is ignored by the CLI (v1.12.7 verified).** Every read/write command silently targets the currently active Obsidian vault, regardless of what you pass for `vault=`. Demonstrated by running `obsidian read vault="Vault A" file="Home"` while Vault B is active - the CLI reads from Vault B even though the argument named Vault A.

**The fix isn't "avoid the CLI" - it's "switch the active vault first."** The `obsidian://open?vault=<name>` URI handler reliably makes a specific vault active. After switching, all CLI commands work correctly on that vault.

Every action skill runs the **Vault Access Sequence** after resolution:
  1. Check active vault: `timeout 3 obsidian vault info=name`
  2. If wrong, switch: `open "obsidian://open?vault=<ENCODED>"` + `sleep 3`
  3. Verify and set `CLI_MODE=1` (success) or `CLI_MODE=0` (fallback to filesystem)

**Operation split:**
- Reads / search / verification: CLI (when `CLI_MODE=1`), else filesystem
- Writes: always filesystem (heredoc) - safer for YAML + multi-line content than CLI escaping
- Link integrity: `obsidian unresolved` / `obsidian orphans` post-write (CLI_MODE=1)

See `${CLAUDE_PLUGIN_ROOT}/obsidian-kb/skills/obsidian-kb/SKILL.md` → "Vault Access Sequence" and "Operation Split" for canonical patterns.

**2. No `vault:create` command.** Running `obsidian create vault="NewName" path="..."` with an unregistered vault name does NOT create a new vault - it silently falls back to the currently active vault and auto-renames on collision. This is a special case of (1), but worth calling out separately.

**3. Weak-signal vault resolution is a trap.** Use strict priority: path overlap → frontmatter `project_path` → strong word-boundary name match → STOP and ask. Resolution captures BOTH name and absolute path; everything downstream uses the path.

**4. Subagents must write to `$VAULT_PATH`.** If a subagent writes a note without the `$VAULT_PATH/` prefix, the note lands in the agent's CWD instead of the vault. Pass the literal path into every subagent prompt.

**5. The Obsidian CLI is disabled by default.** Since v1.12 the CLI ships with the app, but it's OFF until the user enables it via **Settings → General → scroll to bottom → toggle "Command Line Interface"**. If `command -v obsidian` returns empty but `/Applications/Obsidian.app` (or equivalent) exists, the fix isn't "install Obsidian" - it's "walk the user through the toggle." The preflight check in `skills/obsidian-kb/SKILL.md` distinguishes these cases.

**Correct vault creation sequence:**

1. `mkdir -p "/abs/path/.obsidian"` - the `.obsidian/` subfolder is the vault marker
2. Write scaffold files directly with shell heredocs (not via `obsidian create`)
3. Register with Obsidian - either via UI ("Open folder as vault") or by editing `~/Library/Application Support/obsidian/obsidian.json` and cold-restarting the app

See `obsidian-kb/skills/kb-scaffold/SKILL.md` for the full sequence (and `obsidian-kb/scripts/register-vault.sh` for the bundled automation script).

### Referencing bundled scripts from skills

When a skill needs to invoke a bundled script, **always use `${CLAUDE_PLUGIN_ROOT}`** - Claude Code sets this env var to the absolute path of the installed plugin directory at runtime. For cross-platform coverage, resolve it as:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${CURSOR_PLUGIN_ROOT:-${CODEX_PLUGIN_ROOT:-}}}"
```

**Never** use `<plugin-root>` or `<path>` placeholders in skill text. Agents see angle brackets and skip the step instead of resolving them. Concrete env vars or absolute paths only.

### Dispatching subagents from skills

Follow the patterns in `superpowers:subagent-driven-development`. The core idea: every subagent ends its response with a status line (`STATUS: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED`), and the main agent inspects statuses before acting on output.

This catches the subtle failure mode where a subagent gets a tool denied mid-investigation and returns partial data that *looks* complete. Without the status, the main agent can't distinguish "found nothing" from "tried but blocked" - so explicit status is mandatory.

See `${CLAUDE_PLUGIN_ROOT}/obsidian-kb/skills/kb-init/SKILL.md` for a worked example (Step 4 "Universal Instructions" + Step 4b). When in doubt, consult `superpowers:subagent-driven-development` directly.

## Contributing a new plugin

1. Create `<your-plugin-name>/` at repo root (sibling to `obsidian-kb/`, NOT under `plugins/`):
   - `.claude-plugin/plugin.json`
   - `.cursor-plugin/plugin.json`
   - `.codex-plugin/plugin.json`
   - `skills/<skill-name>/SKILL.md` (one or more)
   - `commands/<command-name>.md` (thin wrappers, one per user-invokable workflow - optional; skip if the plugin doesn't need slash commands)
   - `README.md` (plugin-level storefront)
2. Add an entry to the three marketplace manifests at the repo root:
   - `.claude-plugin/marketplace.json`
   - `.cursor-plugin/marketplace.json`
   - `.agents/plugins/marketplace.json`
   The entry's `source` is `./<your-plugin-name>` (relative to repo root).
3. Update `scripts/install.sh` and `scripts/install.ps1` if the plugin has special installation needs.
4. Update the top-level `README.md` to list the new plugin alongside `obsidian-kb`.
5. Bump the version in all relevant places (3 marketplace manifests + 3 plugin manifests + install scripts that embed the version).

### Skill-only and hook-only plugins

If your plugin contains just one skill or just one hook, it still lives as a full plugin at repo root - no separate folder hierarchy. The plugin manifest is small, the `skills/` folder has one entry, and everything else can be empty. The marketplace only cares that it's a valid plugin.

## Style notes

- Use imperative, second-person voice in skills ("Run this command" not "The agent should run...").
- Explain WHY, not just WHAT - future agents reading the skill benefit from reasoning.
- Avoid `MUST`/`ALWAYS` in all caps unless genuinely critical. Prefer concrete examples.
- Start skill files with a clear `---` YAML frontmatter block (`name`, `description`).
