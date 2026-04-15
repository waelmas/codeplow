# codeplow - Install Instructions for AI Agents

**This file is for AI coding agents.** If a human asks you to install codeplow, read these instructions and execute them in their environment.

---

## What codeplow is

A plugin marketplace for AI coding agents (Claude Code, GitHub Copilot CLI, Cursor, Codex CLI). Today it ships `obsidian-kb`: persistent project memory + a built-in documentation auditor + session handoff and onboarding for agents, powered by Obsidian vaults.

Repo: https://github.com/waelmas/codeplow

## Installation steps

Follow these in order. If any step fails, stop and report the error to the user before proceeding.

### Step 1: Detect the AI coding tool(s) present

Check which tools are installed:

```bash
command -v claude   && echo "claude-code-present"
command -v copilot  && echo "copilot-cli-present"
command -v cursor   && echo "cursor-present"
command -v codex    && echo "codex-present"
```

Install codeplow for **every tool that is present**. If multiple tools are installed, the user probably uses more than one - install for all.

If you're running inside one specific tool (you usually know which), start with that one.

### Step 2: Check Obsidian (prerequisite)

codeplow's only plugin requires Obsidian **and** its Command Line Interface enabled. Two distinct things - check both:

```bash
command -v obsidian
```

If it returns a path, you're set; skip to Step 3. If not found, figure out which of two cases you're in:

**Case A - Obsidian app is installed but CLI isn't enabled**

Check:
```bash
# macOS
test -d /Applications/Obsidian.app && echo "app-installed"
# Linux
ls ~/Applications/Obsidian*.AppImage /opt/Obsidian/* 2>/dev/null
# Windows (WSL)
ls "/mnt/c/Program Files/Obsidian/Obsidian.exe" 2>/dev/null
```

If the app exists but `command -v obsidian` is empty, the CLI is disabled in Obsidian's settings (this is the default - users must enable it once). Tell the user exactly this:

> "Obsidian is installed, but its Command Line Interface is disabled. To enable it:
>
> 1. Open Obsidian.
> 2. Click the **Settings** gear (bottom-left) or press `Cmd/Ctrl + ,`.
> 3. In the sidebar, choose **General**.
> 4. Scroll to the bottom of the General page.
> 5. Toggle **'Command Line Interface'** ON.
>
> Then close and reopen your terminal so it picks up the updated PATH."

Wait for the user to confirm, then re-check `command -v obsidian` before continuing.

**Case B - Obsidian is not installed at all**

Show the OS-specific install command and then remind them to enable the CLI afterwards:

- **macOS:** `brew install --cask obsidian` - or download: https://obsidian.md/download
- **Linux:** `flatpak install flathub md.obsidian.Obsidian` - or download: https://obsidian.md/download
- **Windows:** `winget install Obsidian.Obsidian` - or download: https://obsidian.md/download

After install, guide them through the CLI enable steps from Case A (Settings → General → bottom → toggle "Command Line Interface").

### Step 3: Install for Claude Code

Only run if Claude Code is present.

```bash
claude plugin marketplace add waelmas/codeplow
claude plugin install obsidian-kb@codeplow
```

Expected success output:
```
✔ Successfully added marketplace: codeplow
✔ Successfully installed plugin: obsidian-kb@codeplow
```

Tell the user: **"Inside your Claude Code chat, run `/reload-plugins` to pick up codeplow without restarting. If that doesn't work or isn't available in your build, close Claude Code and open it again."**

### Step 4: Install for GitHub Copilot CLI

Only run if Copilot CLI is present. **Copilot CLI reuses Claude Code's plugin format** — same commands, same manifests on our end, different binary.

```bash
copilot plugin marketplace add waelmas/codeplow
copilot plugin install obsidian-kb@codeplow
```

Expected success output is similar to Claude Code's. Tell the user: **"Start a new Copilot session (or run its reload-plugins equivalent if available) to pick up codeplow. Once loaded, slash commands like `/kb-init`, `/kb-onboard`, and `/kb-offboard` are typed inside that session, not in your raw terminal."**

### Step 5: Install for Cursor

Only run if Cursor is present.

```bash
# Clone the repo to a cached location
git clone https://github.com/waelmas/codeplow "$HOME/.codeplow" 2>/dev/null || \
  (cd "$HOME/.codeplow" && git pull --ff-only origin main)

# Symlink the plugin into Cursor's local plugins directory
mkdir -p "$HOME/.cursor/plugins/local"
ln -sfn "$HOME/.codeplow/obsidian-kb" "$HOME/.cursor/plugins/local/obsidian-kb"
```

