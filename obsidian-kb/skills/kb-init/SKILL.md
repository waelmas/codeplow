---
name: kb-init
description: >
  Initialize the project knowledge base. If no vault exists, scaffolds one (via kb-scaffold) first.
  Then analyzes the codebase with parallel subagents and populates the vault with rich, structured
  documentation - mining existing markdown docs for insights but verifying every concrete claim
  against current code, so stale documentation doesn't pollute the vault. Produces curated notes
  plus a "Documentation Audit" report flagging outdated project docs. Use when the user asks to
  "initialize a knowledge base", "document this project", "populate the vault", "set up project
  memory", or types /kb-init. Always ask for confirmation before dispatching subagents - this uses
  meaningful compute and takes a few minutes.
---

# kb-init - Initialize Project Knowledge Base

Dispatch parallel subagents to explore the codebase, then populate the Obsidian vault with a curated set of architectural notes, references, and overviews. Mines existing project markdown docs (README, ARCHITECTURE, CHANGELOG, etc.) for insights, but verifies every concrete claim against the current code so stale documentation doesn't pollute the vault.

Turns an empty vault (or a thin one) into a rich knowledge base the next agent can hit the ground running with - and flags which existing project docs are outdated.

## Step 0: Preflight - Obsidian available and running?

Follow the **Preflight Check** in the `obsidian-kb` awareness skill (`${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`). In short:

