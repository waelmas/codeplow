# Gemini CLI Tool Mapping

The obsidian-kb skills are written with Claude Code tool names. When a skill references a tool, use the Gemini CLI equivalent below.

| Skill references | Gemini CLI equivalent |
|-----------------|----------------------|
| `Bash` (run commands) | `run_shell_command` |
| `Read` (file reading) | `read_file` |
| `Write` (file creation) | `write_file` |
| `Edit` (file editing) | `replace` |
| `Grep` (search file content) | `grep_search` |
| `Glob` (search files by name) | `glob` |
| `Skill` (invoke a skill) | `activate_skill` |
| `TodoWrite` (task tracking) | `write_todos` |
| `WebFetch` | `web_fetch` |
| `WebSearch` | `google_web_search` |
| `Task` (dispatch subagent) | **No equivalent** — see below |

## No subagent support — fallback behavior

Gemini CLI has no equivalent to Claude Code's `Task` tool. Two obsidian-kb skills dispatch parallel subagents:

- **`kb-init`** parallelizes Architecture / Tech Stack / Project Structure / Documentation Audit subagent writes.
- **`kb-audit`** parallelizes per-file audit passes on large projects.

On Gemini CLI, these degrade to **single-session execution**: work through each subagent's task serially in the same session, writing each output to the vault as you go. The end artifact (the populated vault, the audit report) is the same — it just takes longer. The skill's STATUS-line discipline still applies: treat each block of work as if it were a subagent and end with `STATUS: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED` before moving on.

Do NOT try to fake parallelism by dispatching multiple `run_shell_command` calls concurrently — the skills need LLM-level reasoning in each "subagent," not just shell commands.

## Additional Gemini CLI tools to be aware of

| Tool | When relevant |
|------|---------------|
| `save_memory` | Alternative to writing into the vault. The kb-* skills deliberately use the vault instead — prefer the vault so the record is portable + committable. |
| `ask_user` | Useful in kb-init / kb-scaffold when confirming vault location before creating it. |
| `tracker_create_task` | Richer alternative to `write_todos` for longer workflows like kb-init. Optional. |
| `enter_plan_mode` / `exit_plan_mode` | Use before kb-audit if you want to survey the docs first without edits. Optional. |

## Plugin root

When skills reference `${CLAUDE_PLUGIN_ROOT}`, there's no direct Gemini equivalent because extensions aren't plugins in the Claude sense. The obsidian-kb extension installs to `~/.gemini/extensions/codeplow/` (or wherever `gemini extensions install` lands it). Resolve skill-bundled scripts with:

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.gemini/extensions/codeplow}"
```
