---
name: kb-update
description: >
  Refresh the project's Obsidian knowledge base notes to reflect recent code changes. Reviews git
  activity and session context, surgically edits stale KB notes with file:line evidence, and flags
  new concepts as candidates for user-approved notes (never silently creates them). Run after a
  significant refactor, before /kb-offboard at session end, or any time you notice the KB drifting
  from the code. Triggered by /kb-update or when the user asks to "refresh the KB", "update the
  knowledge base", "sync the vault with the code". Distinct from /kb-audit - this maintains the
  vault's own notes; /kb-audit checks the project's user-owned markdown.
---

# kb-update - Refresh the KB after code changes

Keep the project KB aligned with reality as the code evolves. Review recent git activity and session context, surgically update stale KB notes, flag new concepts for documentation.

**Scope distinction:**
- **`kb-update` (this skill)** — edits notes *inside the vault* (Architecture/, Tech/, Patterns/, etc.) so the agent's memory matches the current code.
- **`kb-audit`** — checks the *project's* user-owned markdown (README.md, ARCHITECTURE.md, etc.) and produces a stand-alone audit report.

Both enforce the same hard rule: no edit or flag without `file:line` evidence.

## Step 0: Preflight

Follow the **Preflight Check** in the `obsidian-kb` awareness skill (`${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`). In short: verify `command -v obsidian`, verify `timeout 3 obsidian vaults` works, launch Obsidian if needed.

## Step 1: Resolve the Project Vault

Follow the **Vault Resolution Algorithm** in `${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`. Strict priority: user argument → path overlap → frontmatter `project_path` → strong name match → STOP and ask.

Capture both `$VAULT_NAME` and `$VAULT_PATH`.

Print the confirmation line on your first reply:

> "Using vault **`<Vault Name>`** at `<path>` (matched via `<tier>`). Reviewing KB notes against recent code changes."

If the user passed a focus area in `$ARGUMENTS` (e.g., "focus on the auth refactor"), capture it as `$FOCUS` — it will narrow Step 4's inventory.

### If no vault exists at all

Tell the user:

> "No knowledge base vault found for this project. Run `/kb-init` to create one first, then return here to refresh it."

Stop.

## Step 1b: Vault Access Sequence

Switch Obsidian's active vault to the resolved one so CLI operations work:

```bash
CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
if [[ "$CURRENT" != "$VAULT_NAME" ]]; then
  ENCODED=$(printf '%s' "$VAULT_NAME" | sed 's/ /%20/g')
  open "obsidian://open?vault=${ENCODED}"   # macOS; xdg-open on Linux; start on Windows
  sleep 3
  CURRENT=$(timeout 3 obsidian vault info=name 2>/dev/null)
fi
if [[ "$CURRENT" == "$VAULT_NAME" ]]; then CLI_MODE=1; else CLI_MODE=0; fi
```

All writes in this skill go through the filesystem using `$VAULT_PATH` (safer for multi-line edits than CLI escaping). Reads may use the CLI when `CLI_MODE=1`.

## Step 2: Determine the Review Window

Identify the range of changes to review. Preference order:

1. **Since the last handoff** (most common):
   ```bash
   LAST_HANDOFF=$(ls -t "$VAULT_PATH"/Sessions/*handoff*.md 2>/dev/null | head -1)
   if [[ -n "$LAST_HANDOFF" ]]; then
     LAST_HANDOFF_DATE=$(grep -m1 '^date:' "$LAST_HANDOFF" | sed 's/date:[[:space:]]*//')
     SINCE_ARG="--since=$LAST_HANDOFF_DATE"
   else
     SINCE_ARG="--max-count=15"
   fi
   ```

2. **User-specified window** if `$ARGUMENTS` includes something like "since last week" — pass through to `git log --since="..."`.

3. **No git history** (not a repo) — fall back to session conversation as the sole signal.

## Step 3: Gather Change Signals

Pull evidence of what changed:

```bash
# What commits landed
git log --oneline $SINCE_ARG 2>/dev/null

# What files changed, with line-count deltas
git diff $SINCE_ARG --stat 2>/dev/null

# Unstaged work that might not be committed yet
git diff --stat 2>/dev/null
git status --short 2>/dev/null
```

Also consider the **session conversation**:
- What topics were discussed?
- What files were opened / edited / debugged?
- Were there explicit decisions ("we're switching to X", "we dropped Y")?

Build a mental list of **areas of interest** — e.g., "auth middleware", "database connection pool", "new caching layer". `$FOCUS` (if provided) takes top priority.

## Step 4: Inventory Vault Notes

