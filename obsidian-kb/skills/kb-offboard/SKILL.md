---
name: kb-offboard
description: >
  Write a session handoff note to the project's Obsidian knowledge base so the next session can pick
  up seamlessly. Use when wrapping up a session, when the user says they're "done", "wrapping up",
  "that's it for today", or types /kb-offboard (even in environments without native slash command
  support - treat that as intent to trigger this skill). The handoff is adaptive - proportional to
  what actually happened in the session.
---

# kb-offboard - Session Handoff

Examine what happened this session and write a proportional handoff note so the next session can pick up seamlessly.

## Step 0: Preflight - Obsidian available and running?

Follow the **Preflight Check** in the `obsidian-kb` awareness skill (`${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`). In short:

1. `command -v obsidian` - if missing, check if the app is installed; if neither, show cross-platform install instructions (`brew install --cask obsidian` / `flatpak install flathub md.obsidian.Obsidian` / `winget install Obsidian.Obsidian`, or https://obsidian.md/download) and stop.
2. `timeout 3 obsidian vaults` - if it fails, launch Obsidian (`open -a Obsidian` on macOS, equivalent for Linux/Windows), wait 2-3 seconds, retry.
3. Only proceed once `obsidian vaults` succeeds.

## Step 1: Resolve the Project Vault (strict)

Follow the **Vault Resolution Algorithm** in `${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`. It's a strict priority order:

1. **User argument** (vault name in `$ARGUMENTS`) → fuzzy-match once, confirm, done. If the argument also contains notes (e.g., "master vault focus on auth refactor"), split: vault name hint first, rest becomes user-provided notes for Step 2d.
2. **Path overlap** - exactly one vault whose path is inside `$PWD` or vice versa.
3. **Frontmatter `project_path`** - a root note's YAML matches `$PWD` exactly.
4. **Strong name match** - word-boundary substring match, exactly one candidate.
5. **STOP and ask** - if tiers 1–4 all fail, list available vaults and ask. Do NOT default. Do NOT fall back to the currently active Obsidian vault.

Writing to the wrong vault would pollute it with handoff notes for an unrelated project. If you're less than confident, ASK.

After resolution, print a confirmation line on your first reply:

> "Using vault **`<Vault Name>`** at `<path>` (matched via `<tier>`). Say 'wrong vault' if I should pick a different one."

**Critical:** every `obsidian` command in this skill MUST include `vault="<resolved>"`. Never omit it.

If the user tells you which vault to use, use it immediately - just confirm by name.

## Step 1b: Vault Access Sequence

Before writing anything, make the resolved vault active and set `CLI_MODE`:

```bash
CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
if [[ "$CURRENT" != "$VAULT_NAME" ]]; then
  ENCODED=$(printf '%s' "$VAULT_NAME" | sed 's/ /%20/g')
  open "obsidian://open?vault=${ENCODED}"   # macOS
  sleep 3
  CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
fi
if [[ "$CURRENT" == "$VAULT_NAME" ]]; then CLI_MODE=1; else CLI_MODE=0; fi
```

After resolution + switch, save the project_path mapping for future sessions (Tier 3 fast-path). Uses CLI when available, filesystem fallback otherwise - see "Save the mapping" in the awareness skill for the exact code.

### If no vault exists at all

Tell the user:

> "No knowledge base vault found for this project. Run `/kb-init` to create one first, then try again to save your handoff."

Stop here.

## Step 2: Gather Session Activity

Examine what actually happened this session. Gather data from multiple sources:

### 2a: Git activity

```bash
# What changed in the working tree
git diff --stat 2>/dev/null

# Recent commits (last ~10, or since session start if detectable)
git log --oneline -10 2>/dev/null

# Staged changes
git diff --cached --stat 2>/dev/null

# Untracked files that might matter
git status --short 2>/dev/null
```

### 2b: Conversation context

Think about what happened in this conversation:
- What was the user's goal?
- What decisions were made and why?
- What was accomplished?
- What's left unfinished?
- Were there any surprises, gotchas, or things that broke unexpectedly?
- Are there open questions or blockers?

### 2c: Test state (if applicable)

If tests were run this session, note the results. If there's a standard test command visible in the project (package.json scripts, pytest, etc.), note the last known state.

### 2d: User-provided notes

If the user provided arguments (e.g., "focus on the auth refactor"), incorporate those notes prominently.

## Step 3: Assess Scope and Build the Handoff

The handoff should be **proportional** to what happened. A session where you fixed one typo gets 5 lines. A session where you shipped 10 features gets the full treatment.

### Always include:
- **TL;DR** - 1-2 sentences: what happened, where things stand
- **Next Steps** - what the next session should focus on

### Include only when relevant:
- **Decisions & Rationale** - if architectural or design decisions were made
- **Key Files Changed** - if files were modified (use git diff output)
- **Test State** - if tests were run, with pass/fail counts
- **Watch Out** - gotchas, blockers, surprising behavior, things that might bite the next agent
- **Quick Start** - commands to resume work (only if non-obvious, e.g., special dev server setup, environment variables needed)

### Handoff note format

```markdown
---
type: session-handoff
date: YYYY-MM-DD
project_path: <pwd>
---

# Session Handoff - YYYY-MM-DD

## TL;DR
<1-2 sentences>

## Next Steps
<what to do next, in priority order>

## Decisions & Rationale
<only if decisions were made - what was decided and why>

## Key Files Changed
<only if files changed - list with brief purpose>

## Test State
<only if tests were run - command + result summary>

## Watch Out
<only if there are gotchas - things that might surprise the next session>

## Quick Start
<only if non-obvious - commands to get back to working state>

## Links
- [[Index]]
<wiki-links to relevant vault notes>
```

Omit any section that has nothing meaningful to say. Don't include empty sections.

## Step 4: Determine Where to Write

All writes in this step go through the filesystem using `$VAULT_PATH` (captured in Step 1). Do NOT use `obsidian create / append` - they ignore `vault=` and hit the active Obsidian vault. See "Filesystem-First Operations" in the awareness skill.

### 4a: Check the vault's existing structure

```bash
find "$VAULT_PATH" -type d -not -path "*/.obsidian/*" | sort
find "$VAULT_PATH" -type f -name "*.md" -not -path "*/.obsidian/*" \
  \( -iname "*handoff*" -o -path "*/Sessions/*" \) | sort
```

Look for where previous handoffs live:
- A `Sessions/` folder (standard for this plugin)
- Handoff notes directly at the vault root
- Inside another folder like `NEXUS/` or `Notes/`

### 4b: Choose the write location

- **`Sessions/` folder exists** → write there (standard path).
- **Previous handoffs exist elsewhere** → write alongside them to keep the vault consistent. Don't scatter handoffs across multiple folders.
- **No previous handoffs, no `Sessions/`** → create `Sessions/` and write there:
  ```bash
  mkdir -p "$VAULT_PATH/Sessions"
  ```

### 4c: Check for existing handoff today

```bash
TODAY="$(date +%Y-%m-%d)"
# Search handoffs with today's date in filename
ls "$VAULT_PATH"/Sessions/${TODAY}*.md 2>/dev/null
```

If a handoff already exists for today, pick the next sequence number: `YYYY-MM-DD-handoff-2.md`, etc.

### 4d: Create the note

```bash
HANDOFF_PATH="$VAULT_PATH/Sessions/${TODAY}-handoff.md"
mkdir -p "$(dirname "$HANDOFF_PATH")"

cat > "$HANDOFF_PATH" <<'HANDOFF_EOF'
---
type: session-handoff
date: 2026-04-13
project_path: <replace with $PWD before writing>
---

# Session Handoff - 2026-04-13

## TL;DR
<summary>

## Next Steps
<priorities>
HANDOFF_EOF
```

(Replace the YAML + heredoc content with the adaptive sections you built in Step 3.)

### 4e: Update the overview note (if one exists)

Check for an overview note at the vault root; if one exists, append a link to the new handoff:

```bash
for overview in "Index.md" "README.md" "Home.md" "00 - Home.md"; do
  if [[ -f "$VAULT_PATH/$overview" ]]; then
    printf '\n- [[Sessions/%s-handoff]] - %s\n' "$TODAY" "<TL;DR summary>" \
      >> "$VAULT_PATH/$overview"
    break
  fi
done
```

If no overview note exists, skip this step - don't create one just for a link.

### 4f: Never write outside the vault

Every path in this step begins with `$VAULT_PATH/`. If any path would land outside the vault folder, STOP - that's a bug. Double-check by verifying `$VAULT_PATH` is set and the target path starts with it.

## Step 5: Opportunistic Linking

Look at the topics mentioned in the handoff:
- If they match existing vault notes, use `[[wiki-links]]` to reference them.
- If they reference topics that *don't* have vault notes yet, mention this to the user as candidates for future notes.

## Step 6: Report

Tell the user:

> "Handoff saved to **<path>/YYYY-MM-DD-handoff.md** in the [Vault Name] vault.
>
> Next session, trigger **kb-onboard** (or run `/kb-onboard` in Claude Code / Cursor) to pick up where you left off."

## Safety Rules

- NEVER install or run npm/npx packages for Obsidian - use the system `obsidian` CLI only
- Always wrap commands with `timeout` to prevent hangs
- Don't fabricate session activity - only document what actually happened
- If git commands fail (not a git repo, no commits), skip those sections gracefully
