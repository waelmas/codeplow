# obsidian-kb

**A per-project knowledge base for AI coding agents, backed by a real [Obsidian](https://obsidian.md) vault.** Persistent memory your agent can read between sessions, with a built-in audit that cites `file:line` evidence for every stale doc claim, and a KB-refresh skill that keeps the vault aligned with live code.

Native on **Claude Code**, **Cursor**, and **Codex CLI**. Part of the [codeplow](https://github.com/waelmas/codeplow) marketplace — start there for the pitch and comparisons. This page is the deep reference.

---

## What you get

| Capability | Command | What happens |
|---|---|---|
| Project knowledge base auto-built from your codebase | `/kb-init` | Parallel subagents write structured notes (Architecture, Tech Stack, Patterns, etc.) into the vault. |
| Keep the KB aligned with code as it evolves | `/kb-update` | Reviews git activity + session context, surgically refreshes stale KB notes with `file:line` evidence, flags new concepts as candidates. |
| Audit your project's own markdown for drift | `/kb-init` or `/kb-audit` | Flags every stale claim in project docs with `file:line` evidence. |
| Session handoff — beat context rot | `/kb-offboard` *(alias `/kb-handoff`)* | Writes an adaptive handoff into the vault, linked from the index and wiki-linked to related KB notes. |
| Session onboarding — pick up the thread | `/kb-onboard` | New agent reads the latest handoff + the linked KB notes. |
| Visual knowledge map | `/kb-graph` | Opens the vault in Obsidian's graph view. |
| Empty scaffold (hand-populated KB) | `/kb-scaffold` | Vault structure only. |

---

## Prerequisites

obsidian-kb needs two things:

1. **Obsidian desktop app** (v1.12+) — `brew install --cask obsidian` / `winget install Obsidian.Obsidian` / download from [obsidian.md](https://obsidian.md/download).
2. **Obsidian's CLI enabled.** The CLI ships with the app but is **OFF by default** — open Obsidian → **Settings → General → scroll to the bottom → toggle "Command Line Interface" ON**, then close and reopen your terminal.

Both are required. Preflight walks you through enabling the CLI if you forget, but knowing upfront saves a round-trip.

---

## Install

One-line shell scripts (detects your AI tools and installs for each):

```bash
# macOS / Linux / WSL
curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.sh | bash

# Windows PowerShell
iwr -useb https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.ps1 | iex
```

Or per platform:

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

---

## Getting started — first 5 minutes

Point your AI agent at a real project and:

1. **`/kb-init`.** Scaffolds a vault alongside your project, analyzes the codebase via parallel subagents into structured notes, runs the Documentation Audit in parallel. 3–6 minutes.
2. **Open `Research/Documentation Audit.md`.** Every stale doc claim with `file:line` evidence. Tell the agent *"fix the stale claims"* — it works from evidence, not vibes.
3. **`/kb-graph`.** See your project as a visual knowledge map in Obsidian.
4. **The daily loop.** At session end: `/kb-update` to refresh KB notes for whatever changed, then `/kb-offboard` (or `/kb-handoff`) to write the handoff. New session: `/kb-onboard`. Fresh context, preserved thread, KB still trustworthy.

---

## The loops this plugin is built for

**Handoff loop — against context rot.** Long sessions drift; new sessions start blind. `/kb-offboard` writes an adaptive handoff into the vault, wiki-linked to relevant existing notes and appended to the vault's index. Next session's `/kb-onboard` reads it plus the linked notes. You reset context without losing the thread.

**Update loop — against KB rot.** Code evolves; the KB must follow or the agent starts reading stale truth. `/kb-update` reviews git activity since the last handoff and the session's conversation, then surgically edits affected KB notes with `file:line` evidence. New concepts get flagged as candidates for notes (never silently created).

**Audit loop — against doc rot in your project.** `/kb-init` (or `/kb-audit` standalone) walks every `.md` file *in the project itself* and flags stale claims. Distinct scope from `/kb-update`: audit checks your project's user-owned markdown; update maintains the vault.

Hard rule shared across all three: **no claim flagged stale — and no KB edit — without `file:line` evidence.** No vibes. Every finding is a clickable coordinate you verify in seconds.

---

## Why Obsidian, not a vector database

Most "AI memory" tools store knowledge in an opaque index. When you ask *"what does my agent actually know?"*, the answer is a JSON blob or a vector distance.

obsidian-kb puts the agent's memory in a vault **you can open**:

- Edit by hand when the agent got something wrong — it's a `.md` file.
- See connections in the graph view before your next session.
- Own your data — leave anytime, nothing to migrate.
- Commit it alongside your code (default) or `.gitignore` it for a private per-dev KB.

---

## How `/kb-init` works

1. **Preflight** — verifies Obsidian is installed and its CLI is enabled, resolves project name.
2. **Vault creation** — a folder inside your project (default: `./MyProject KB/`, title-cased from the repo name) with three directories: `Architecture/`, `Research/`, `Sessions/`.
3. **Parallel subagents** — each explores one slice of the codebase and writes a structured note.
4. **Audit subagent** — runs in parallel, cross-checks every existing `.md` file against live code.
5. **Index** — a `README.md` at the vault root wiki-links every note.
6. **Report** — summary of what was created, plus top audit recommendations.

Typical run: 3–6 minutes. Re-run safe: doesn't clobber hand-edits or notes you've marked preserved.

---

## A handoff, concretely

```markdown
---
type: session-handoff
date: 2026-04-15
---

# Session Handoff - 2026-04-15

## TL;DR
Shipped auth refactor (JWT + refresh tokens). 12 files changed, 947 tests passing.

## Next Steps
1. Verify `/refresh` against the stress-test script
2. Update `ARCHITECTURE.md` for the new token flow (flagged in the audit)

## Key Files Changed
- `src/middleware/auth.ts` - new JWT middleware
- `src/services/auth/refresh.ts` - refresh token rotation
- `tests/auth.test.ts` - 47 new cases

## Watch Out
- Migration `042_user_tokens.sql` runs on next deploy - manual review
- `refresh_tokens` table has no TTL yet

## Links
- [[Architecture/System Overview]]
- [[Research/Documentation Audit]]
```

Handoffs are short when sessions were small, rich when they weren't. Links back into the KB mean `/kb-onboard` can escalate depth on demand.

---

## FAQ

**Do I have to commit the vault?**
Your call. Default is vault-in-project for commit-friendliness; `.gitignore` it for private per-dev. No server, no proprietary store, no lock-in either way.

**Does this work without Obsidian?**
The vault is plain markdown — any agent reads/edits it fine. Only the graph view and some speedups need Obsidian installed.

**Will it auto-capture my sessions?**
No. `/kb-offboard` and `/kb-update` are explicit. Design choice: curated writes > noisy auto-capture. If you want auto-capture too, layer [claude-mem](https://github.com/thedotmack/claude-mem) on top — different problem, composes fine.

**Can it semantic-search a huge vault?**
Not natively — navigation is by filenames and wiki-links. For very large vaults, layer [Smart Connections](https://github.com/brianpetro/obsidian-smart-connections) for embedding-based search against the same vault.

**Does the audit hallucinate staleness?**
The skill enforces `file:line` evidence for every flag. Models can still mismatch — but every flag is cheap to verify: click the coordinate, see the code, decide.

**What's the difference between `/kb-update` and `/kb-audit`?**
Scope. `/kb-update` maintains the vault's own notes against live code. `/kb-audit` reviews your project's user-owned markdown (README.md, ARCHITECTURE.md, etc.) against live code. Both use the same `file:line`-evidence rule.

---

## License

[MIT](../LICENSE).