List every KB note that could plausibly be affected:

```bash
find "$VAULT_PATH" -type f -name '*.md' \
  -not -path '*/.obsidian/*' \
  -not -path '*/Sessions/*' \
  -not -name 'Documentation Audit.md'
```

**Always excluded:**
- `Sessions/` — handoffs are point-in-time records; editing them would corrupt history.
- `Research/Documentation Audit.md` — owned by `/kb-audit`; don't touch.

If `$FOCUS` is set, prioritize notes whose filename or path matches the focus area.

## Step 5: Identify Stale Notes

For each KB note in the inventory, read its content and look for **concrete claims** that can be checked against the code:

- File paths (e.g., "auth middleware lives at `src/auth/middleware.ts`")
- Function / class / module names
- Command-line invocations (e.g., "run tests with `npm test`")
- Version numbers (package versions, protocol versions, schema versions)
- Configuration keys and values
- Environment variable names

For each concrete claim, verify against the code:
- Does the file path still exist?
- Does the function / class / module still live where the note says?
- Does the command still exist in `package.json` / `Makefile` / etc.?
- Does the version number match what's pinned now?

If any claim fails verification, mark the note as a **staleness candidate** and capture the concrete evidence (`file:line` or command output that contradicts the claim).

## Step 6: Apply Surgical Updates

For each staleness candidate, apply an in-place edit to the affected section:

**Rules:**
- **Evidence-backed edits only.** Every change must cite a `file:line` reference (or equivalent, e.g., `package.json:15-22`, `ls src/services/` output).
- **Preserve hand-edits.** If a paragraph contains unique user voice, commentary, or reasoning that isn't a verifiable claim, don't touch it.
- **In-place replacement, not rewrite.** Change the stale claim and the text immediately around it; leave the rest of the note alone.
- **Preserve wiki-links.** Don't break `[[Note Name]]` references or rename linked notes.
- **Preserve frontmatter.** If the note has YAML frontmatter, leave it intact unless a field (e.g., `last_updated`) is specifically stale.

Use the Edit tool for each change. Prefer many small edits over one big rewrite.

**Example edit:**
- Before: `The auth service lives in \`src/services/auth/\`.`
- Evidence: `ls src/services/` returns `billing/ notifications/ orders/` — no `auth/`. `grep -l "authenticate" src/middleware/` finds `src/middleware/auth.ts`.
- After: `The auth service lives in \`src/middleware/auth.ts\` (moved from \`src/services/auth/\` during the JWT refactor).`

## Step 7: Flag New Documentation Candidates

If the change signals reveal a new concept that **isn't covered** by any existing KB note — a new service, a new pattern, a new architectural decision, a new dependency that deserves its own note — do NOT create the note silently.

Instead, collect a list of candidates and present them at the end for user approval:

```
Candidates for new notes (awaiting your approval):

- `Architecture/Refresh Token Flow` - new concept introduced by commit abc123; no existing note
  covers token lifecycle. Would document: rotation policy, revocation, storage.

- `Tech/Redis Caching Layer` - new dependency (package.json:58), no existing Tech/ note.
```

The user can approve or redirect. Do not write these without approval.

## Step 8: Report

Summarize at the end:

```
Updated N KB notes based on recent changes:

- Architecture/System Overview.md - auth section refreshed
  (evidence: src/middleware/auth.ts replaces src/services/auth/)

- Tech/Stack.md - Postgres version 15 → 16
  (evidence: package.json:42, docker-compose.yml:8)

- Patterns/Error Handling.md - added reference to new RetryMiddleware
  (evidence: src/middleware/retry.ts:1-47)

Candidates for new notes (awaiting your approval):
- Architecture/Refresh Token Flow
- Tech/Redis Caching Layer

Unchanged: K notes - no drift detected against the reviewed window.

Skipped by design: Sessions/* (handoffs), Research/Documentation Audit.md.

Tip: run /kb-audit to cross-check the project's own markdown separately.
```

## Safety Rules

- NEVER rewrite a note wholesale. Surgical edits only.
- NEVER create new notes without user approval — flag as candidates and wait.
- NEVER edit anything in `Sessions/` or `Research/Documentation Audit.md`.
- Every update cites `file:line` (or equivalent concrete) evidence.
- If a claim is ambiguous — no clear contradiction in the code — leave it alone and mention it in the report as "unclear, left unchanged."
- Preserve wiki-links and frontmatter unchanged unless explicitly stale.
- If git commands fail (not a repo), fall back to session conversation as the sole signal; don't invent change history.
- Wrap CLI commands with `timeout` to prevent hangs.
