---
name: kb-audit
description: >
  Audit the existing markdown documentation in the current project against the actual code. Flags
  stale claims with file:line evidence, categorizes each doc (current / partially stale / stale /
  aspirational), produces a single "Documentation Audit" note in the project's Obsidian knowledge
  base. Re-runnable at any time - use for quarterly doc refreshes or before a major rewrite. Use
  when the user asks to "audit our docs", "check for stale READMEs", "find outdated documentation",
  or types /kb-audit. Independent of kb-init's full populate flow.
---

# kb-audit - Documentation Rot Detector

Scan every markdown doc in the current project, verify concrete claims against the code, and produce a single verdict note in the vault: **which docs are current, which are stale, and exactly why.** Every flagged claim carries a `file:line` reference as proof.

This skill is the **standalone** version of the audit that kb-init runs as part of its full flow. Run this any time you want to re-check documentation freshness without re-populating the vault.

## Step 0: Preflight - Obsidian available and running?

Follow the **Preflight Check** in the `obsidian-kb` awareness skill (`${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`).

## Step 1: Resolve the Project Vault

Follow the **Vault Resolution Algorithm** in `${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`. Strict priority: user argument → path overlap → frontmatter → strong name match → STOP and ask.

Capture both `$VAULT_NAME` and `$VAULT_PATH`.

Print the confirmation line on your first reply:

> "Using vault **`<Vault Name>`** at `<path>` (matched via `<tier>`). Auditing project docs against current code."

## Step 1b: Vault Access Sequence

Switch Obsidian's active vault to the resolved one so post-audit CLI verification works:

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

## Step 2: Inventory Project Markdown Docs

Find every markdown file in the project (not the vault - the *project's* docs we're auditing):

```bash
find "$PWD" -type f \( -name '*.md' -o -name '*.mdx' \) \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/.next/*' \
  -not -path '*/target/*' \
  -not -path '*/vendor/*' \
  -not -path '*/venv/*' \
  -not -path '*/.venv/*' \
  -not -path '*/__pycache__/*' \
  2>/dev/null | sort
```

If the result is empty - no project markdown to audit - tell the user and stop. This skill has nothing to do.

If a single user argument is passed (e.g., `/kb-audit README.md`), scope the audit to just that file or glob. Skip the full inventory.

## Step 3: Ask for Confirmation (if >10 docs)

If the inventory returned more than ~10 files, confirm with the user first - audit uses compute:

> "I found N markdown docs in this project. I'll audit each one: quote-and-verify 2-3 concrete claims per doc against the current code, flag stale claims with file:line evidence, and write a **Documentation Audit** note to the vault. Takes 1-3 minutes. Proceed? [Y/n]"

If ≤10 docs, skip the confirmation - it's quick enough to just run.

## Step 4: Dispatch the Audit Subagent

Dispatch a single general-purpose subagent (not Explore - it needs to write the note via filesystem). Pass the doc inventory and `$VAULT_PATH`.

**Subagent prompt template:**