1. `command -v obsidian` - if missing, check if the app is installed; if neither, show cross-platform install instructions (`brew install --cask obsidian` / `flatpak install flathub md.obsidian.Obsidian` / `winget install Obsidian.Obsidian`, or https://obsidian.md/download) and stop.
2. `timeout 3 obsidian vaults` - if it fails, launch Obsidian (`open -a Obsidian` on macOS, equivalent for Linux/Windows), wait 2-3 seconds, retry.
3. Only proceed once `obsidian vaults` succeeds.

## Step 1: Resolve the Project Vault (strict)

Follow the **Vault Resolution Algorithm** in `${CLAUDE_PLUGIN_ROOT}/skills/obsidian-kb/SKILL.md`. Strict priority order:

1. **User argument** (vault name) → fuzzy-match once, confirm.
2. **Path overlap** - exactly one vault whose path is inside `$PWD` or vice versa.
3. **Frontmatter `project_path`** - a root note's YAML matches `$PWD` exactly.
4. **Strong name match** - word-boundary substring match, exactly one candidate.
5. **STOP and ask** - if tiers 1–4 fail, list vaults and ask. Offer the "create a new vault for this project" option (the "If no vault exists" branch below).

This skill writes substantial content to the vault (5-8 notes). Writing to the wrong vault would pollute it. When uncertain, ASK.

After resolution, print the confirmation line:

> "Using vault **`<Vault Name>`** at `<path>` (matched via `<tier>`). Say 'wrong vault' if I should pick a different one."

## Step 1b: Vault Access Sequence

Before dispatching subagents or writing anything, make the resolved vault active so any CLI verification afterwards (`obsidian unresolved`, `obsidian orphans`, `obsidian search`) targets the right vault. Subagents get `$VAULT_PATH` explicitly in their prompts - they write via filesystem and don't need the switch themselves.

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

After that, subagents will write notes directly to `$VAULT_PATH/...` via filesystem (see "Context the subagents need" below) - no active-vault dependency for the writes. The active-vault switch matters for the main agent's verification step (Step 5c).

### If no vault exists

**Don't just stop - offer to chain.** Users should only need to remember one command; the agent handles the rest.

Say to the user:

> "No knowledge base vault found for this project. I'll run **kb-scaffold** first to create the empty vault structure, then continue here to populate it with rich docs from the codebase. Total time: 3-6 minutes. Proceed? [Y/n]"

**If the user confirms**:
1. Trigger the `kb-scaffold` skill (read `${CLAUDE_PLUGIN_ROOT}/skills/kb-scaffold/SKILL.md` and follow its instructions exactly).
2. When `kb-scaffold` reaches its "Step 6: Suggest Next Steps", skip that suggestion - the user is already about to get populated via this skill.
3. Once the vault is scaffolded and registered, return here and continue with **Step 2** of this skill (the user already confirmed they want population - proceed straight to Step 3 without re-asking).

**If the user declines**: stop here.

**Pass through the vault name** when chaining so kb-scaffold doesn't re-ask for it if the user specified one.

## Step 2: Ask for User Confirmation

This skill uses subagents and can take 2-5 minutes depending on codebase size. Always confirm:

> "I'll dispatch subagents in parallel to explore this codebase and populate the **<Vault Name>** knowledge base with rich documentation. This will:
>
> - Analyze architecture, tech stack, project structure, integrations, testing, and git history
> - Mine existing project docs (README, ARCHITECTURE, CHANGELOG, etc.) for insights
> - Verify every concrete claim against the actual code (no stale docs in the vault)
> - Write 5-9 curated notes into the vault (adaptive - only creates relevant ones)
> - Produce a Documentation Audit note flagging any outdated project docs
> - Update `Index.md` with links
>
> Takes 2-5 minutes. Proceed? [y/N]"

Only continue if the user confirms.

## Step 3: Pre-scan the Codebase

Before dispatching subagents, gather a quick overview to inform their prompts:

```bash
# Project surface
ls -la
cat README.md 2>/dev/null | head -50
cat package.json pyproject.toml go.mod Cargo.toml Gemfile 2>/dev/null

# Directory shape
find . -maxdepth 2 -type d -not -path '*/\.*' 2>/dev/null | head -30

# Git context
git log --oneline -20 2>/dev/null
git remote -v 2>/dev/null
```

This pre-scan helps each subagent focus - e.g., if there's no `package.json`, skip frontend-specific exploration; if no `.github/workflows/`, skip CI analysis.

## Step 3b: Inventory Existing Documentation

Projects often already have valuable markdown docs that hold insights (decisions, history, quirks) no amount of code reading would surface. But they also rot - commands become wrong, files get renamed, patterns shift. The skill should mine them **and** flag what's stale.

Find all markdown files in the project (skip generated, vendored, and third-party directories):

```bash
find . -type f \( -name '*.md' -o -name '*.mdx' \) \
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
  2>/dev/null | head -50
```

Categorize the findings by likely relevance (by filename and location):

| Filename pattern | Likely relevant to |
|------------------|---------------------|
| `README.md`, `OVERVIEW.md` | System Overview, Tech Stack |
| `ARCHITECTURE.md`, `DESIGN.md`, `docs/architecture/*` | System Overview, Data Models |
| `CONTRIBUTING.md`, `DEVELOPING.md`, `HACKING.md` | Tech Stack, Project Structure |
| `INSTALL.md`, `SETUP.md`, `GETTING_STARTED.md` | Tech Stack (commands) |
| `TESTING.md`, `docs/testing/*` | Testing Approach |
| `API.md`, `docs/api/*`, `openapi.yaml` | Data Models, External Integrations |
| `CHANGELOG.md`, `HISTORY.md`, `RELEASES.md` | Project History |
| `DEPLOYMENT.md`, `DEPLOY.md`, `docs/deployment/*` | External Integrations, System Overview |
| `docs/*.md` (other) | Varies - inspect contents |

Build a doc inventory to pass to the subagents:

```
doc_inventory = {
  "architecture": ["./ARCHITECTURE.md", "./docs/design.md"],
  "tech_stack": ["./README.md", "./CONTRIBUTING.md"],
  "testing": ["./TESTING.md"],
  "history": ["./CHANGELOG.md"],
  ...
}
```

Each subagent receives the paths of docs relevant to its aspect.

## Step 4: Dispatch Parallel Subagents

Send all subagent tasks in a **single message with multiple tool calls** so they run in parallel. Each subagent has a narrow focus, a target output note, and a template.

### Subagent type - use general-purpose, NOT Explore

Subagents in this skill need to **write** their output notes to the vault via the `obsidian` CLI (which requires Bash). That means:

- **Use `general-purpose`** subagents for every research task here - they have all tools.
- **Do NOT use `Explore` subagents.** Explore is read-only (no Edit, Write, or certain Bash operations) - it can analyze, but it cannot create the Obsidian notes it's asked to produce. The main agent would then have to transcribe each subagent's findings into notes itself, defeating the purpose of parallel dispatch and burning through context.

If you want a lean investigation-only pass without writing (e.g., a quick "is there a data model layer?" check before deciding whether to dispatch Subagent 7), an Explore subagent is fine. But for any subagent whose job ends with "write a note to `<vault>/...`", it must be general-purpose.

### Folder taxonomy (where each note belongs)

The vault already has `Architecture/`, `Research/`, and `Sessions/` (from kb-scaffold). Write new notes under the right top-level folder:

**`Architecture/` - structural information about the system.** What the system IS. Stable, descriptive.
- System Overview, Tech Stack, Project Structure, Data Models, External Integrations
- Decisions.md (ADR log - pre-existing from scaffold)

**`Research/` - investigations, findings, meta-analyses.** What we DISCOVERED during analysis. Can evolve.
- Testing Approach, Project History, Documentation Audit
- Notes.md (pre-existing from scaffold)

**`Sessions/` - session handoffs.** Reserved for kb-offboard output + the initial handoff this skill writes in Step 5b.

**Subfolders are allowed and encouraged when they make sense.** For large or multi-surface projects, subagents can create deeper structure:
- `Architecture/Frontend/`, `Architecture/Backend/` for split-stack projects
- `Architecture/Services/<ServiceName>/` for microservices
- `Research/Deep Dives/<topic>.md` for lengthy investigations

The canonical notes listed per-subagent below use the default paths. If a subagent creates a deeper structure, it should link from the canonical note to the deeper notes, not orphan them.

### Context the subagents need

Brief each subagent like a smart colleague walking in cold - they haven't seen the conversation. Every subagent prompt should include:

- The task's narrow focus and expected output note path (e.g., `Architecture/System Overview.md`)
- The doc inventory entries relevant to this subagent (from Step 3b)
- The relevant "Universal Instructions" blocks below
- The vault's **absolute filesystem path** (`$VAULT_PATH`, captured in Step 1). Subagents write notes via standard shell commands (`mkdir -p`, heredoc to `$VAULT_PATH/<relative/path.md>`) - not via the Obsidian CLI. The CLI's `vault=` argument is known-broken (ignored) in Obsidian 1.12.7, so filesystem operations are the only reliable path. See "Filesystem-First Operations" in the awareness skill for canonical command mappings.
- **Every file path a subagent writes must start with `$VAULT_PATH/`.** If the path doesn't start with that prefix, the note would land outside the vault - STOP and fix the path. Pass the literal `$VAULT_PATH` value into the subagent prompt, not a placeholder.

### Universal Instructions for All Subagents

This skill follows the subagent patterns from `superpowers:subagent-driven-development`. If you need deeper guidance on dispatching subagents, reviewing their output, or handling failures - consult that skill directly.

Every subagent prompt MUST include both of these blocks.

#### Block 1: Status Reporting Protocol

Subagents end every response with a status line so the main agent can distinguish "found nothing interesting" from "tried but couldn't complete":

> **End your response with exactly one of:**
> - `STATUS: DONE` - task completed, findings accurate.
> - `STATUS: DONE_WITH_CONCERNS` - completed; concerns listed below (e.g., had to guess which framework is primary).
> - `STATUS: NEEDS_CONTEXT` - missing info. List what's needed. Do NOT write the output note.
> - `STATUS: BLOCKED` - hit a blocker (denied tool, missing command, unreadable file). Describe it concretely. Do NOT fabricate content to fill the gap; empty is better than wrong.

#### Block 2: Trust-but-Verify for Existing Docs

Include this block in every subagent's prompt so they treat existing documentation as input material, not ground truth:

> **Existing docs to consult (trust but verify):**
> You've been given a list of relevant existing markdown docs in the project: `<doc_inventory_for_this_aspect>`. Treat these as **input material, not ground truth**:
>
> 1. **Mine them for insights** - rationale, history, quirks, decisions, tribal knowledge that isn't in the code.
> 2. **Verify every concrete claim against the code** - specifically check:
>    - **Commands** (e.g., "run `npm run dev`") → confirm in package.json / scripts / Makefile
>    - **File paths** (e.g., "see `src/api/routes.ts`") → confirm the file exists at that path
>    - **Component/module names** → confirm they still exist with the stated role
>    - **Tech versions** → confirm against current lock files and manifests
>    - **Configuration keys** → confirm in current config files
> 3. **Use the verified/current version in your output note.** If the doc said `npm run start` but `package.json` now has only `npm run dev`, write the current command.
> 4. **Flag discrepancies with hard evidence.** Every flagged claim MUST include a concrete reference that proves why you considered it outdated. The agent can't just say "this is stale" - it has to show the receipt.
>
>    Required format (use this exact shape):
>    ```markdown
>    ## Notes on Existing Docs
>    - **`<doc-path>`** - claim: "<exact quote or paraphrase from the doc>"
>      - Evidence: `<evidence-file>:<line-or-range>` - <what the code/config actually shows>
>      - Correction: <what the current truth is>
>    - **`<doc-path>`** - claim: "<another stale claim>"
>      - Evidence: `<file>:<line>` - <reality>
>      - Correction: <truth>
>    ```
>
>    Good example:
>    ```markdown
>    - **`README.md`** - claim: "Start the dev server with `npm run start`"
>      - Evidence: `package.json:15-22` - the `scripts` block only has `"dev"`, `"build"`, `"test"` (no `"start"`)
>      - Correction: use `npm run dev`
>    - **`ARCHITECTURE.md`** - claim: "The auth service lives in `src/services/auth/`"
>      - Evidence: `ls src/services/` returns `billing/ notifications/ orders/` - no `auth/` directory
>      - Correction: auth logic is now in `src/middleware/auth.ts` (git log shows it moved in commit abc123)
>    ```
>
>    If all existing docs are accurate, omit this section entirely. **Never flag something as stale without evidence.** If you're not sure, skip the flag.
>
> 5. **Don't include insights you can't verify or justify.** If a doc says "this was chosen because of historical reason X" and you can't confirm in the code, it's fine to include as "Per `<doc-path>`: <claim>" (attributed) - but don't present unverified claims as facts.

### Subagent 1: Architecture Explorer

**Scope:** Map the system's high-level design.

**Pass along:** `doc_inventory["architecture"]` (e.g., `./ARCHITECTURE.md`, `./docs/design.md`).

**Prompt template:**
> Analyze this codebase at `<pwd>`. Identify the high-level architecture: major components, how they communicate, key design patterns, and architectural style (monolith, services, client-server, etc.). Read the top-level README, entry points (main.*, index.*, app.*), and key configuration files. Do not read every file - focus on the architectural signal.
>
> **Existing architecture docs to consult:** `<paths>` - follow the "trust but verify" instructions from the skill. Mine them for rationale and decisions, verify claims against code, flag stale parts.
>
> Write a note to `<vault-path>/Architecture/System Overview.md` with this structure:
> ```markdown
> ---
> type: architecture
> created: <today's date>
> ---
>
> # <Project Name> - System Overview
>
> ## At a Glance
> <2-3 sentences: what this project is and what architectural style it uses>
>
> ## Key Components
> <bulleted list: each component, its role, where it lives in the code>
>
> ## Data Flow
> <how components communicate - requests, events, queues, etc.>
>
> ## Architectural Patterns
> <list the patterns in use: MVC, CQRS, event-driven, layered, etc.>
>
> ## Entry Points
> <main files - server, client, workers, CLIs>
> ```
>
> Write the note by creating the file on disk (the Obsidian CLI's `vault=` is broken; filesystem is the only reliable path):
> ```bash
> TARGET="$VAULT_PATH/Architecture/System Overview.md"
> mkdir -p "$(dirname "$TARGET")"
> cat > "$TARGET" <<'NOTE_EOF'
> ---
> type: architecture
> created: <today>
> ---
>
> # <Project Name> - System Overview
> ... your content ...
> NOTE_EOF
> ```
> Return a brief summary of what you wrote.

### Subagent 2: Tech Stack Analyzer

**Scope:** Languages, frameworks, dependencies, build/run/test commands.

**Pass along:** `doc_inventory["tech_stack"]` (e.g., `./README.md`, `./CONTRIBUTING.md`, `./INSTALL.md`).

**Prompt template:**
> Analyze the tech stack of the codebase at `<pwd>`. Check package.json, pyproject.toml, go.mod, Cargo.toml, Gemfile, Dockerfile, any lock files. Identify: primary languages, major frameworks, key libraries, build/test/lint commands, runtime versions.
>
> **Existing tech/install docs to consult:** `<paths>` - follow the "trust but verify" instructions. Particularly scrutinize commands: if README says `npm run start` but package.json only has `dev`, flag it and use the current command.
>
> Write to `<vault-path>/Architecture/Tech Stack.md`:
> ```markdown
> ---
> type: architecture
> created: <today's date>
> ---
>
> # Tech Stack
>
> ## Languages
> <list with versions where detectable>
>
> ## Frameworks & Core Libraries
> <categorized: frontend, backend, data, infra>
>
> ## Build, Run, Test
> | Task | Command |
> |------|---------|
> | Install | ... |
> | Dev server | ... |
> | Build | ... |
> | Test | ... |
> | Lint | ... |
>
> ## Runtime Requirements
> <Node version, Python version, OS, etc.>
> ```
>
> Write with: `mkdir -p "$VAULT_PATH/Architecture" && cat > "$VAULT_PATH/Architecture/Tech Stack.md" <<'NOTE_EOF' ... NOTE_EOF` (filesystem - do NOT use obsidian CLI create, it writes to the active vault regardless of `vault=`).

### Subagent 3: Project Structure Mapper

**Scope:** Directory layout, what lives where, naming conventions.

**Pass along:** `doc_inventory["tech_stack"]` (CONTRIBUTING.md and similar often describe structure).

**Prompt template:**
> Map the directory structure of the codebase at `<pwd>`. Identify top-level directories and their purposes. Note any naming conventions (kebab-case vs camelCase, test file patterns, etc.). Skip `node_modules`, `.git`, `dist`, `build`, `.next`, `target`, and similar generated directories.
>
> **Existing docs to consult:** `<paths>` - follow "trust but verify". CONTRIBUTING.md and similar docs often explain directory layout - verify that the described directories still exist.
>
> Write to `<vault-path>/Architecture/Project Structure.md`:
> ```markdown
> ---
> type: reference
> created: <today's date>
> ---
>
> # Project Structure
>
> ## Directory Layout
> ```
> <tree of top-level dirs with one-line descriptions>
> ```
>
> ## Naming Conventions
> <any patterns observed: file names, folder names, test naming>
>
> ## Where to Find Things
> | Looking for | Location |
> |-------------|----------|
> | Entry point | ... |
> | Config | ... |
> | Tests | ... |
> | Utilities | ... |
> ```

### Subagent 4: Integrations Scanner *(only if applicable)*

**Scope:** External APIs, services, webhooks, third-party integrations.

Skip this subagent if pre-scan shows no obvious external integrations (no API calls, no webhook files, no service configs). Otherwise:

**Pass along:** `doc_inventory["integrations"]` (API.md, DEPLOYMENT.md, any docs mentioning services).

> Scan the codebase at `<pwd>` for external integrations: third-party APIs, cloud services, webhooks, message queues, databases. Look at environment variables, config files, and HTTP client usage. Identify each integration and what it's used for.
>
> **Existing docs to consult:** `<paths>` - follow "trust but verify". Deployment and API docs often list integrations; confirm each still has active code references.
>
> Write to `<vault-path>/Architecture/External Integrations.md`:
> ```markdown
> ---
> type: reference
> created: <today's date>
> ---
>
> # External Integrations
>
> ## Services
> | Service | Purpose | Config |
> |---------|---------|--------|
> | ... | ... | ... |
>
> ## Environment Variables
> <list of env vars with what they're for>
>
> ## Webhook Endpoints
> <if any - incoming webhooks this project handles>
> ```

### Subagent 5: Testing Approach Analyzer *(only if tests exist)*

**Scope:** Test framework, patterns, coverage philosophy.

Skip if pre-scan shows no tests. Otherwise:

**Pass along:** `doc_inventory["testing"]` (TESTING.md and similar).

> Analyze the testing approach in the codebase at `<pwd>`. Identify the test framework(s), test file conventions, what kinds of tests exist (unit, integration, e2e), how to run them, and any notable patterns.
>
> **Existing testing docs to consult:** `<paths>` - follow "trust but verify". Check that test commands in docs still match package.json / Makefile / pyproject.toml scripts.
>
> Write to `<vault-path>/Research/Testing Approach.md`:
> ```markdown
> ---
> type: reference
> created: <today's date>
> ---
>
> # Testing Approach
>
> ## Framework & Tools
> ## Test Types
> ## File Conventions
> ## Running Tests
> ## Coverage & Philosophy
> ```

### Subagent 6: History Analyst *(only if git history exists)*

**Scope:** Git log analysis - major changes, refactors, project evolution.

Skip if not a git repo. Otherwise:

**Pass along:** `doc_inventory["history"]` (CHANGELOG.md, RELEASES.md, HISTORY.md).

> Analyze the git history of the codebase at `<pwd>`. Read `git log --oneline -50` and `git log --stat -20`. Identify major refactors, significant feature additions, and periods of intense activity. Report the project's evolution at a high level, not commit-by-commit.
>
> **Existing history docs to consult:** `<paths>` - CHANGELOG.md is often the best source of truth for version history. Prefer its framing over raw git log when both exist. Follow "trust but verify" for any claims about current features.
>
> Write to `<vault-path>/Research/Project History.md`:
> ```markdown
> ---
> type: reference
> created: <today's date>
> ---
>
> # Project History
>
> ## Timeline Highlights
> <major milestones with approximate dates>
>
> ## Recent Focus
> <what the last ~20 commits have been about>
>
> ## Notable Refactors
> <if any - what changed and why, inferred from commit messages>
> ```

### Subagent 7: Data Models *(only if applicable)*

**Scope:** Core data types, schemas, database models.

Skip if no clear data model (e.g., pure CLI tool, static site). Otherwise:

**Pass along:** `doc_inventory["architecture"]` + `doc_inventory["integrations"]` (API.md often has schemas).

> Identify the core data types and schemas in the codebase at `<pwd>`. Look for database migrations, ORM models, type definitions, API schemas, protobuf files. Focus on the 5-10 most central entities.
>
> **Existing docs to consult:** `<paths>` - follow "trust but verify". API and architecture docs often describe data models; verify each entity still exists in the code with the stated fields.
>
> Write to `<vault-path>/Architecture/Data Models.md`:
> ```markdown
> ---
> type: architecture
> created: <today's date>
> ---
>
> # Data Models
>
> ## Core Entities
> <for each: name, purpose, key fields, relationships>
>
> ## Schema Location
> <where types/schemas are defined>
>
> ## Storage
> <database, file system, in-memory, etc.>
> ```

### Subagent 8: Existing Docs Auditor *(only if any .md docs exist)*

**Scope:** Dedicated audit of existing markdown documentation - produces a single "state of the docs" note that complements the stale-docs flags in other subagents' outputs.

Skip if the doc inventory found zero markdown files beyond the generated Index.md in the vault. Otherwise:

**Delegate to the `kb-audit` skill** - the full audit prompt (template, verdict categories, evidence rules, version-numerically-stale patterns) lives in `${CLAUDE_PLUGIN_ROOT}/skills/kb-audit/SKILL.md` Step 4. Dispatch a subagent with that prompt verbatim, passing:
- `$VAULT_PATH`
- The full `doc_inventory` from Step 3b

The subagent follows the same status reporting protocol as the other subagents in this step (Block 1 above). When it completes, its output - `$VAULT_PATH/Research/Documentation Audit.md` - gets stitched into the Index like any other produced note.

**Why delegate:** kb-audit is also a standalone command users run independently of kb-init. Keeping the audit prompt in one place (the kb-audit skill) avoids drift between "the audit as part of kb-init" and "the audit run by itself."

## Step 4b: Check Subagent Statuses

After all parallel subagents return, inspect each status before stitching. This follows the same pattern as `superpowers:subagent-driven-development` - consult that skill for deeper handling if you hit an unusual case.

Handle each status:

- **DONE** - stitch the output.
- **DONE_WITH_CONCERNS** - read the concerns. If they affect accuracy (e.g., "had to guess the primary framework"), reflect the uncertainty in the output or ask the user. If they're observational (e.g., "the codebase has lots of generated files"), note and proceed.
- **NEEDS_CONTEXT** - provide what's missing and re-dispatch just that subagent.
- **BLOCKED** - don't stitch partial or empty output. Tell the user briefly what was blocked and ask whether to retry, skip (proceed with N-1 notes), or abort. For minor blockers (one subagent failed on a non-critical aspect), a single-line note in the final report is fine - don't interrupt for every denial.
- **No status line at all** - treat as BLOCKED and re-dispatch with a reminder to include the status.

The rule is simple: **only DONE and DONE_WITH_CONCERNS output reaches the vault.** Fabricating content to fill a blocked subagent's slot is worse than having one fewer note.

## Step 5: Stitch Results into Index

After all subagents finish, update the vault's `Index.md` to include links to the new notes. Read the current Index, then append a "Project Documentation" section listing links for notes that were actually created.

```bash
# Inspect the current Index
cat "$VAULT_PATH/Index.md"

# Build the doc-list block in a variable, including only notes that exist on disk.
DOC_LINKS=$'\n\n## Project Documentation\n'
for pair in \
  "Architecture/System Overview" \
  "Architecture/Tech Stack" \
  "Architecture/Data Models" \
  "Architecture/Project Structure" \
  "Architecture/External Integrations" \
  "Research/Testing Approach" \
  "Research/Project History" \
  "Research/Documentation Audit"
do
  if [[ -f "$VAULT_PATH/${pair}.md" ]]; then
    DOC_LINKS+="- [[${pair}]]"$'\n'
  fi
done
printf '%s' "$DOC_LINKS" >> "$VAULT_PATH/Index.md"
```

Only notes that actually exist on disk get linked - skipped or BLOCKED subagents don't leave dangling references.

## Step 5b: Write an Initial Session Handoff

After a fresh `/kb-init`, the vault has rich documentation but zero session history. `/kb-onboard` has nothing to brief from. Leave a single initial handoff so the next session (or a teammate) can get a grounded briefing on their first invocation.

```bash
TODAY="$(date +%Y-%m-%d)"
INIT_HANDOFF="$VAULT_PATH/Sessions/${TODAY}-initial.md"
mkdir -p "$VAULT_PATH/Sessions"

cat > "$INIT_HANDOFF" <<HANDOFF_EOF
---
type: session-handoff
date: ${TODAY}
project_path: ${PWD}
initial: true
---

# Initial Handoff - Knowledge Base Populated

## TL;DR
The knowledge base for this project was bootstrapped via \`/kb-init\` on ${TODAY}. <Short summary: "N notes written across Architecture/ and Research/; M existing project docs audited, K flagged for update.">

## What exists in the vault
Use these as your starting point for onboarding - they're the high-signal entry points:

- [[Index]] - overview + links to everything
- <list the key notes that were written, with one-liners>

## Next Steps
<If the audit flagged stale docs, mention: "the audit under Research/Documentation Audit lists N doc(s) that need updating - worth a quick pass before major new work."

If there's no pressing next step (the vault is fresh and no in-flight task), suggest:
"Browse the vault (\`/kb-graph\` for a visual map) or dive into whatever brought you here. Remember to \`/kb-offboard\` when wrapping up.">

## Watch Out
<Carry over any Watch Out items from subagents' DONE_WITH_CONCERNS reports, or from the Documentation Audit.>

## Links
- [[Index]]
- <links to the major notes created>
HANDOFF_EOF
```

This gives `/kb-onboard` a meaningful first briefing. Subsequent `/kb-offboard` calls will add normal handoffs alongside it.

Append the initial handoff link to the Index under a `## Recent Sessions` section:

```bash
printf '\n## Recent Sessions\n- [[Sessions/%s-initial]] - Initial handoff after kb-init\n' "$TODAY" \
  >> "$VAULT_PATH/Index.md"
```

## Step 5c: Verify Wiki-Link Integrity (CLI_MODE=1 only)

All the notes we just wrote contain `[[wiki-links]]`. After the last write lands, use Obsidian's indexed queries to check for broken links and lonely notes. This is much faster and more accurate than grepping.

```bash
if [[ "$CLI_MODE" == "1" ]]; then
  # Wait a couple seconds for Obsidian to re-index the new/updated files
  sleep 3

  # 1. Unresolved wiki-links (broken references)
  UNRESOLVED=$(timeout 5 obsidian unresolved 2>/dev/null)
  # 2. Orphan notes (nothing points to them) - purely informational
  ORPHANS=$(timeout 5 obsidian orphans 2>/dev/null)
fi
```

### Handling the results

**Unresolved links** - broken `[[...]]` in your notes. Surface these to the user briefly; don't auto-fix.
- If `UNRESOLVED` is empty: mention "All wiki-links resolved cleanly." in the Step 6 report.
- If non-empty: include a short bullet list: "N unresolved links: `[[X]]`, `[[Y]]`. These may be notes I meant to create but didn't, or intentional future references. Worth a quick scan."

**Orphans** - notes with no backlinks. Not necessarily a bug (Index doesn't need a backlink to itself), but a low-signal quality check.
- Just include the count in the report: "N notes currently have no incoming wiki-links."

**Skip this step entirely if `CLI_MODE=0`** - raw grep can approximate unresolved but doesn't handle Obsidian's resolution rules (aliases, case-insensitive, etc.) correctly. Better to skip than to false-positive.

## Step 6: Report

Tell the user what was created:

> "Populated the **<Vault Name>** knowledge base with N notes:
> - [[Architecture/System Overview]] - <one-line summary>
> - [[Architecture/Tech Stack]] - <one-line summary>
> - [[Architecture/Project Structure]] - <one-line summary>
> - <other notes created>
>
> Open the vault in Obsidian to explore. Next session, run `/kb-onboard` and the agent will have rich context to work with from the start."

## Key Principles

- **Always confirm first.** This skill uses meaningful compute and takes minutes. Never auto-run without explicit user approval.
- **Dispatch in parallel, not sequence.** Send all applicable subagent tasks in one message. They're independent - don't waste time serializing them.
- **Trust but verify existing docs.** Project markdown files are goldmines for rationale and history, but they rot. Mine them for insight; verify every concrete claim against code; write the current truth.
- **Skip irrelevant subagents.** A pure static site doesn't need `Data Models.md`. A one-file CLI doesn't need `Testing Approach.md`. Use pre-scan signals to decide.
- **Prefer depth over breadth.** One rich System Overview beats five shallow notes. Subagents should read 10-20 strategic files, not `find` everything.
- **Don't duplicate with existing notes.** If the vault already has `Architecture/Tech Stack.md` with content, ask the user: overwrite, merge, or skip?
- **Respect the user's time.** If the codebase is tiny (< 20 files), skip the subagent dance - the main agent can populate everything directly in a minute.
- **Attribute unverified insights.** If an existing doc contains rationale you can't confirm in code (e.g., "we chose X because of Y in 2023"), include it as "Per `<doc-path>`: <claim>" rather than presenting it as verified fact.
- **Subagents report status, main agent checks it.** Every subagent prompt includes the status protocol from Step 4 "Universal Instructions / Block 1". See `superpowers:subagent-driven-development` for the broader pattern.

## Safety Rules

- NEVER install or run npm/npx packages for Obsidian - use the system `obsidian` CLI only
- Always wrap commands with `timeout` to prevent hangs
- Never stitch BLOCKED or NEEDS_CONTEXT output into the vault - partial content is worse than no content
- Never fabricate a note to fill in for a blocked subagent
- If overwriting an existing note, ask the user first

## When to Suggest This Skill

Suggest `kb-init` when:
- The user just ran `/kb-scaffold` and the vault is mostly empty
- The user says "the vault is sparse" or "add more docs" or "enrich the KB"
- An agent is about to do complex work on an unfamiliar codebase - populating first gives future sessions better context
- The user wants to refresh docs after a major refactor

Don't suggest it:
- On trivial one-session tasks
- If the vault already has rich, recent documentation
- Before the user has confirmed the right vault for the project
