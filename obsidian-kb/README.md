# obsidian-kb

**A per-project knowledge base for AI coding agents, backed by [Obsidian](https://obsidian.md) vaults.** Persistent memory your agent can read between sessions, with a built-in audit that cites `file:line` evidence for every stale doc claim.

Native on **Claude Code**, **Cursor**, and **Codex CLI**. Part of the [codeplow](https://github.com/waelmas/codeplow) marketplace - start there for install and comparisons. This page is the deep reference.

---

## TL;DR

- `/kb-init` on day 1 → scaffolds a vault, analyzes your codebase into structured notes, audits existing markdown for drift.
- `/kb-offboard` → `/kb-onboard` around every session → handoffs persist the thread so new sessions start fresh *and* briefed. This is the core loop against context rot.
- Vault is plain markdown on disk inside your project by default - committable, grep-able, editable by hand, zero lock-in.
- Closest sibling is Cline Memory Bank; everything else in the category is either a vector DB over chat history or a single-file config. This is none of those.

---

## Commands

| Command | What it does |
|---|---|
| `/kb-init` | Scaffold vault, dispatch parallel subagents to write Architecture / Tech Stack / Patterns / etc. notes, run Documentation Audit in parallel. |
| `/kb-audit` | Re-run the audit only. `file:line` evidence for every stale claim. |
| `/kb-onboard` | Agent reads the latest handoff + relevant KB notes; picks up where you left off. |
| `/kb-offboard` | Agent writes an adaptive handoff and updates the KB with what was learned/decided. |
| `/kb-graph` | Open the vault in Obsidian's graph view. |
| `/kb-scaffold` | Empty structure only - for hand-populated KBs. |

---

## The two loops

**Session handoff loop - against context rot.** Long sessions drift and new sessions start blind. `/kb-offboard` writes a handoff proportional to what happened (TL;DR, decisions, files changed, gotchas, next steps, wiki-links back into the KB). Next session's `/kb-onboard` reads it in seconds. You reset context without losing the thread.

**Audit loop - against doc rot.** LLM-generated projects especially accumulate stale markdown. `/kb-init` (or `/kb-audit` later) walks every `.md` file in the project and cross-checks concrete claims against the code. The result - `Research/Documentation Audit.md` - flags every drift with a concrete `file:line` reference. A sample audit lives in the [top-level README](https://github.com/waelmas/codeplow#the-documentation-auditor).

Hard rule: **no claim flagged stale without `file:line` evidence.** No vibes. Every finding is a clickable coordinate you verify in seconds.

---

## Why Obsidian, not a vector database

Most "AI memory" tools store knowledge in an opaque index. When you ask *"what does my agent actually know?"*, the answer is a JSON blob or a vector distance.

obsidian-kb puts the agent's memory in a vault **you can open**:

- Edit by hand when the agent got something wrong - it's a `.md` file.
- See connections in the graph view before your next session.
- Own your data - leave anytime, nothing to migrate.
- Commit it alongside your code (default) or `.gitignore` it for a private per-dev KB.

---

## How `/kb-init` works

1. **Preflight** - verifies Obsidian is installed and its CLI is enabled, resolves project name.
2. **Vault creation** - sibling folder to your project (e.g. `./myproject-kb/`) with standard directories: `Architecture/`, `Research/`, `Session Handoffs/`, `Tech/`, `Patterns/`.
3. **Parallel subagents** - each explores one slice of the codebase (architecture, tech stack, testing, domain model, key patterns) and writes a structured note.
4. **Audit subagent** - runs in parallel, cross-checks every existing `.md` file against live code.
5. **Index** - a `README.md` at the vault root wiki-links every note.
6. **Report** - summary of what was created, plus top audit recommendations.

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

## Install & requirements

See the [codeplow install guide](https://github.com/waelmas/codeplow#install). Requirement worth calling out: [Obsidian](https://obsidian.md) v1.12+ with its **Command Line Interface** enabled (Settings → General → bottom → toggle **Command Line Interface** ON - it's off by default). Preflight walks you through it.

---

## FAQ

**Do I have to commit the vault?**
Your call. Default is vault-in-project for commit-friendliness; `.gitignore` it for private per-dev. No server, no proprietary store, no lock-in either way.

**Does this work without Obsidian?**
The vault is plain markdown - any agent reads/edits it fine. Only the graph view and some speedups need Obsidian installed.

**Will it auto-capture my sessions?**
No. Offboards are explicit. Design choice: curated writes > noisy auto-capture. If you want auto-capture too, layer [claude-mem](https://github.com/thedotmack/claude-mem) on top - different problem, composes fine.

**Can it semantic-search a huge vault?**
Not natively - navigation is by filenames and wiki-links. For very large vaults, layer [Smart Connections](https://github.com/brianpetro/obsidian-smart-connections) for embedding-based search against the same vault.

**Does the audit hallucinate staleness?**
The skill enforces `file:line` evidence for every flag. Models can still mismatch - but every flag is cheap to verify: click the coordinate, see the code, decide.

---

## License

[MIT](../LICENSE).
