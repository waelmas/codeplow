# OpenCode Tool Mapping

The obsidian-kb skills are written with Claude Code tool names. When a skill references a tool, use the OpenCode equivalent below.

| Skill references | OpenCode equivalent |
|-----------------|----------------------|
| `Bash` (run commands) | native `bash` tool |
| `Read` (file reading) | native file-read tool |
| `Write` (file creation) | native file-write tool |
| `Edit` (file editing) | native file-edit tool |
| `Grep` (search file content) | native grep tool |
| `Glob` (search files by name) | native glob tool |
| `Skill` (invoke a skill) | OpenCode's native `skill` tool |
| `Task` (dispatch subagent) | `@mention` syntax for a named subagent |
| `TodoWrite` (task tracking) | `todowrite` |
| `WebFetch` | native web-fetch tool |

## Subagents via @mention

OpenCode's subagent model is `@mention`-based rather than a structured `Task` call:

- Define a subagent profile (if available in your OpenCode version) or invoke one ad-hoc via `@general-purpose`.
- Dispatch multiple in one response for parallelism.
- Each subagent must still end with the STATUS line the skill requires.

If your OpenCode build doesn't support subagents for the skill's parallelism needs, fall back to single-session execution — see the equivalent note in `gemini-tools.md`.

## How the bootstrap lands

Unlike Claude Code or Cursor, OpenCode doesn't auto-load a plugin's primary skill via session-start hook output. Instead, the codeplow OpenCode plugin (`.opencode/plugins/obsidian-kb.js`) injects the `obsidian-kb` awareness skill into the first user message of each session via `experimental.chat.messages.transform`. That means the first reply the agent sees in every OpenCode session already includes the awareness guidance.

If context is missing or the plugin isn't loading, check:

```bash
opencode run --print-logs "hello" 2>&1 | grep -i obsidian-kb
```

## Skills discovery

The codeplow OpenCode plugin registers `obsidian-kb/skills/` as a skills path via the `config` hook. Skills with valid YAML frontmatter are discovered at session start. To list what's loaded:

```
use skill tool to list skills
```

## Plugin root

The plugin install path for OpenCode isn't a fixed env var — Bun manages the git-installed package under a cache directory. Skills that need the bundled scripts directory should resolve relative to the skill file itself when running under OpenCode, or rely on commands in the skill that don't reference `${CLAUDE_PLUGIN_ROOT}` directly.
