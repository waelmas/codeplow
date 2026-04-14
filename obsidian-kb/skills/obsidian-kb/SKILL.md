---
name: obsidian-kb
description: >
  Awareness skill for the obsidian-kb plugin. Nudges agents to suggest kb-init, kb-scaffold,
  kb-audit, kb-onboard, kb-offboard, and kb-graph at the right moments - session start, session
  end, vault initialization, doc freshness checks, visualization. Use when the user mentions
  session handoffs, project knowledge bases, onboarding, wrapping up, continuing previous work,
  initializing a vault, auditing stale docs, populating or enriching docs, visualizing the vault
  graph, or types any /kb-* command.
---

# obsidian-kb - Project Knowledge Base Lifecycle

This plugin gives AI coding agents persistent memory across sessions via Obsidian vaults. It provides six skills (also available as slash commands in Claude Code and Cursor):

| Skill / Command | When to trigger |
|-----------------|-----------------|
| `kb-init` / `/kb-init` | **Full initialization**: scaffold + populate vault with codebase analysis + audit existing project markdown for stale claims. Use when user wants project memory set up properly from the start. |
| `kb-scaffold` / `/kb-scaffold` | **Empty scaffold only** (no codebase analysis). Use when user explicitly wants to manage content manually. Most users should use /kb-init. |
| `kb-audit` / `/kb-audit` | **Re-runnable doc freshness audit.** Scan project markdown against current code, flag stale claims with file:line evidence. Use for quarterly doc refreshes, before major rewrites, or when user says "are our docs still accurate?". |
| `kb-onboard` / `/kb-onboard` | Start of a session when a vault exists for this project. |
| `kb-offboard` / `/kb-offboard` | End of a session, user says "done", "wrapping up", "that's it". |
| `kb-graph` / `/kb-graph` | User wants to visualize the knowledge base as a graph in Obsidian. |

## When to Nudge

**Do suggest** `kb-onboard` early in a session if you detect a vault exists for the current project. A simple "This project has a knowledge vault - want me to trigger kb-onboard (or run `/kb-onboard`) to see what happened last session?" is enough.

**Do suggest** `kb-offboard` when the user signals they're wrapping up. Don't wait for them to ask - they may not know the skill exists.

**Do suggest** `kb-init` if you're doing meaningful work on a project (architecture decisions, multi-file changes, complex debugging) and no vault exists. Don't suggest it for trivial one-off tasks. `kb-init` is the usual choice - it scaffolds *and* populates + audits in one go.

**Do suggest** `kb-scaffold` only if the user explicitly says they want just the empty folder structure - "skip the codebase analysis" or similar. Most users should go through `kb-init`.

**Do suggest** `kb-audit` when the user asks about doc accuracy, says "our docs are probably out of date", plans a major refactor, or wants to do a periodic check. Also great standalone pitch: "run `/kb-audit` on any repo with markdown - you'll find out how much of it still matches the code."

**Do suggest** `kb-graph` after a successful `kb-init`, or when the user asks to visualize the vault, see connections between notes, or explore the knowledge base visually. Also useful to show off the vault's richness after meaningful growth.

**One-command chains**: users should only need to remember one skill; the agent handles sequencing. `/kb-init` already handles the "no vault yet" case by chaining through `kb-scaffold` automatically. If someone runs `/kb-graph` with no vault, offer to chain `kb-init` → `kb-graph`.

**Don't** auto-run any of these skills. Always suggest, never force.

**Don't** suggest these skills if the user is clearly just asking a quick question or doing something minor.

## Platform Notes

- **Claude Code / Cursor**: Users can invoke as slash commands: `/kb-init`, `/kb-scaffold`, `/kb-audit`, `/kb-onboard`, `/kb-offboard`, `/kb-graph`
- **Codex CLI**: No native slash commands - users type the command-like form (e.g., "/kb-onboard") or express intent naturally ("catch me up on this project"). Both should trigger the matching skill.

## Vault Resolution Algorithm

