# codeplow

**Plugins for AI coding agents that fight context rot, doc rot, and forgotten decisions.** Native on **Claude Code**, **Cursor**, and **Codex CLI**.

Built by [Wael Masri](https://waelmas.com).

---

## TL;DR

- Today, one plugin: [`obsidian-kb`](obsidian-kb/) - a real [Obsidian](https://obsidian.md) vault as persistent, per-project memory for your AI coding agent.
- Solves **context rot** between sessions (`/kb-offboard` writes a handoff, `/kb-onboard` reads it) and **doc rot** inside the repo (`/kb-audit` flags stale markdown with `file:line` evidence).
- Not a vector DB, not a CLAUDE.md replacement - plain markdown on disk, user-owned, committable alongside your code.
- Add the marketplace once; future plugins land there automatically.

```bash
curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.sh | bash
```

---

## Why this exists

**Context rot.** Long sessions drift - decisions made at token 2,000 get lost by token 50,000. Starting a new session resets everything, including the decisions. The fix isn't stuffing more into context. It's externalizing the thread so each new session starts fresh *and* briefed.

**Doc rot.** Every codebase accumulates stale markdown: a README that says `npm run start`, an `ARCHITECTURE.md` describing a service split three refactors ago. AI-written projects are especially prone - the agent generates docs that match the commit, nothing updates them later, the next session reads them as truth.

`obsidian-kb` attacks both with one pattern: a real Obsidian vault holding structured project memory, audited against live code with `file:line` citations, plus explicit session handoffs.

---

## Commands

| Command | What it does | When |
|---|---|---|
| `/kb-init` | Scaffold a vault, analyze the codebase via parallel subagents into structured docs, run a Documentation Audit on existing markdown with `file:line` evidence. | Day 1 on a project. |
| `/kb-audit` | Re-run just the drift check on existing markdown. | Quarterly, after refactors. |
| `/kb-onboard` | Agent reads the latest handoff, picks up the thread. | Start of each session. |
| `/kb-offboard` | Agent writes an adaptive handoff (TL;DR, decisions, files changed, gotchas) and updates the KB. | End of each session. |
| `/kb-graph` | Opens the vault in Obsidian's graph view. | When you want to see connections. |
| `/kb-scaffold` | Empty structure only - populate by hand. | If you don't want codebase analysis. |

Smart chaining: run `/kb-graph` on an uninitialized project and the agent offers to chain through `/kb-init` first.

---

## How it compares

| | obsidian-kb | [Cline Memory Bank](https://docs.cline.bot/prompting/cline-memory-bank) | [claude-mem](https://github.com/thedotmack/claude-mem) | [Mem0](https://mem0.ai) / [Zep](https://getzep.com) | CLAUDE.md / AGENTS.md |
|---|---|---|---|---|---|
| **Storage** | Markdown in Obsidian vault | Plain markdown | SQLite + Chroma (vector) | Proprietary graph + vector | Single markdown file |
| **User owns the data?** | Yes - portable `.md` | Yes | Local, but opaque | OSS self-host or cloud | Yes |
| **Audit with `file:line` citations** | **Yes** | No | No | No | No |
| **Cross-platform** (Claude Code / Cursor / Codex) | **Yes, one plugin** | Cline only | Claude-primary | SDK into any app | Tool-specific file |
| **Session continuity** | Explicit onboard/offboard | Implicit ("read all on reset") | Auto-capture, opaque | Retrieval on query | None |
| **Scope** | Per-project vault | Per-project folder | Global + per-project | Per-user / per-app | Per-project file |

- **Closest sibling - Cline Memory Bank.** Also markdown, also per-project. Differs: Cline-only, fixed schema, no audit, no graph, no explicit handoff loop.
- **Different category - claude-mem / Mem0 / Zep / Supermemory.** Vector retrieval over chat history (*"what did we discuss?"*). obsidian-kb curates project docs (*"what does this project look like, and where were we?"*). Compose them if you want both.
- **Different scope - CLAUDE.md / AGENTS.md / Cursor Rules.** Short bootstrap files. Point them at the vault for depth.
- **Opposite direction - [Smart Connections](https://github.com/brianpetro/obsidian-smart-connections).** Brings AI *into* Obsidian. obsidian-kb brings Obsidian *into* your AI coding agent.

---

## Install

Easiest - ask your agent:

> Install codeplow for me by following https://raw.githubusercontent.com/waelmas/codeplow/main/INSTALL.md

Or one shell line:

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.sh | bash

# Windows PowerShell
iwr -useb https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.ps1 | iex
```

<details>
<summary><b>Platform-specific manual install</b></summary>

**Claude Code**
```bash
claude plugin marketplace add waelmas/codeplow
claude plugin install obsidian-kb@codeplow
```

**Cursor**
```bash
git clone https://github.com/waelmas/codeplow ~/codeplow
mkdir -p ~/.cursor/plugins/local
ln -s ~/codeplow/obsidian-kb ~/.cursor/plugins/local/obsidian-kb
# Then: Developer: Reload Window in Cursor
```

**Codex CLI**
```bash
git clone https://github.com/waelmas/codeplow ~/codeplow
mkdir -p ~/.agents/plugins
cp ~/codeplow/.agents/plugins/marketplace.json ~/.agents/plugins/marketplace.json
# Then open /plugins in Codex
```
</details>

**Prerequisite:** [Obsidian](https://obsidian.md) v1.12+ with its CLI enabled (Settings → General → scroll to bottom → toggle **Command Line Interface** ON). The plugin preflight walks you through it if it's missing.

---

## The Documentation Auditor

The feature nothing else in this category ships.

When `/kb-init` runs, one subagent walks every existing `.md` file in the project and cross-checks concrete claims against the code. The result lives in `Research/Documentation Audit.md`:

```markdown
## Summary
8 docs audited, 3 current, 4 partially stale, 1 stale

## Partially stale

- **`README.md`** - Project overview. Issues:
  - Claim: "Start the dev server with `npm run start`"
    - Evidence: `package.json:15-22` - scripts block only has `dev`, `build`, `test`
    - Correction: use `npm run dev`

- **`ARCHITECTURE.md`** - System design. Issues:
  - Claim: "Auth service lives in `src/services/auth/`"
    - Evidence: `ls src/services/` → no `auth/`; auth moved to `src/middleware/auth.ts`
```

You then tell the agent *"fix the stale README commands"* or *"delete the outdated architecture doc"* and you're back in control of your docs in minutes.

**Hard rule:** no flag without a concrete `file:line` reference. Every finding is independently verifiable - no vibes, no speculation.

---

## Where the vault lives

Default: **inside the project** (e.g. `./myproject-kb/` alongside `src/`). Two reasons - scoping (one KB per project) and commit-friendliness (versioned markdown, your whole team onboards on the same KB).

Prefer it private per-developer? `echo "myproject-kb/" >> .gitignore`. Zero lock-in either way - it's markdown on disk.

---

## Honest trade-offs

- **No automatic capture.** Offboards are explicit. Design trade-off: explicit writes are curated writes.
- **No built-in semantic search.** Agents navigate by filenames and wiki-links. For a large vault, layer [Smart Connections](https://github.com/brianpetro/obsidian-smart-connections) on top - it runs against the same vault.
- **No cross-project user memory.** Per-project by design. Pair with CLAUDE.md or Mem0 for global.
- **Graph view needs Obsidian installed.** The vault is markdown either way - only the graph differentiator requires Obsidian.

---

## About, Contributing, Uninstall

Built by [Wael Masri](https://waelmas.com) - more AI coding tools at [github.com/waelmas](https://github.com/waelmas).

Flat layout: each plugin is a top-level folder at repo root (following [ComposioHQ/awesome-claude-plugins](https://github.com/ComposioHQ/awesome-claude-plugins)). See [AGENTS.md](AGENTS.md) for repo conventions. Open an issue to propose a new plugin.

Clean uninstall preserves your Obsidian vaults:

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/uninstall.sh | bash

# Windows PowerShell
iwr -useb https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/uninstall.ps1 | iex
```

[MIT License](LICENSE).
