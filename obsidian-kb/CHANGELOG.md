# Changelog — obsidian-kb

All notable changes to the **`obsidian-kb`** plugin are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
