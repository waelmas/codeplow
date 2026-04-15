# codeplow

**Plugins for AI coding agents that fight context rot, doc rot, and forgotten decisions.** Native on **Claude Code**, **GitHub Copilot CLI**, **Cursor**, and **Codex CLI**.

Built by [Wael Masri](https://waelmas.com).

---

## What's in the marketplace

Today, one plugin. More coming — they'll land as siblings in this repo.

### [`obsidian-kb`](obsidian-kb/) — persistent, per-project memory for your AI coding agent

A real [Obsidian](https://obsidian.md) vault per project, sitting inside the project folder by default (committable), holding structured knowledge your agent can read between sessions.

| Capability | Command | What happens |
|---|---|---|
| Build a **project knowledge base** from your codebase | `/kb-init` | Parallel subagents write Architecture / Tech Stack / Patterns / etc. notes into the vault. 3–6 minutes. |
| **Keep the KB aligned** with recent changes | `/kb-update` | Reviews git activity + session context, surgically refreshes stale KB notes with `file:line` evidence, flags new concepts as candidates. |
| **Audit your project docs** for drift | `/kb-init` or `/kb-audit` | Flags every stale claim in the project's own markdown (README.md, ARCHITECTURE.md, etc.) with `file:line` evidence. |
| **Session handoff** — beat context rot | `/kb-offboard` *(alias `/kb-handoff`)* | Writes an adaptive handoff into the vault (TL;DR, decisions, files changed, gotchas, next steps), linked from the index and wiki-linked to related KB notes. |
| **Session onboarding** — pick up in a new session | `/kb-onboard` | New agent reads the latest handoff and the linked KB notes before starting work. |
| **Visual knowledge map** | `/kb-graph` | Opens the vault in Obsidian's graph view. |
| Empty scaffold (hand-populated KB) | `/kb-scaffold` | Vault structure only, no codebase analysis. |

The vault is plain markdown on disk — committable alongside your code, editable by hand, grep-able, zero lock-in. Not a vector DB, not a CLAUDE.md replacement.

---

## Prerequisites

`obsidian-kb` needs two things:

1. **Obsidian desktop app** (v1.12+) — `brew install --cask obsidian` / `winget install Obsidian.Obsidian` / download from [obsidian.md](https://obsidian.md/download).
2. **Obsidian's CLI enabled.** The CLI ships with the app but is **OFF by default.** Open Obsidian → **Settings → General → scroll to the bottom → toggle "Command Line Interface" ON**, then close and reopen your terminal so `obsidian` lands on PATH.

Both are required. The plugin preflight tells you which is missing and walks you through enabling the CLI, but knowing upfront saves a round-trip.

---

## Install

Installation has **two steps** that live in two different places. Keep them straight or you'll paste the wrong command into the wrong place — which is the most common source of confusion.

> **1. Install the plugin — runs in your regular terminal** (bash / zsh / PowerShell).
> **2. Use the plugin — runs inside your AI agent's chat or session**, not in your terminal. Commands like `/kb-init` are typed to the agent. They start with `/` because they're slash commands the agent recognizes; your shell doesn't.

---

### 1. Install — in your terminal

Easiest — ask your agent to do it for you (from its own chat):

> Install codeplow for me by following https://raw.githubusercontent.com/waelmas/codeplow/main/INSTALL.md

Or paste the one-liner into your terminal. It detects which AI tools you have installed and registers codeplow for each:

```bash
# macOS / Linux / WSL — paste into your terminal
curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.sh | bash
```

```powershell
# Windows PowerShell — paste into a PowerShell window
iwr -useb https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.ps1 | iex
```

#### Or install manually per platform — also terminal

All four snippets run in your regular terminal. They register codeplow with each tool's plugin system — they don't start the agent.

**Claude Code**
```bash
claude plugin marketplace add waelmas/codeplow
claude plugin install obsidian-kb@codeplow
```

**GitHub Copilot CLI** — reuses Claude Code's plugin format, so the same manifests serve both. Just a different binary:
```bash
copilot plugin marketplace add waelmas/codeplow
copilot plugin install obsidian-kb@codeplow
```

**Cursor**
```bash
git clone https://github.com/waelmas/codeplow ~/codeplow
mkdir -p ~/.cursor/plugins/local
ln -s ~/codeplow/obsidian-kb ~/.cursor/plugins/local/obsidian-kb
# Then in Cursor: Command Palette → Developer: Reload Window
```

**Codex CLI**
```bash
git clone https://github.com/waelmas/codeplow ~/codeplow
mkdir -p ~/.agents/plugins
cp ~/codeplow/.agents/plugins/marketplace.json ~/.agents/plugins/marketplace.json
# Then start Codex and open /plugins from inside its session
```

Once any of those finish, reload the agent so it picks up the plugin:

- **Claude Code** — inside your chat, run `/reload-plugins`. If that's unavailable, close Claude Code and reopen it.
- **Copilot CLI** — start a fresh Copilot session (close and reopen).
- **Cursor** — Command Palette → *Developer: Reload Window*.
- **Codex CLI** — start a fresh Codex session, then open `/plugins` inside it to verify.

You're done in your terminal — everything from here happens **inside the agent**.

---

### 2. Use — inside your AI agent's chat / session

Open Claude Code (or Copilot CLI / Cursor agent chat / Codex), point it at a real project, and type the slash commands below **to the agent**, not into your shell. If you paste `/kb-init` into bash, bash will complain — it's not a shell command.

1. **Type `/kb-init` in your agent.** The agent scaffolds a vault (e.g. `./myproject-kb/`), dispatches parallel subagents to write Architecture / Tech Stack / Patterns notes, and runs a Documentation Audit against your existing markdown. 3–6 minutes end to end.

2. **Open `Research/Documentation Audit.md`** (outside the agent — in Obsidian or any editor). Every stale claim in your project's docs, with `file:line` evidence. If your project has AI-generated docs, expect surprises. Then back in the agent, tell it *"fix the stale claims in README.md"* — it works from the evidence, not vibes.

3. **Type `/kb-graph` in the agent.** Opens the vault in Obsidian's graph view; click through the wiki-linked notes to see your project as a knowledge map.

4. **The daily loop — all typed to the agent.** At session end: `/kb-update` to refresh KB notes with what changed, then `/kb-offboard` (or `/kb-handoff`) to write the handoff. Start a fresh session and `/kb-onboard` — new agent reads the handoff plus the updated KB, picks up with clean context. **This is the loop most users run daily.**

> **Not seeing slash-command autocomplete?** You probably still need to reload the agent from step 1 — in Claude Code try `/reload-plugins` first, otherwise close and reopen. On Codex CLI there's no slash-command UI — just say *"run kb-init"* or *"catch me up on this project"* and the skill triggers from intent.

---

## Why this exists

**Context rot.** Long sessions drift — decisions made at token 2,000 get lost by token 50,000. Starting a new session resets everything, including the decisions. The fix isn't stuffing more into context. It's externalizing the thread so each new session starts fresh *and* briefed.

**Doc rot.** Every codebase accumulates stale markdown: a README that says `npm run start`, an `ARCHITECTURE.md` describing a service split three refactors ago. AI-written projects are especially prone — the agent generates docs that match the commit, nothing updates them later, the next session reads them as truth.

`obsidian-kb` attacks both with one pattern: a real Obsidian vault holding structured project memory, kept aligned with live code via `/kb-update`, audited with `file:line` citations, plus explicit session handoffs that live inside the same vault.

---

## The Documentation Auditor

The feature nothing else in this category ships.

When `/kb-init` runs (or `/kb-audit` on its own), one subagent walks every existing `.md` file in the project and cross-checks concrete claims against the code. The result lives in `Research/Documentation Audit.md`:

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

**Hard rule:** no flag without a concrete `file:line` reference. Every finding is independently verifiable — no vibes, no speculation.

---

## Where the vault lives

Default: **inside the project** (e.g. `./myproject-kb/` alongside `src/`). Two reasons — scoping (one KB per project) and commit-friendliness (versioned markdown, your whole team onboards on the same KB).

Prefer it private per-developer? `echo "myproject-kb/" >> .gitignore`. Zero lock-in either way — it's markdown on disk.

---

## How it compares

| | obsidian-kb | [Cline Memory Bank](https://docs.cline.bot/prompting/cline-memory-bank) | [claude-mem](https://github.com/thedotmack/claude-mem) | [Mem0](https://mem0.ai) / [Zep](https://getzep.com) | CLAUDE.md / AGENTS.md |
|---|---|---|---|---|---|
| **Storage** | Markdown in Obsidian vault | Plain markdown | SQLite + Chroma (vector) | Proprietary graph + vector | Single markdown file |
| **User owns the data?** | Yes — portable `.md` | Yes | Local, but opaque | OSS self-host or cloud | Yes |
| **Audit with `file:line` citations** | **Yes** | No | No | No | No |
| **Cross-platform** (Claude Code / Cursor / Codex) | **Yes, one plugin** | Cline only | Claude-primary | SDK into any app | Tool-specific file |
| **Session continuity** | Explicit onboard/offboard | Implicit ("read all on reset") | Auto-capture, opaque | Retrieval on query | None |
| **Scope** | Per-project vault | Per-project folder | Global + per-project | Per-user / per-app | Per-project file |

- **Closest sibling — Cline Memory Bank.** Also markdown, also per-project. Differs: Cline-only, fixed schema, no audit, no graph, no explicit handoff loop.
- **Different category — claude-mem / Mem0 / Zep / Supermemory.** Vector retrieval over chat history (*"what did we discuss?"*). obsidian-kb curates project docs (*"what does this project look like, and where were we?"*). Compose them if you want both.
- **Different scope — CLAUDE.md / AGENTS.md / Cursor Rules.** Short bootstrap files. Point them at the vault for depth.
- **Opposite direction — [Smart Connections](https://github.com/brianpetro/obsidian-smart-connections).** Brings AI *into* Obsidian. obsidian-kb brings Obsidian *into* your AI coding agent.

---

## Honest trade-offs

- **No automatic capture.** Offboards and KB updates are explicit. Design trade-off: explicit writes are curated writes.
- **No built-in semantic search.** Agents navigate by filenames and wiki-links. For a large vault, layer [Smart Connections](https://github.com/brianpetro/obsidian-smart-connections) on top — it runs against the same vault.
- **No cross-project user memory.** Per-project by design. Pair with CLAUDE.md or Mem0 for global.
- **Graph view needs Obsidian installed.** The vault is markdown either way — only the graph differentiator requires Obsidian.

---

## About, Contributing, Uninstall

Built by [Wael Masri](https://waelmas.com) — more AI coding tools at [github.com/waelmas](https://github.com/waelmas).

Flat layout: each plugin is a top-level folder at repo root (following [ComposioHQ/awesome-claude-plugins](https://github.com/ComposioHQ/awesome-claude-plugins)). See [AGENTS.md](AGENTS.md) for repo conventions. Open an issue to propose a new plugin.

Clean uninstall preserves your Obsidian vaults:

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/uninstall.sh | bash

# Windows PowerShell
iwr -useb https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/uninstall.ps1 | iex
```

[MIT License](LICENSE).
