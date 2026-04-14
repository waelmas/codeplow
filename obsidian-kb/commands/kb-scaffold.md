---
name: kb-scaffold
description: Scaffold an empty Obsidian knowledge base vault for the current project (no codebase analysis - for that, use /kb-init)
argument-hint: "[vault name] - optional name for the new vault (default: <project dir> KB)"
---

# /kb-scaffold

Trigger the **kb-scaffold** skill. Read the instructions from `${CLAUDE_PLUGIN_ROOT}/skills/kb-scaffold/SKILL.md` in this plugin and follow them exactly.

This creates an empty vault with the standard folder structure (`Architecture/`, `Research/`, `Sessions/`) and placeholder notes. It does NOT analyze your codebase or generate content - that's what `/kb-init` does.

Use `/kb-scaffold` when you want to manage the vault's content yourself. Use `/kb-init` for the full flow (scaffold + codebase analysis + documentation audit).

User arguments: `$ARGUMENTS`
