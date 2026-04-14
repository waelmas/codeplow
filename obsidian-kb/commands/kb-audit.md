---
name: kb-audit
description: Audit your project's markdown docs against the actual code - flag stale claims with file:line evidence
argument-hint: "[vault name] [path-or-glob] - optional vault hint; optional path to a single doc or a glob to limit the audit"
---

# /kb-audit

Trigger the **kb-audit** skill. Read the instructions from `${CLAUDE_PLUGIN_ROOT}/skills/kb-audit/SKILL.md` in this plugin and follow them exactly.

Audits the existing markdown docs in the current project (README, ARCHITECTURE, CONTRIBUTING, docs/*, etc.) against the actual code. Produces a "Documentation Audit" note in the project's Obsidian vault listing every stale claim with `file:line` evidence.

Re-runnable any time. Use for quarterly doc refreshes or before a major rewrite.

User arguments: `$ARGUMENTS`
