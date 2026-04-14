---
name: kb-onboard
description: >
  Brief the agent on what happened last session by reading the latest handoff note and project overview
  from an Obsidian knowledge base. Use when starting work on a project that has a knowledge vault,
  when the user asks to "catch up", "see what was done last time", "continue previous work", or types
  /kb-onboard (even in environments without native slash command support - treat that as intent to
  trigger this skill). Read-only - never modifies the vault.
---

# kb-onboard - Session Briefing

Read the latest session handoff and project overview to quickly brief yourself (or the agent) on the current state of the project. Lean and fast - get context, then get to work.

## Step 0: Preflight - Obsidian available and running?

Follow the **Preflight Check** in the `obsidian-kb` awareness skill (`${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`). In short:

1. `command -v obsidian` - if missing, check if the app is installed; if neither, show cross-platform install instructions (`brew install --cask obsidian` / `flatpak install flathub md.obsidian.Obsidian` / `winget install Obsidian.Obsidian`, or https://obsidian.md/download) and stop.
2. `timeout 3 obsidian vaults` - if it fails, launch Obsidian (`open -a Obsidian` on macOS, equivalent for Linux/Windows), wait 2-3 seconds, retry.
3. Only proceed once `obsidian vaults` succeeds.

## Step 1: Resolve the Project Vault (strict)

Follow the **Vault Resolution Algorithm** in `${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`. It's a strict priority order - do not invent shortcuts. Summary:

1. **User argument** (explicit vault name) → fuzzy-match once, confirm, done.
2. **Path overlap** - vault path is inside `$PWD` (or vice versa) with exactly one match. Strongest automated signal.
3. **Frontmatter `project_path`** - a root note's YAML matches `$PWD` exactly.
4. **Strong name match** - word-boundary substring match, exactly one candidate. Weak partial overlaps do NOT qualify.
5. **STOP and ask** - if tiers 1–4 all fail, list available vaults and ask the user. Do NOT default to any vault. Do NOT fall back to the currently active Obsidian vault.

After you resolve the vault, print a confirmation line on your first reply:

> "Using vault **`<Vault Name>`** at `<path>` (matched via `<tier>`). Say 'wrong vault' if I should pick a different one."

This gives the user a fast abort path before any data is read.

**Critical:** every subsequent `obsidian` command in this skill MUST include `vault="<resolved>"` - never omit it. The obsidian CLI's active-vault fallback is how unrelated handoffs get read from other projects.

If the user tells you which vault to use, use it immediately - just confirm by name.

## Step 1b: Vault Access Sequence (switch active vault, then operate)

Before reading anything, run the Vault Access Sequence from `${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`:

```bash
CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
if [[ "$CURRENT" != "$VAULT_NAME" ]]; then
  ENCODED=$(printf '%s' "$VAULT_NAME" | sed 's/ /%20/g')
  open "obsidian://open?vault=${ENCODED}"    # macOS; xdg-open on Linux; start on Windows
  sleep 3
  CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
fi
if [[ "$CURRENT" == "$VAULT_NAME" ]]; then
  CLI_MODE=1
else
  CLI_MODE=0
fi
```

- `CLI_MODE=1` → you may use `obsidian search`, `obsidian files`, `obsidian read` for this vault (they all target the active one, which is now ours).
- `CLI_MODE=0` → use filesystem fallbacks (`find`, `grep`, `cat`) on `$VAULT_PATH`.

Tell the user: "Switched Obsidian to **`<VaultName>`** for this onboarding."

## Step 2: Find the Latest Handoff

Existing vaults may not follow a standard structure - handoff notes could be anywhere and named anything. See "Operation Split" in the awareness skill for the CLI/filesystem mappings.

### 2a: List handoff-like files in the vault

```bash
if [[ "$CLI_MODE" == "1" ]]; then
  # CLI path - indexed, handles Obsidian's file metadata
  timeout 5 obsidian files folder="Sessions" 2>/dev/null
  timeout 5 obsidian files 2>/dev/null | grep -iE 'handoff|handover|[0-9]{4}-[0-9]{2}-[0-9]{2}'
else
  # Filesystem fallback
  find "$VAULT_PATH" -type f -name "*.md" -not -path "*/.obsidian/*" \
    \( -iname "*handoff*" -o -iname "*handover*" -o -path "*/Sessions/*" \) | sort
fi
```

### 2b: If filename search doesn't surface obvious candidates, search content

```bash
if [[ "$CLI_MODE" == "1" ]]; then
  # Obsidian's indexed search - better than grep for multi-word queries
  timeout 5 obsidian search query="handoff" 2>/dev/null
  timeout 5 obsidian search query="next session" 2>/dev/null
  timeout 5 obsidian search query="TL;DR" 2>/dev/null
else
  # Filesystem fallback
  grep -r -l -i "handoff\|next session\|TL;DR" "$VAULT_PATH" \
    --include="*.md" --exclude-dir=.obsidian | sort
fi
```

### 2c: Pick the best candidate

- If multiple candidates, pick the one with the **most recent filename date** (YYYY-MM-DD) or `stat`-based mtime.
- If unsure, read the top 2-3 candidates and pick the one that reads like a session summary with next steps.
- If nothing looks like a handoff, that's OK - skip to Step 3.

### 2d: Read the handoff

```bash
if [[ "$CLI_MODE" == "1" ]]; then
  timeout 5 obsidian read path="<relative/path-to-handoff.md>"
else
  cat "$VAULT_PATH/<relative/path-to-handoff.md>"
fi
```

## Step 3: Find and Read the Project Overview

Look for an overview or index note. Don't assume it's `Index.md` - existing vaults may use different names.

### 3a: Check common names first

```bash
# Try these in order, stop at the first one that exists
for candidate in "Index.md" "README.md" "00 - Home.md" "Home.md" "Overview.md"; do
  if [[ -f "$VAULT_PATH/$candidate" ]]; then
    cat "$VAULT_PATH/$candidate"
    break
  fi
done
```

### 3b: If no standard index exists

List vault root notes and look for one that reads like an overview:

```bash
find "$VAULT_PATH" -maxdepth 1 -type f -name "*.md" -not -name ".*"
```

Pick the most promising candidate (e.g., a note named after the project, "Start Here", "About") and read it.

### 3c: If no overview note exists either

That's still fine. Present what you found from the handoff (Step 2), plus a summary of the vault's folder structure and file count as the "overview":

```bash
find "$VAULT_PATH" -type f -name "*.md" -not -path "*/.obsidian/*" | wc -l   # total note count
find "$VAULT_PATH" -maxdepth 2 -type d -not -path "*/.obsidian*" | sort       # folder tree
```

## Step 4: Present the Briefing

Synthesize what you read into a concise briefing. Adapt the format to what you found - don't present empty sections.

### If a handoff was found:

> **Session Briefing - [Project Name]**
>
> **Last session ([date]):** [TL;DR from handoff]
>
> **Next steps:** [Next Steps from handoff]
>
> **Watch out:** [Watch Out / gotchas from handoff, if any]
>
> **Vault overview:** [summary from index - N notes, key topics available]

### If no handoff but an overview exists:

> **Session Briefing - [Project Name]**
>
> **No session handoff found.**
>
> **Project overview:** [summary from index/overview note]
>
> Tip: trigger **kb-offboard** (or run `/kb-offboard`) when you're done to start the handoff chain.

### If the user passed a topic argument

If the user provided a topic (e.g., "auth refactor"), also search the vault for it:

```bash
timeout 5 obsidian search vault="<name>" query="<topic>"
```

Read and briefly summarize any matching notes.

## Step 5: Nudge for Further Exploration

End the briefing with a reminder that the vault has more depth:

> "The vault has **N** notes you can explore. If you need deeper context on anything, I can search and read from the vault - just ask."

## Key Principles

- **Be flexible reading.** Don't require exact file names, folder structures, or frontmatter fields. Look for what's there, not what you expect.
- **Be fast.** Read 2-3 files max, present the briefing, done. Don't read the whole vault.
- **Be concise.** The briefing should be scannable in 10 seconds. Details live in the vault.
- **Don't create or modify notes.** Onboard is read-only.
- **Don't refuse.** If you can't find a perfect handoff, work with what's available. Something is always better than nothing.
- **When unsure, ask.** A quick confirmation question is always better than guessing wrong or giving up.

## Safety Rules

- NEVER install or run npm/npx packages for Obsidian - use the system `obsidian` CLI only
- Always wrap commands with `timeout` to prevent hangs
- This skill is read-only - never create, modify, or delete vault notes