All action skills must identify the correct vault **before** performing any operation. This algorithm uses a **strict priority order with stop-at-first-match**. If no tier produces a clear match, the agent must stop and ask the user - never default to "whichever vault".

### Why strict priority matters

**The Obsidian CLI (verified against v1.12.7) ignores the `vault=` argument** - it always operates on the currently active vault in the Obsidian app. This means we **cannot scope operations through the CLI**. Every cross-vault operation must go through the filesystem directly (see "Filesystem-first operations" below).

If we resolve the wrong vault or leave it ambiguous, our reads/writes hit whatever vault happens to be open in Obsidian - which could be an unrelated project. This is how a test run of `/kb-onboard` ended up reading a handoff from an unrelated project.

### Capture BOTH name and absolute path during resolution

```bash
timeout 5 obsidian vaults verbose
# Output format: <name>\t<absolute-path>
# Example:       MyProject KB\t/Users/<you>/.../MyProject KB
```

After the tiers below pick a vault, capture **both** fields:

```bash
VAULT_NAME="MyProject KB"
VAULT_PATH="/Users/<you>/projects/myproject/MyProject KB"
```

All subsequent operations use `$VAULT_PATH` directly - do not rely on the CLI for anything scoped to a specific vault.

### Priority order (stop at first match)

#### Tier 1 - User-specified vault (command argument)

If the user passed an argument that looks like a vault name, fuzzy-match it against `obsidian vaults verbose`:
- Exactly one match → use it (confirm by name in the first reply).
- Multiple matches → list them, ask which.
- Zero matches → list all vaults, ask which to use.

Don't fall through to other tiers if the user was explicit.

#### Tier 2 - Path overlap (strongest automated signal)

Find vaults whose filesystem path satisfies either:
- The vault path is inside `$PWD` (e.g., `$PWD/My KB`), OR
- `$PWD` is inside the vault path (when working inside a vault-rooted project).

If exactly one vault matches → use it.
If multiple match (rare), prefer the vault whose path is a child of `$PWD`.

Do NOT treat a parent-directory match (e.g., your home folder contains many vaults) as overlap - that's too loose and will false-positive.

#### Tier 3 - Frontmatter `project_path` match

For each vault, check if a root-level note (`Index.md` or `README.md`) has a `project_path` YAML property whose value equals `$PWD`. If exactly one vault matches → use it.

#### Tier 4 - Strong name match

Normalize the project dir name (`basename "$PWD"`, lowercase, strip hyphens/underscores/spaces) and compare against each vault's normalized name. A match counts as **strong** only when:

- One normalized string is a **word-boundary substring** of the other (e.g., `myproject` ↔ `myprojectkb`, `webapp` ↔ `webappkb`), not just a few shared letters.
- Exactly one such strong match exists among the candidates.

If exactly one strong name match → use it. Otherwise fall through.

Weak matches (partial substrings, shared prefixes only) do NOT count here - they go to Tier 5.

#### Tier 5 - STOP and ask the user

If no tier produced a clear match, **do not default to any vault**. Tell the user:

> "I don't see a vault that clearly matches this project (`$PWD`). Your options:
>
> 1. Use one of these existing vaults (name one): `<list>`
> 2. Run `/kb-init` to create a new vault for this project
> 3. Cancel
>
> Which would you like?"

Do not guess. Do not search across vaults for handoff files. Do not fall back to the currently active Obsidian vault. Wait for the user's choice.

### After resolution: switch Obsidian's active vault, then operate

The Obsidian CLI ignores `vault=` - it always operates on the currently **active** vault. So we make the resolved vault active first (via the `obsidian://` URI handler, which does work), then use the CLI for reads and verification. Writes still go through the filesystem for safety (YAML frontmatter + multi-line content is error-prone to shell-escape).

## Vault Access Sequence

Every action skill runs this sequence after vault resolution, before any reads/writes:

