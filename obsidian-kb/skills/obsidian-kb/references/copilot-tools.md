# Copilot CLI Tool Mapping

The obsidian-kb skills are written with Claude Code tool names. When a skill references a tool, use the GitHub Copilot CLI equivalent below.

| Skill references | Copilot CLI equivalent |
|-----------------|----------------------|
| `Bash` (run commands) | `bash` |
| `Read` (file reading) | `view` |
| `Write` (file creation) | `create` |
| `Edit` (file editing) | `edit` |
| `Grep` (search file content) | `grep` |
| `Glob` (search files by name) | `glob` |
| `Skill` (invoke a skill) | `skill` |
| `Task` (dispatch subagent) | `task` with `agent_type: "general-purpose"` |
| `TodoWrite` (task tracking) | `sql` with the built-in `todos` table |
| `WebFetch` | `web_fetch` |
| `WebSearch` | No equivalent — use `web_fetch` with a search-engine URL |

## Subagents in kb-init and kb-audit

`kb-init` and `kb-audit` dispatch parallel subagents to analyze the codebase. On Copilot CLI:

- Use multiple `task` calls in a single response to run them in parallel.
- Pass `agent_type: "general-purpose"` — Copilot's built-in general agent.
- Use `read_agent` / `list_agents` to inspect status while they run.

Each subagent must still end with the STATUS line the skill requires (`STATUS: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED`).

## Async shell sessions (optional)

Copilot CLI uniquely supports long-running background shell sessions via `bash` with `async: true`, `write_bash`, `read_bash`, `stop_bash`, `list_bash`. None of the kb-* skills require this — skip unless you're extending a skill with a long-running command.

## Additional tools to be aware of

| Tool | When relevant |
|------|---------------|
| `store_memory` | Alternative to writing into the vault for transient facts. The kb-* skills deliberately use the vault instead — prefer the vault. |
| `report_intent` | Status-line updates during long-running skills (e.g. kb-init). Optional polish. |
| GitHub MCP tools (`github-mcp-server-*`) | Useful in /kb-audit when the skill walks project docs that reference issues / PRs. |

## Plugin root

When skills reference `${CLAUDE_PLUGIN_ROOT}`, fall back:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${COPILOT_PLUGIN_ROOT:-}}"
```

The two env vars typically resolve to the same path in a codeplow install.