Tell the user: **"In Cursor, open the Command Palette and run 'Developer: Reload Window' to pick up the plugin."**

### Step 6: Install for Codex CLI

Only run if Codex is present.

```bash
# Cache the repo (same location as Cursor shares it)
git clone https://github.com/waelmas/codeplow "$HOME/.codeplow" 2>/dev/null || \
  (cd "$HOME/.codeplow" && git pull --ff-only origin main)

# Register as a user-level marketplace
mkdir -p "$HOME/.agents/plugins"
cat > "$HOME/.agents/plugins/marketplace.json" <<EOF
{
  "name": "codeplow",
  "interface": { "displayName": "codeplow" },
  "owner": { "name": "Wael Masri" },
  "plugins": [
    {
      "name": "obsidian-kb",
      "source": { "source": "local", "path": "$HOME/.codeplow/obsidian-kb" },
      "description": "Persistent project memory for AI agents + documentation auditor - powered by Obsidian vaults",
      "version": "0.1.2",
      "category": "Productivity"
    }
  ]
}
EOF
```

Tell the user: **"In Codex, open `/plugins` to see and install `obsidian-kb`."**

## Verify installation

For whichever tool you installed, verify it worked:

- **Claude Code:** `claude plugin list | grep obsidian-kb` - should show `obsidian-kb@codeplow  ✔ enabled`
- **Copilot CLI:** `copilot plugin list | grep obsidian-kb` - should show `obsidian-kb@codeplow` enabled
- **Cursor:** `ls -la ~/.cursor/plugins/local/obsidian-kb` - should show a symlink
- **Codex:** `cat ~/.agents/plugins/marketplace.json | grep obsidian-kb` - should show the plugin entry

## Report back to the user

Once installation is complete, tell the user clearly:

1. Which tool(s) you installed it for.
2. Any required restart / reload actions they need to take.
3. **Where to type the slash commands** — this is the most common point of confusion. Be explicit:

   > "Installation happens in your terminal, but the slash commands below are typed **inside your AI agent's chat / session**, not into your shell. If you paste `/kb-init` into bash, it'll just error out — that's expected. Start or reload the agent, then type them there."

4. The commands they can now use (all typed in the agent, not the terminal):
   - `/kb-init` - **main command.** Initialize the project knowledge base: scaffold vault + analyze codebase + populate with rich docs + audit existing markdown for stale claims
   - `/kb-update` - refresh KB notes after code changes; surgical edits with file:line evidence, flags new concepts as candidates
   - `/kb-audit` - re-runnable audit of the project's own markdown (README, ARCHITECTURE, etc.) against current code
   - `/kb-scaffold` - just create an empty vault structure (use when you want to manage content manually)
   - `/kb-onboard` - brief the agent on what happened last session
   - `/kb-offboard` (alias `/kb-handoff`) - write an adaptive session handoff into the vault
   - `/kb-graph` - open the vault graph view in Obsidian

   Note for Codex CLI users: Codex has no slash-command UI — tell them to say *"run kb-init"* or *"catch me up on this project"* instead; the skill triggers from natural intent.

Suggest they start with `/kb-init` on a project they care about — inside the agent.

## Troubleshooting

### "Plugin not found in marketplace"

The marketplace wasn't registered. Rerun Step 3 - the first command (`marketplace add`) registers it.

### "obsidian CLI not found"

The Obsidian app is installed but the CLI isn't on PATH. On macOS, the CLI ships bundled with Obsidian at `/Applications/Obsidian.app/Contents/MacOS/obsidian` - either add that directory to PATH or symlink it:
```bash
sudo ln -s /Applications/Obsidian.app/Contents/MacOS/obsidian /usr/local/bin/obsidian
```

### Multiple AI coding tools detected

Install for all of them. Users who have both Claude Code and Cursor usually want the plugin available everywhere.

## Notes for future updates

When codeplow releases a new plugin version, users can update with:

- **Claude Code:** `claude plugin update obsidian-kb@codeplow`
- **Copilot CLI:** `copilot plugin update obsidian-kb@codeplow`
- **Cursor/Codex:** `cd ~/.codeplow && git pull` (the symlink + local marketplace pick up changes on next reload)