> **Status Reporting Protocol (required):**
> End your response with exactly one of:
> - `STATUS: DONE` - audit complete, note written.
> - `STATUS: DONE_WITH_CONCERNS` - completed with notes; concerns listed below.
> - `STATUS: NEEDS_CONTEXT` - missing info; do NOT write the note.
> - `STATUS: BLOCKED` - hit a blocker (denied tool, missing command). Describe concretely. Do NOT fabricate content.
>
> ---
>
> Audit the existing markdown documentation in the project at `<pwd>`. You're given this inventory:
> `<doc inventory from Step 2>`
>
> For each doc, determine:
>
> - **Purpose** - what the doc claims to be about.
> - **Freshness signals** - last modified date (`stat` on macOS; `git log -1 --format=%cI <file>`), last commit message, references to deprecated features.
> - **Accuracy spot-check** - pick 2-3 concrete claims in each doc and verify against the code:
>   - Command in README → confirm in package.json / Makefile / scripts.
>   - File path reference → confirm the file exists at that path.
>   - Version claim → confirm in lock files.
>   - Feature description → confirm the feature still exists in code.
> - **Version-numerically stale patterns** - a common failure mode worth flagging separately. The doc is *architecturally* accurate but has frozen-in-time version metadata:
>   - README badges with outdated versions (e.g., `![Next.js 13.0]` when `package.json` has Next 15.x).
>   - "Requires Node N+" claims vs. current `engines` / `.nvmrc`.
>   - "Currently in alpha/beta" when the project is on a mature version tag.
>   - Installation sections referencing old dep versions.
>   - Roadmap / Coming Soon items that actually shipped months ago.
> - **Overall verdict** - current / partially stale / stale / aspirational (describes plans, not reality).
>
> Write the audit to `$VAULT_PATH/Research/Documentation Audit.md` via filesystem (NOT via `obsidian create` - the CLI ignores `vault=` and would write to the active vault only). Use this structure:
>
> ```markdown
> ---
> type: reference
> created: <today's date>
> audit_date: <today's date>
> ---
>
> # Documentation Audit
>
> Audit of existing project markdown docs, checked against current code.
> Every claim flagged as stale includes a concrete file:line reference as evidence.
>
> ## Summary
> <N docs audited, M current, S partially stale, X stale, A aspirational>
>
> ## Docs by Status
>
> ### Current (accurate & up to date)
> - `<path>` - <purpose>. Last touched <date>.
>
> ### Partially stale
> - **`<path>`** - <purpose>. Issues:
>   - Claim: "<quote>"
>     - Evidence: `<file>:<line>` - <what's actually there>
>     - Correction: <current truth>
>
> ### Stale
> - **`<path>`** - <purpose>. Likely out of date since <date> / version X.
>   - Primary evidence: `<file>:<line>` - <concrete example>
>
> ### Aspirational
> - **`<path>`** - describes planned state rather than current reality.
>   - Evidence: <what's missing vs described>
>
> ## Version-Numerically Stale
> <docs that are architecturally accurate but have frozen version metadata>
>
> ## Recommended Actions
> - **`<doc>`**: update section "<heading>" - says "<claim>", should say "<correction>" (see `<file>:<line>`)
> - **`<doc>`**: deprecate - functionality moved to `<new-location>` (git log `<commit>`)
> - **`<doc>`**: keep - historical value; flag at top with "Historical - may not reflect current architecture"
> ```
>
> Write with filesystem commands:
> ```bash
> mkdir -p "$VAULT_PATH/Research"
> cat > "$VAULT_PATH/Research/Documentation Audit.md" <<'NOTE_EOF'
> ... content ...
> NOTE_EOF
> ```
>
> **Hard rule:** do not flag any doc as stale without a concrete `file:line` or command-output reference proving the staleness. If you can't produce evidence, do not flag the claim. Speculation is useless - the audit's value is verifiable pointers the user can click.
>
> Keep it pragmatic - don't nitpick minor wording. Focus on claims that would mislead an agent or engineer trying to follow the docs today.

## Step 4b: Check Subagent Status

Same pattern as kb-init Step 4b (see `${CLAUDE_PLUGIN_ROOT}/skills/kb-init/SKILL.md`):

- **DONE** → proceed to Step 5.
- **DONE_WITH_CONCERNS** → read concerns; if they affect accuracy, reflect uncertainty or ask user.
- **NEEDS_CONTEXT** → provide what's missing, re-dispatch.
- **BLOCKED** → don't present partial output. Surface to user: retry / skip / abort.
- **No status line** → treat as BLOCKED, re-dispatch with a reminder.

## Step 5: Update the Vault Index

If `$VAULT_PATH/Index.md` exists and doesn't already link the audit, append a link:

```bash
if [[ -f "$VAULT_PATH/Index.md" ]] && ! grep -q 'Documentation Audit' "$VAULT_PATH/Index.md"; then
  printf '\n- [[Research/Documentation Audit]] - Freshness audit of project markdown\n' \
    >> "$VAULT_PATH/Index.md"
fi
```

If the audit note already existed and was overwritten (a re-run), leave the Index as-is - the link was already there.

## Step 6: Report

Show the user:

> "Audited **N** docs. **M** are current, **S** partially stale, **X** stale. Written to `Research/Documentation Audit.md` in the **<Vault Name>** vault.
>
> Top actions (if any):
> - <1-3 highest-impact fixes, each with a file:line pointer>
>
> Click through the Documentation Audit note for the full list with evidence."

## When to Suggest This Skill

Suggest `/kb-audit` when:
- The user asks to audit, check, or review their docs.
- The user mentions "stale docs", "outdated README", "doc rot".
- The user is about to do a major refactor and wants to know which docs will need updating.
- It's been 3+ months since the last audit (if you can tell from the vault's existing audit note).

Don't suggest it:
- On trivial one-session tasks.
- Immediately after a fresh `/kb-init` - that already ran the audit.
- In projects with no markdown docs.

## Safety Rules

- NEVER install or run npm/npx packages for Obsidian - use the system `obsidian` CLI only for CLI-specific ops.
- Always wrap `obsidian` commands with `timeout` (see the awareness skill's Rule 2).
- Writes go through the filesystem (`$VAULT_PATH/...`) - not `obsidian create vault=...`, which is ignored.
- Never flag a claim as stale without `file:line` evidence.
- If the vault already has a Documentation Audit note, this skill overwrites it with the new audit. That's correct behavior for a re-run.
