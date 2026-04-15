# Changelog — obsidian-kb

All notable changes to the **`obsidian-kb`** plugin are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] — 2026-04-16

### Added
- **GitHub Copilot CLI** as a natively supported platform. Copilot CLI reuses Claude Code's plugin format (`.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json`), so the install path is just `copilot plugin marketplace add waelmas/codeplow && copilot plugin install obsidian-kb@codeplow`. Detected and installed by `scripts/install.sh` + `scripts/install.ps1`; removed by the matching uninstallers.
- **Version-bump tooling.** New `.version-bump.json` declares the 6 JSON manifests that carry a version field; new `scripts/bump-version.sh` provides `--check` (show versions, detect drift), `--audit` (also greps repo for undeclared version strings), and `<new-version>` (atomic bump with post-audit). Replaces the manual `sed` one-liner previously documented in `AGENTS.md`.
- **Tool-mapping references** under `obsidian-kb/skills/obsidian-kb/references/`: `copilot-tools.md`, `gemini-tools.md`, `opencode-tools.md`. Skills stay written in Claude Code tool names; each reference maps those names to the target platform's equivalents (and flags fallback behavior — e.g. Gemini's lack of subagents degrading `/kb-init` + `/kb-audit` to serial).

### Changed
- **`README.md`**: explicit two-step frame (*"1. Install — in your terminal"* / *"2. Use — inside your AI agent's chat / session"*) added so users no longer paste slash commands into bash. New per-tool reload callout (e.g. `/reload-plugins` for Claude Code) and a troubleshooting note for "not seeing slash-command autocomplete." "Native on..." line expanded to include Copilot CLI.
- **`INSTALL.md`**: detection step extended with `command -v copilot`; new Step 4 for Copilot CLI (Cursor/Codex renumbered to 5/6); `/reload-plugins` guidance added to Claude Code's user-facing message; "Report back to the user" section now requires the agent to state the terminal-vs-chat distinction explicitly.
- **`UNINSTALL.md`**: detection step extended; new Step 3 for Copilot (Cursor/Codex renumbered to 4/5/6); verify section covers both Claude and Copilot plugin lists.
- **`AGENTS.md`**: platform list updated to four tools with explicit note on Copilot CLI reusing Claude's manifests; "Version bumps happen in 7 places" section replaced with the new script workflow.
- **`obsidian-kb/skills/obsidian-kb/SKILL.md`**: Platform Notes section expanded to cover Copilot CLI (same as Claude), Gemini CLI (no subagents — serial fallback), and OpenCode (awareness injected via OpenCode plugin's first-message transform). Each entry points at its `references/*-tools.md` companion.

## [0.1.1] — 2026-04-15

### Added
- **`/kb-update`** skill + slash command — refresh KB notes after code changes. Reviews git activity and session context, surgically edits stale vault notes with `file:line` evidence, and flags new concepts as candidates (never silently creates notes). Complements `/kb-audit` — `/kb-update` maintains the vault; `/kb-audit` checks the project's own markdown.
- **`/kb-handoff`** slash command — alias for `/kb-offboard`.

### Changed
- Top-level `README.md` restructured: replaced TL;DR / Why / Commands / Compares sections with a single "What's in the marketplace" capability matrix keyed to commands.
- `obsidian-kb/README.md` restructured: added explicit **Prerequisites**, **Install**, and **Getting Started** sections. Prerequisites now call out Obsidian's CLI being **OFF by default** — must be enabled in Settings → General → Command Line Interface.
- `INSTALL.md`: command list surfaces `/kb-update` and the `/kb-handoff` alias; clarified `/kb-audit` scope ("project's own markdown").
- Version string bumped `0.1.0 → 0.1.1` across all 7 declarations: 3 marketplace manifests (`.claude-plugin/`, `.cursor-plugin/`, `.agents/plugins/`), 3 plugin manifests under `obsidian-kb/`, and the embedded Codex-marketplace JSON inside `scripts/install.sh` and `scripts/install.ps1`.

## [0.1.0] — 2026-04-15

Initial release.

### Added
- **`obsidian-kb`** plugin: persistent per-project memory for AI coding agents, backed by real Obsidian vaults. Ships as the first plugin in the [codeplow](https://github.com/waelmas/codeplow) marketplace.
- Seven skills shipped: `kb-init`, `kb-scaffold`, `kb-audit`, `kb-onboard`, `kb-offboard`, `kb-graph`, plus the `obsidian-kb` awareness dispatcher.
- Six slash-command wrappers under `obsidian-kb/commands/`.
- Multi-platform distribution: native support for **Claude Code** (`.claude-plugin/`), **Cursor** (`.cursor-plugin/`), and **Codex CLI** (`.codex-plugin/` + `.agents/plugins/`).
- Bundled `register-vault.sh` / `register-vault.ps1` scripts for Method B vault registration (backs up `obsidian.json`, force-quits Obsidian, injects vault entry, relaunches, verifies).
- Repo-level `install.sh` / `install.ps1` + `uninstall.sh` / `uninstall.ps1` installers.
- Filesystem-first write discipline across all skills (Obsidian CLI's `vault=` argument is broken in 1.12.7 and silently falls back to the active vault — all writes use `mkdir -p` + heredoc instead).
