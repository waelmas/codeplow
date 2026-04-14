---
name: kb-init
description: Initialize the project knowledge base - scaffolds a vault (if missing) and populates it with rich docs + stale-doc audit via parallel subagents
argument-hint: "[vault name] - optional vault name hint if auto-detection picks the wrong vault"
---

# /kb-init

Trigger the **kb-init** skill. Read the instructions from `${CLAUDE_PLUGIN_ROOT}/skills/kb-init/SKILL.md` in this plugin and follow them exactly.

This is the **full initialization** flow: if the project has no vault yet, it runs `kb-scaffold` first (with user confirmation), then proceeds to analyze the codebase via parallel subagents and write curated documentation notes - including a Documentation Audit that flags stale claims in existing project markdown.

**Always ask for user confirmation before proceeding** - this uses meaningful compute and takes a few minutes.

User arguments: `$ARGUMENTS`
