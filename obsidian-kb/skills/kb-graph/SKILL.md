---
name: kb-graph
description: >
  Open the project's Obsidian vault in Obsidian and switch to the graph view, showing the knowledge
  base as a visual network of notes and their wiki-link relationships. Use when the user asks to
  "see the graph", "visualize the vault", "show me how notes connect", "open the graph view",
  or types /kb-graph. Also useful after kb-init to show off the newly rich vault.
---

# kb-graph - Open Vault in Graph View

Open Obsidian at the project's vault and switch to the graph view. Pure convenience - makes the knowledge base visible as an explorable network rather than a file tree.

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
5. **STOP and ask** - if tiers 1–4 fail, list vaults and ask. Do NOT default. Do NOT fall back to the active Obsidian vault.

After resolution, print the confirmation line:

> "Opening vault **`<Vault Name>`** at `<path>` (matched via `<tier>`). Say 'wrong vault' if I should pick a different one."

**Critical:** the obsidian URI you open in Step 2 MUST use the resolved vault name - never let Obsidian decide which vault to open.

**If no vault exists for this project** (Tier 5 → user chose "create a new one"): offer to chain through `/kb-init` first, then return to this skill:
> "No knowledge base vault found for this project. I can run **/kb-init** to create and populate one with codebase documentation, then come back to open the graph view. Takes 3-6 minutes. Proceed? [Y/n]"

## Step 2: Open the Vault

Obsidian supports a URI scheme for opening vaults directly:

```bash
# Open the vault using the obsidian:// URI
# macOS
open "obsidian://open?vault=<url-encoded-vault-name>"

# Linux
xdg-open "obsidian://open?vault=<url-encoded-vault-name>"

# Windows
start "obsidian://open?vault=<url-encoded-vault-name>"
```

URL-encode spaces in the vault name (space → `%20`). Example: `"MyProject KB"` becomes `obsidian://open?vault=MyProject%20KB`.

If the vault is already open in Obsidian, this URI will just bring that window to the front.

## Step 3: Switch to Graph View

Obsidian's graph view is reached by:
- **Keyboard**: `Cmd+G` (macOS) or `Ctrl+G` (Linux/Windows) for the **global graph**
- **Menu**: Sidebar ribbon → Graph icon
- **Command palette**: `Cmd/Ctrl+P` → "Graph view: Open graph view"

**There is no official URI scheme to open a specific Obsidian view.** Programmatic control of the graph view requires the [Advanced URI](https://obsidian.md/plugins?id=obsidian-advanced-uri) community plugin. If the user has it, try:

```bash
open "obsidian://advanced-uri?vault=<name>&commandid=graph%3Aopen"
```

(This opens the global graph view via the built-in command ID.)

**If Advanced URI is not installed**, or to stay plugin-agnostic, tell the user after opening the vault:

> "Opened **<Vault Name>** in Obsidian. Press `Cmd+G` (macOS) / `Ctrl+G` (Linux/Windows) to open the graph view - or click the graph icon in the left ribbon.
>
> For a project-scoped graph, open a note first, then click the graph icon inside the note for its **local graph**."

## Step 4: Optional - Local vs Global Graph

If the user asked for a specific focus (e.g., `/kb-graph architecture` or `/kb-graph session handoffs`), try to open a relevant note first so the user can use the local graph view:

```bash
# Open a specific note via URI
open "obsidian://open?vault=<vault-name>&file=<url-encoded-note-path>"
```

Then suggest: "Click the local graph icon (three connected dots) in the note to see only notes linked to this one."

## When to Suggest This Skill

Suggest `kb-graph` when:
- The user just ran `/kb-init` - the vault now has rich, interconnected notes worth visualizing.
- The user says "show me the vault", "visualize", "let me see the knowledge base".
- The user is exploring how notes connect and wants a visual overview.
- The user mentions the graph view specifically.

Don't suggest it:
- As part of routine onboard/offboard flows (those are context-delivery, not exploration).
- If the vault is nearly empty (< 5 notes) - the graph won't be interesting.
- If the user is actively in a task that doesn't benefit from visual exploration.

## Safety Rules

- NEVER install or run npm/npx packages for Obsidian - use the system `obsidian` CLI only
- Always wrap CLI commands with `timeout` to prevent hangs
- This skill is read-only - never create, modify, or delete vault notes
- Don't assume Advanced URI is installed; fall back to instructing the user on keyboard shortcut