```bash
# After Step 1 resolution, you have:
#   VAULT_NAME="MyProject KB"
#   VAULT_PATH="/Users/<you>/.../MyProject KB"

# Step A: Check if it's already active
CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)

# Step B: Switch if needed
if [[ "$CURRENT" != "$VAULT_NAME" ]]; then
  # URL-encode spaces (simple approach works for vault names)
  ENCODED=$(printf '%s' "$VAULT_NAME" | sed 's/ /%20/g')
  # macOS
  open "obsidian://open?vault=${ENCODED}"
  # Linux: xdg-open "obsidian://open?vault=${ENCODED}"
  # Windows: cmd.exe /c "start obsidian://open?vault=${ENCODED}"
  sleep 3
  CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
fi

# Step C: Verify and choose mode
if [[ "$CURRENT" == "$VAULT_NAME" ]]; then
  CLI_MODE=1
  # CLI reads/verification work correctly now
else
  CLI_MODE=0
  # Switch didn't stick - fall back to filesystem-only
  echo "Note: could not switch Obsidian's active vault. Using filesystem-only mode." >&2
fi
```

After this, you know whether CLI queries target the right vault (`CLI_MODE=1`) or you need to fall back to pure filesystem (`CLI_MODE=0`). Both modes work - CLI mode just adds indexed search and link verification.

## Operation Split

| Operation | Preferred tool | Reason |
|-----------|----------------|--------|
| List files / folders | CLI (`obsidian files`, `obsidian folders`) post-switch, or `find` always | CLI uses Obsidian's index |
| Search content | **CLI (`obsidian search`, `obsidian search:context`)** post-switch | Indexed + fuzzy; beats raw grep. Fall back to `grep -r` if `CLI_MODE=0`. |
| Read single note | `cat "$VAULT_PATH/path.md"` | Direct, deterministic; no CLI overhead |
| Write note | **Filesystem (`mkdir -p` + heredoc)** | Safer for YAML frontmatter + multi-line markdown than CLI escaping |
| Append to note | Filesystem (`printf ... >>`) | Same |
| Verify wiki-links after writes | **CLI (`obsidian unresolved`, `obsidian orphans`)** post-switch | Catches broken `[[Link]]` targets; only works on indexed vault |
| Check backlinks | CLI (`obsidian backlinks`) post-switch | Uses Obsidian's index |
| List vaults | CLI (`obsidian vaults verbose`) | Always works; not vault-scoped |

### Canonical filesystem fallbacks

When `CLI_MODE=0` (or as the default for writes), these filesystem equivalents always work:

```bash
# List
find "$VAULT_PATH" -type f -name "*.md" -not -path "*/.obsidian/*" | sort
find "$VAULT_PATH" -type d -not -path "*/.obsidian/*" | sort

# Search
grep -r -l -i "query" "$VAULT_PATH" --include="*.md" --exclude-dir=.obsidian

# Read
cat "$VAULT_PATH/relative/path.md"

# Write
mkdir -p "$(dirname "$VAULT_PATH/relative/path.md")"
cat > "$VAULT_PATH/relative/path.md" <<'NOTE_EOF'
---
type: architecture
---
# Title
...
NOTE_EOF

# Append
printf '\n- [[new-link]]\n' >> "$VAULT_PATH/Index.md"
```

## Post-write verification (CLI_MODE=1 only)

After any kb-init populate or batch of writes, use the CLI to verify wiki-link integrity:

```bash
# Broken [[wiki-links]] that don't resolve to any file
timeout 5 obsidian unresolved verbose

# Notes with no incoming links (may need linking from Index or elsewhere)
timeout 5 obsidian orphans
```

Surface these to the user as optional cleanup - don't block on them. A vault where kb-init populated 8 notes and 3 have no incoming links yet isn't broken; it just means the Index or cross-references are thin. The user can fix or ignore.

## Confirmation line (always)

After resolution, state clearly in your first reply to the user which vault you picked and why:

> "Using vault **`<Vault Name>`** at `<path>` (matched via `<tier that matched>`). Say 'wrong vault' if I should pick a different one."

