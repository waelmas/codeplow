---
name: kb-scaffold
description: >
  Scaffold an empty Obsidian knowledge base vault for the current project - creates the folder structure
  and placeholder notes, but does NOT analyze the codebase or populate with content (for that, use kb-init).
  Use when the user asks to "just scaffold a vault", "create empty vault structure", "set up a bare vault",
  or types /kb-scaffold. Most users should use /kb-init instead for the full initialization flow. Always
  ask for confirmation before creating or deleting anything.
---

# kb-scaffold - Create an Empty Project Knowledge Base

Create a new Obsidian vault with a standardized empty structure. This is the lightweight alternative to `kb-init` - use when the user wants just the folders and placeholders, without automated codebase analysis.

For the full flow (scaffold + populate + audit), direct the user to `kb-init` instead.

## Step 0: Preflight - Obsidian available and running?

Follow the **Preflight Check** in the `obsidian-kb` awareness skill (`${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`). In short:

1. `command -v obsidian` - if missing, check if the app is installed; if neither, show cross-platform install instructions (`brew install --cask obsidian` / `flatpak install flathub md.obsidian.Obsidian` / `winget install Obsidian.Obsidian`, or https://obsidian.md/download) and stop.
2. `timeout 3 obsidian vaults` - if it fails, launch Obsidian (`open -a Obsidian` on macOS, equivalent for Linux/Windows), wait 2-3 seconds, retry.
3. Only proceed once `obsidian vaults` succeeds.

## Step 1: Check for Existing Vaults (strict priority)

Follow the **Vault Resolution Algorithm** in `${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`. Use strict priority order:

1. **Path overlap** - exactly one vault whose path is inside `$PWD` or vice versa.
2. **Frontmatter `project_path`** - a root note's YAML matches `$PWD` exactly.
3. **Strong name match** - word-boundary substring match, exactly one candidate.

If a match at any tier exists, treat that vault as a potential existing KB for this project and follow the "If a matching or similar vault is found" branch below.

If none of the tiers match, there's no existing vault - proceed to Step 2 to scaffold a new one.

**Critical:** every subsequent `obsidian` command in this skill MUST include `vault="<name>"` with the explicit vault name.

### If a matching or similar vault is found

Present the finding to the user and ask them to choose:

> "I found an existing vault **[vault name]** at `[path]` that appears to be associated with this project. Would you like to:
> 1. **Use it** - adopt this vault as the project KB (I'll update its Index.md with the project path if needed)
> 2. **Delete and recreate** - remove this vault and create a fresh one
> 3. **Ignore it** - create a new vault alongside it with a different name"

**If they choose "Use"**: Read the vault's `Index.md`. If it doesn't have a `project_path` property, set one:
```bash
timeout 5 obsidian property:set vault="<name>" path="Index.md" name="project_path" value="<pwd>"
```
Then report that the vault is now linked to this project. Done.

**If they choose "Delete"**: Delete the vault and proceed to Step 2.
```bash
timeout 10 obsidian delete vault="<name>" path="<each-file>" permanent
```

**If they choose "Ignore"**: Proceed to Step 2 but use a different vault name (ask the user what they'd like to call it).

### If no matching vault is found

Proceed to Step 2.

## Step 2: Confirm Vault Details

Derive a default vault name from the project directory:
- Take the directory name (e.g., `myproject`)
- Title-case it and append " KB" (e.g., `MyProject KB`)

If the user provided an argument, use that as the vault name instead.

Present for confirmation:

> "I'll create a knowledge base vault:
> - **Name:** MyProject KB
> - **Location:** `<pwd>/MyProject KB/`
>
> This will set up folders for architecture decisions, session handoffs, and research notes. Go ahead?"

Wait for the user to confirm. They can also override the name or location.

## Step 3: Create the Vault Folder on Disk

**Important:** The Obsidian CLI has **no `vault:create` command** - it only operates on already-registered vaults. If you try `obsidian create vault="NewName"` before the vault is registered, the CLI silently falls back to the currently active vault, renaming files on collision (`Index 2.md`, `Index 3.md`). That's a data-integrity bug, not a creation. Do not do this.

The correct sequence is:

1. Create the vault folder **on disk** with standard shell commands (not via the Obsidian CLI).
2. Write the scaffold files directly to disk.
3. Register the folder with Obsidian (Step 4).
4. Only then use the Obsidian CLI, now that the vault is known.

### 3a: Create the folder structure

```bash
# Use absolute path - resolve any ~ or relative paths first
VAULT_PATH="<absolute path chosen in Step 2>"

# Vault marker + scaffold folders
mkdir -p "$VAULT_PATH/.obsidian"
mkdir -p "$VAULT_PATH/Architecture" "$VAULT_PATH/Research" "$VAULT_PATH/Sessions"
```

The `.obsidian/` subfolder is what makes a folder an Obsidian vault. Without it, Obsidian treats the folder as ordinary files.

### 3b: Write the scaffold files

Write each file directly using shell heredocs (portable across bash/zsh/WSL). **Do not use the `obsidian` CLI here** - the vault isn't registered yet.

```bash
# Index.md
cat > "$VAULT_PATH/Index.md" <<'INDEX_EOF'
---
project_path: <pwd>
created: <YYYY-MM-DD>
---

# <Project Name> - Knowledge Base

## Overview
Knowledge base for the <Project Name> project.

## Structure
- [[Architecture/Decisions]] - architecture decision records and design rationale
- `Sessions/` - session handoffs for continuity across sessions
- [[Research/Notes]] - research notes, investigations, references

## Recent Sessions
INDEX_EOF

# Architecture/Decisions.md
cat > "$VAULT_PATH/Architecture/Decisions.md" <<'DECISIONS_EOF'
# Architecture Decisions

Record of key technical decisions and their rationale.

## Decisions

_No decisions recorded yet. As you make architectural choices, document them here with context and reasoning._
DECISIONS_EOF

# Research/Notes.md
cat > "$VAULT_PATH/Research/Notes.md" <<'NOTES_EOF'
# Research Notes

Investigations, references, and findings.

## Notes

_No research notes yet. Use this section for technical investigations, external references, and findings worth preserving._
NOTES_EOF

# Sessions/.gitkeep.md (placeholder so the folder exists in git)
cat > "$VAULT_PATH/Sessions/.gitkeep.md" <<'SESSIONS_EOF'
# Sessions

This folder contains session handoff notes created by the kb-offboard skill (`/kb-offboard`).

Each handoff captures what happened in a session so the next session can pick up where you left off.
SESSIONS_EOF
```

Replace `<pwd>`, `<YYYY-MM-DD>`, and `<Project Name>` with actual values before running.

### 3c: Verify disk creation

```bash
ls -la "$VAULT_PATH"/
ls -la "$VAULT_PATH/.obsidian"
```

You should see `.obsidian/`, `Architecture/`, `Research/`, `Sessions/`, and `Index.md` at the vault root. If any of these are missing, stop and report the error - don't proceed to registration with a partially-built vault.

## Step 4: Register the Vault with Obsidian

A folder with `.obsidian/` inside is **a vault on disk**, but Obsidian only lists vaults it has explicitly registered in its global config. This step tells Obsidian "track this folder as a vault."

**Always present both methods to the user and let them choose.** Don't hide Method B behind an opt-in - users won't know it exists. Present the trade-off openly.

### Ask the user which method they prefer

Present both options together:

> "Vault folder is ready at `<path>`. Now Obsidian needs to register it. Two methods:
>
> **A. Manual (via Obsidian's UI)** - safer, takes 5 seconds of clicking.
> You click the vault switcher at the bottom-left of Obsidian → 'Open folder as vault' → select the folder. Nothing on your system changes except Obsidian adding a new entry when you click.
>
> **B. Automatic (I edit Obsidian's config)** - fully hands-off, takes 5-10 seconds.
> I'll edit Obsidian's vault registry JSON file, force-quit Obsidian, and relaunch it. I'll back up the config file first. **Any unsaved work in your current Obsidian window will be lost when I force-quit** - so save anything open first.
>
> Which do you prefer? [A/B]"

Wait for the user's choice. Don't default - let them pick.

### Method A: Manual registration via the Obsidian UI

Guide the user with specific, visual instructions:

> "OK, Method A. Here's what to do:
>
> 1. Bring Obsidian to the foreground (it's already running from the preflight).
> 2. Click the vault switcher at the **bottom-left** of the Obsidian window - it shows the current vault's name.
> 3. Click **'Open folder as vault'**.
> 4. Select the folder: `<path>`
> 5. Obsidian will open the new vault.
>
> Let me know when you've done this and I'll verify."

Wait for user confirmation (reply of "done", "ok", etc.). Then verify:

```bash
timeout 5 obsidian vaults verbose
# The new vault should appear with its path
```

If it appears, proceed to Step 5. If it doesn't, ask the user to try again or offer to switch to Method B.

### Method B: Automatic registration

If the user picked Method B, walk through the steps transparently. **Before doing anything**, restate exactly what's about to happen:

> "OK, Method B. Here's exactly what I'm about to do, no hidden steps:
>
> **What the automatic method does:**
> 1. **Reads Obsidian's vault registry** - a plain JSON file on your computer:
>    - macOS: `~/Library/Application Support/obsidian/obsidian.json`
>    - Linux: `~/.config/obsidian/obsidian.json`
>    - Windows: `%APPDATA%\obsidian\obsidian.json`
> 2. **Makes a timestamped backup** (e.g., `obsidian.json.bak-<timestamp>`) so nothing is lost if anything goes wrong.
> 3. **Adds one new entry** to the `vaults` object: `{ "<new-id>": { "path": "<your-vault-path>", "ts": <current-time> } }`. The ID is a random 16-character hex string. No other data is changed.
> 4. **Force-quits Obsidian** - Obsidian only re-reads this config on startup, and it overwrites the file on clean quit (which would wipe our edit). This step is essential.
> 5. **Relaunches Obsidian** - it now sees the new vault.
> 6. **Verifies** the vault appears in the vault list.
>
> **The trade-off:** any unsaved work in your current Obsidian window will be lost when Obsidian is force-quit. If you have unsaved notes, save them first.
>
> Prefer this over Method A? [y/N]"

If the user declines or is unsure, use Method A. If they confirm Method B, follow the decision tree below - **do not improvise a different approach**.

### Method B decision tree (strict order, do not skip steps)

```
1. Try the bundled registration script.    ← primary path
   ├─ exit 0   → done, proceed to Step 5.
   ├─ exit 1   → scaffold is incomplete. Return to Step 3 to fix, then retry.
   ├─ exit 2   → OS unsupported by scripts. Skip to Method A.
   ├─ exit 3   → Obsidian config missing. Tell user, offer to skip to Method A.
   ├─ exit 4   → register/verify failed; script already restored backup. Skip to Method A.
   └─ script file not found / resolver failed → fall through to step 2.

2. Inline bash fallback (Method B2).       ← only if step 1 script was unreachable
   ├─ succeeds → done, proceed to Step 5.
   └─ fails    → restore the backup (if one was made), fall through to step 3.

3. Pivot to Method A (manual UI).          ← final fallback
   Guide the user through "Open folder as vault" in Obsidian.

NEVER invent a fourth approach. NEVER skip step 1 for step 2 to "save time".
NEVER leave the user's obsidian.json modified without a verified vault entry.
```

#### B1: Invoke the bundled registration script (primary path)

The plugin ships with tested, platform-specific scripts at:

- macOS / Linux: `$PLUGIN_ROOT/scripts/register-vault.sh`
- Windows: `$PLUGIN_ROOT/scripts/register-vault.ps1`

These scripts do all the steps (detect OS, find config, back it up, generate ID, force-quit Obsidian, inject entry, relaunch, verify). They return exit 0 on success, non-zero with a clear error on failure. On failure, they restore the backup automatically.

**Resolving `$PLUGIN_ROOT`:** Use the host platform's plugin-root environment variable. These are set automatically when a skill runs inside a plugin:

- **Claude Code:** `${CLAUDE_PLUGIN_ROOT}` - canonical, always set
- **Cursor:** `${CURSOR_PLUGIN_ROOT}` (if available) - otherwise infer from install location
- **Codex CLI:** `${CODEX_PLUGIN_ROOT}` (if available) - otherwise infer

Put together a one-line resolver:

```bash
# Resolve the plugin root across Claude Code / Cursor / Codex.
# Try the canonical env vars first; fall back to a find-based search.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${CURSOR_PLUGIN_ROOT:-${CODEX_PLUGIN_ROOT:-}}}"

if [[ -z "$PLUGIN_ROOT" || ! -f "$PLUGIN_ROOT/scripts/register-vault.sh" ]]; then
  # Last resort: locate it via filesystem search
  PLUGIN_ROOT="$(dirname "$(find \
    "$HOME/.claude/plugins/cache" \
    "$HOME/.cursor/plugins" \
    "$HOME/.codex/plugins" \
    -name register-vault.sh -path '*obsidian-kb*' 2>/dev/null | head -n 1 | xargs dirname 2>/dev/null)")"
fi
```

**Invoke the script:**

```bash
# macOS / Linux
bash "$PLUGIN_ROOT/scripts/register-vault.sh" "$VAULT_PATH"
SCRIPT_EXIT=$?
```

```powershell
# Windows (PowerShell)
# The analogous resolver uses $env:CLAUDE_PLUGIN_ROOT etc.
$PluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT }
              elseif ($env:CURSOR_PLUGIN_ROOT) { $env:CURSOR_PLUGIN_ROOT }
              elseif ($env:CODEX_PLUGIN_ROOT) { $env:CODEX_PLUGIN_ROOT }
              else { (Get-ChildItem -Path $env:USERPROFILE\.claude\plugins,$env:USERPROFILE\.cursor\plugins -Recurse -Filter register-vault.ps1 -ErrorAction SilentlyContinue | Select-Object -First 1).Directory.Parent.FullName }

powershell -ExecutionPolicy Bypass -File "$PluginRoot\scripts\register-vault.ps1" -VaultPath $VaultPath
```

**Script exit codes** (handle per the decision tree at the top of Method B):
- `0` - success; proceed to Step 5.
- `1` - bad usage / missing `.obsidian/` marker. Something went wrong in Step 3 - return there, fix the scaffold, and retry.
- `2` - unsupported OS. Skip to Method A.
- `3` - Obsidian config not found. Tell the user: "Obsidian's vault registry isn't where I expected at `<path>`. Is Obsidian installed and has it been run at least once? I'll skip to Method A so you can register via the UI."
- `4` - vault didn't appear after registration. The script already restored the backup. Skip to Method A.

**Do not skip the script in favor of inline bash (B2)** unless the script is genuinely unreachable (resolver couldn't locate it). Inline bash is more error-prone and harder to debug.

#### B2: Fallback - inline bash (if the script is unavailable or fails non-recoverably)

If the script can't be found (e.g., the plugin was loaded without the scripts directory), or if the script returns a non-zero exit you don't understand, fall back to running the equivalent steps inline. The logic is identical to the script - just spelled out for the agent to execute manually.

**B2a: Detect OS and config path**

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
  CONFIG_PATH="$HOME/Library/Application Support/obsidian/obsidian.json"
  OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  CONFIG_PATH="$HOME/.config/obsidian/obsidian.json"
  # Fall back to flatpak location if the standard one doesn't exist
  [[ ! -f "$CONFIG_PATH" ]] && CONFIG_PATH="$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"
  OS="linux"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  # WSL
  CONFIG_PATH="/mnt/c/Users/$USER/AppData/Roaming/obsidian/obsidian.json"
  OS="windows"
else
  echo "Unknown OS - fall back to Method A."
  # Go to Method A
fi

[[ ! -f "$CONFIG_PATH" ]] && { echo "Obsidian config not found - fall back to Method A."; }
```

**B2b: Back up + generate ID**

```bash
BACKUP_PATH="$CONFIG_PATH.bak-$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "Backed up to: $BACKUP_PATH"
NEW_ID=$(openssl rand -hex 8 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(8))")
```

**B2c: Force-quit Obsidian, inject entry, relaunch, verify**

Do these in sequence (see `${CLAUDE_PLUGIN_ROOT}/scripts/register-vault.sh` for the full implementation if you need a reference). Quit gently first (`osascript ... quit`), hard-kill if still running after 1s, inject with a Python one-liner, relaunch via `open -a Obsidian` (macOS) / AppImage or `obsidian` binary (Linux), verify with `obsidian vaults verbose`.

If verification fails, restore the backup and fall back to Method A.

### After Either Method - Vault is Registered

Once `obsidian vaults verbose` shows the new vault, registration is complete.

**Also make the new vault active** so anything downstream (a chained `/kb-init`, or verification commands) targets it correctly:

```bash
ENCODED=$(printf '%s' "$VAULT_NAME" | sed 's/ /%20/g')
open "obsidian://open?vault=${ENCODED}"     # macOS; xdg-open on Linux; start on Windows
sleep 3
# Verify
CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
if [[ "$CURRENT" != "$VAULT_NAME" ]]; then
  echo "Warning: new vault registered but didn't become active. User may need to click it in Obsidian's switcher."
fi
```

Proceed to Step 5.

## Step 5: Report

Tell the user what was created:

> "Created and registered knowledge base **[Vault Name]** at `<path>` with:
> - `Index.md` - project overview and structure
> - `Architecture/Decisions.md` - for architecture decision records
> - `Research/Notes.md` - for research and investigations
> - `Sessions/` - for session handoffs"

## Step 6: Suggest Next Steps

The scaffold is intentionally minimal - empty templates. Close with:

> "Scaffolded empty knowledge base at `<path>`. Two suggested next steps:
>
> - **`/kb-init`** - automatically analyze the codebase and populate the vault with rich documentation (+ audit any existing project markdown for stale claims). Takes 2-5 minutes.
> - **`/kb-graph`** - visualize the vault in Obsidian's graph view.
>
> When you're done working on the project, use `/kb-offboard` to save a session handoff for next time."

If the user explicitly asked for just a scaffold, don't push `/kb-init` on them - the suggestion is enough. If they used `/kb-scaffold` because they landed on it by accident (meaning to run `/kb-init`), they can pivot immediately.

## Safety Rules

- NEVER install or run npm/npx packages for Obsidian - use the system `obsidian` CLI only
- NEVER try to create a new vault using `obsidian create vault="NewName"` - the CLI silently falls back to the active vault, polluting it. Always use the `mkdir` + direct file write + register sequence in Steps 3-4.
- Always wrap CLI commands with `timeout` to prevent hangs
- Always ask for user confirmation before creating or deleting a vault
- When using Method B (automatic registration), always back up `obsidian.json` first and announce the backup path
- Never force-quit Obsidian without explicit user confirmation and a warning about unsaved work
- Never delete a vault without explicit user approval
- Always present BOTH registration methods (A and B) to the user - don't hide automation behind an opt-in
