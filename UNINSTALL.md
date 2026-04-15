# codeplow - Uninstall Instructions for AI Agents

**This file is for AI coding agents.** If a human asks you to uninstall codeplow, read these instructions and execute them in their environment.

Mirrors `INSTALL.md`. Idempotent - safe to run even if codeplow was only partially installed.

---

## Guarantees

What this removal does NOT touch:
- Obsidian or its settings
- Any of the user's vaults
- Any notes, handoffs, or content the user created inside vaults
- Shell PATH or shell config

If the user's main concern is "will I lose my project knowledge bases?" - **no**. Vaults are just folders on disk. Uninstalling codeplow leaves them exactly where they are.

## Steps

Detect which tools are present and clean each one up. If a tool isn't installed, skip it silently.

### Step 1: Detect present tools

```bash
command -v claude   && echo "claude-code-present"
command -v copilot  && echo "copilot-cli-present"
command -v cursor   && echo "cursor-present"
command -v codex    && echo "codex-present"
```

### Step 2: Claude Code

```bash
# Uninstall the plugin (if installed)
claude plugin list 2>/dev/null | grep -q "obsidian-kb@codeplow" \
  && claude plugin uninstall obsidian-kb@codeplow

# Remove the marketplace (if registered)
claude plugin marketplace list 2>/dev/null | grep -q "codeplow" \
  && claude plugin marketplace remove codeplow
```

### Step 3: GitHub Copilot CLI

Copilot CLI reuses Claude Code's plugin format, so the teardown is identical in shape — just a different binary.

```bash
# Uninstall the plugin (if installed)
copilot plugin list 2>/dev/null | grep -q "obsidian-kb@codeplow" \
  && copilot plugin uninstall obsidian-kb@codeplow

# Remove the marketplace (if registered)
copilot plugin marketplace list 2>/dev/null | grep -q "codeplow" \
  && copilot plugin marketplace remove codeplow
```

### Step 4: Cursor

```bash
rm -rf "$HOME/.cursor/plugins/local/obsidian-kb"
```

Tell the user: **"Run 'Developer: Reload Window' in Cursor so it drops the plugin from the current session."**

### Step 5: Codex CLI

```bash
# Remove the plugin symlink
rm -rf "$HOME/.codex/plugins/obsidian-kb"

# Remove the marketplace.json - but only if it ONLY contains codeplow.
# If it contains other marketplaces, leave it alone and tell the user to edit it manually.
MP="$HOME/.agents/plugins/marketplace.json"
if [ -f "$MP" ] && grep -q '"codeplow"' "$MP"; then
  count=$(grep -c '"name"' "$MP" 2>/dev/null || echo 0)
  if [ "$count" = "1" ]; then
    rm "$MP"
  else
    echo "Note: $MP contains multiple marketplaces. Leaving intact. Edit manually to remove the codeplow entry."
  fi
fi
```

### Step 6: Remove the local cache (optional but recommended)

The install script cloned the codeplow repo to `~/.codeplow` as a cache for Cursor/Codex. Safe to remove:

```bash
rm -rf "$HOME/.codeplow"
```

## Verify

Confirm each tool no longer has codeplow:

```bash
# Claude Code
claude plugin list 2>/dev/null | grep -i codeplow   # should be empty
claude plugin marketplace list 2>/dev/null | grep -i codeplow   # should be empty

# Copilot CLI
copilot plugin list 2>/dev/null | grep -i codeplow   # should be empty
copilot plugin marketplace list 2>/dev/null | grep -i codeplow   # should be empty

# Cursor
ls "$HOME/.cursor/plugins/local/obsidian-kb" 2>/dev/null   # should error

# Codex
ls "$HOME/.codex/plugins/obsidian-kb" 2>/dev/null          # should error
cat "$HOME/.agents/plugins/marketplace.json" 2>/dev/null   # should not mention codeplow
```

## Report back

Tell the user:

1. Which tools were cleaned up.
2. That their vaults and notes are untouched.
3. Point them at https://github.com/waelmas/codeplow/issues if they uninstalled because of a bug or missing feature - feedback is more valuable than a quiet exit.