This gives the user a fast abort path if something went sideways.

### Save the mapping (on write operations only)

After resolution succeeds on write-intensive skills (`kb-init`, `kb-scaffold`, `kb-offboard`), save the mapping so Tier 3 fast-paths next time. Prefer `CLI_MODE=1` path since Obsidian can validate the YAML; fall back to direct file edit if the CLI isn't available:

```bash
if [[ "$CLI_MODE" == "1" ]]; then
  # CLI works now because we switched the active vault to $VAULT_NAME
  timeout 5 obsidian property:set path="Index.md" name="project_path" value="$PWD"
else
  # Filesystem fallback: edit the frontmatter directly.
  # If Index.md has no frontmatter, prepend one. If it does, upsert the key.
  python3 - "$VAULT_PATH/Index.md" "$PWD" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
pwd = sys.argv[2]
text = p.read_text() if p.exists() else ""
fm_re = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
m = fm_re.match(text)
if m:
    body = text[m.end():]
    front = m.group(1)
    if re.search(r"(?m)^project_path:", front):
        front = re.sub(r"(?m)^project_path:.*$", f"project_path: {pwd}", front)
    else:
        front = front.rstrip() + f"\nproject_path: {pwd}"
    text = f"---\n{front}\n---\n{body}"
else:
    text = f"---\nproject_path: {pwd}\n---\n\n" + text
p.write_text(text)
PYEOF
fi
```

Don't write mappings during read-only operations (`kb-onboard`, `kb-graph`) unless the user explicitly asks.

### Key principles

- **Path overlap beats everything else that isn't an explicit user choice.** A vault inside this project's directory is almost certainly this project's vault.
- **Name matches must be strong.** "Shares a few letters" is not a match. Word-boundary or full-name matches only.
- **When in doubt, ask - never default.** The cost of a one-line confirmation question is low; the cost of silently reading the wrong vault is high.
- **Switch the active vault before CLI commands; use filesystem paths for writes.** The CLI's `vault=` argument is cosmetic - only the active vault matters for reads/writes. Writes always go through `$VAULT_PATH` + heredoc to avoid escape issues.

## CRITICAL SAFETY RULES

### Rule 1: Never use npm/npx for Obsidian

```
The obsidian CLI is a SYSTEM BINARY: `obsidian help`
There is NO official npm package for it.
NEVER install or run npm/npx "obsidian" packages - they are third-party
and potentially malicious.
```

### Rule 2: Always wrap obsidian commands with `timeout`

Wrap **every** `obsidian` invocation with a `timeout` prefix. That includes quick-looking ones that might still hang on an unresponsive Obsidian instance:

```bash
timeout 5 obsidian vaults verbose          # yes
timeout 3 obsidian vaults                  # yes
timeout 3 obsidian help                    # yes
timeout 10 obsidian create vault="X" ...   # yes, longer budget for writes
timeout 15 obsidian create vault="X" ...   # yes, even longer for big content

# Also wrap these when they exist in your flow:
timeout 5 obsidian vault info=name         # yes
timeout 5 obsidian files vault="X"         # yes
```

**Recommended timeout budgets:**
- Quick reads / metadata / help: `timeout 3`
- Normal reads (files, vaults verbose, search): `timeout 5`
- Writes (create, append): `timeout 10`
- Writes with large content (populated notes): `timeout 15`

**Do NOT** run bare `obsidian <cmd>` without a timeout. If the Obsidian app is busy, frozen, or in a weird state, a bare command can hang indefinitely and freeze the agent session.

**System-level launch/quit commands** (e.g., `open -a Obsidian`, `osascript -e 'tell ... quit'`, `pkill Obsidian`) don't need `timeout` - they're OS commands, not obsidian CLI calls, and they return quickly.

### Rule 3: Switch active vault first, then use the CLI

```
The Obsidian CLI (v1.12.7, verified) IGNORES the vault= argument for
every read/write command - operations always hit the currently ACTIVE
vault regardless of what you pass for vault=.

The fix is not "avoid the CLI" - it's "make the right vault active
BEFORE running CLI commands." The obsidian:// URI handler does switch
the active vault reliably.

Every action skill runs the Vault Access Sequence after resolution:
  1. Check active vault:   timeout 3 obsidian vault info=name
  2. If wrong, switch:     open "obsidian://open?vault=<ENCODED>"
  3. Wait 3s, re-check:    timeout 3 obsidian vault info=name
  4. If it matches:        CLI_MODE=1 (CLI reads + filesystem writes + CLI verify)
  5. If it didn't:         CLI_MODE=0 (filesystem-only fallback)

Both modes produce correct results. CLI_MODE=1 additionally gets:
  - Indexed search (obsidian search beats raw grep)
  - Link verification (obsidian unresolved / orphans)
  - Backlink queries
```

## Preflight Check (run at the start of every action skill)

Every action skill (kb-init, kb-scaffold, kb-audit, kb-onboard, kb-offboard, kb-graph) must begin with this check. The CLI only works when Obsidian is installed and running.

### 1. Is the `obsidian` CLI installed?

```bash
command -v obsidian >/dev/null 2>&1 && echo "cli-ok" || echo "cli-missing"
```

If it's present, skip to step 3. If missing, distinguish between **"Obsidian not installed at all"** and **"Obsidian installed but CLI not enabled in settings"** - the fix differs.

```bash
# macOS
test -d /Applications/Obsidian.app && echo "app-found" || echo "app-missing"

# Linux (common locations)
ls ~/Applications/Obsidian*.AppImage /opt/Obsidian/* 2>/dev/null

# Windows (WSL)
ls "/mnt/c/Program Files/Obsidian/Obsidian.exe" 2>/dev/null
```

### 2a. App is installed but CLI is missing - the CLI is disabled in Obsidian's settings

The Obsidian CLI ships with the app since v1.12, but **it is not enabled by default**. The user has to turn it on manually once:

> "Obsidian is installed but its Command Line Interface is disabled. To enable it:
>
> 1. Open Obsidian.
> 2. Click the **Settings** gear (bottom-left) or press `Cmd/Ctrl + ,`.
> 3. In the sidebar, choose **General**.
> 4. Scroll to the bottom of the General page.
> 5. Toggle **'Command Line Interface'** ON.
> 6. Obsidian will add the `obsidian` binary to your PATH.
>
> Close and reopen your terminal (so it picks up the new PATH), then re-run the command. You only need to do this once."

Stop the skill here until the user confirms the CLI is enabled and `command -v obsidian` returns a path.

### 2b. Obsidian app is not installed

Pick the command for the user's OS, show it, and stop until they've installed the app:

**macOS:**
```
brew install --cask obsidian
# OR download: https://obsidian.md/download
```

**Linux:**
```
# Flathub (recommended)
flatpak install flathub md.obsidian.Obsidian

# Or AppImage / deb / snap from:
# https://obsidian.md/download
```

**Windows:**
```
winget install Obsidian.Obsidian
# OR download: https://obsidian.md/download
```

After installing Obsidian, the user still needs to enable the CLI (see step 2a above). Tell them both steps upfront so they don't have to come back.

### 3. If the CLI exists - check whether the app is running

The Obsidian CLI requires the app to be running.

```bash
timeout 3 obsidian vaults 2>&1 >/dev/null && echo "running" || echo "not-running"
```

### 4. If not running - launch it

```bash
# macOS
open -a Obsidian

# Linux (AppImage or binary)
(~/Applications/Obsidian*.AppImage &>/dev/null &) || (obsidian &>/dev/null &)

# Windows (WSL)
/mnt/c/Program\ Files/Obsidian/Obsidian.exe &
```

Wait 2-3 seconds, then retry `timeout 3 obsidian vaults`. If it still fails, inform the user and ask them to open Obsidian manually.

### 5. Proceed

Once `obsidian vaults` returns successfully, proceed with the skill's normal steps.
