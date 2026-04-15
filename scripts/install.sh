#!/usr/bin/env bash
# codeplow - one-step installer
# Detects installed AI coding tools and installs codeplow for each.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.sh | bash
#
# Or clone first:
#   git clone https://github.com/waelmas/codeplow ~/codeplow && bash ~/codeplow/scripts/install.sh

set -euo pipefail

REPO_URL="https://github.com/waelmas/codeplow"
REPO_OWNER="waelmas"
REPO_NAME="codeplow"
MARKETPLACE_NAME="codeplow"
PLUGIN_NAME="obsidian-kb"

# Where to cache a local clone (for Cursor + Codex which prefer local references)
CACHE_DIR="$HOME/.codeplow"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

bold "codeplow installer"
echo "Repo: $REPO_URL"
echo "Marketplace: $MARKETPLACE_NAME"
echo ""

# Clone or update the local cache (used by Cursor/Codex)
ensure_cache() {
  if [ -d "$CACHE_DIR/.git" ]; then
    echo "Updating cached repo at $CACHE_DIR..."
    git -C "$CACHE_DIR" pull --ff-only origin main >/dev/null 2>&1 || \
      yellow "(Couldn't fast-forward - continuing with existing cache.)"
  else
    echo "Cloning $REPO_URL into $CACHE_DIR..."
    git clone --depth 1 "$REPO_URL" "$CACHE_DIR" >/dev/null
  fi
}

# --- Claude Code --------------------------------------------------------------
install_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    return 1
  fi
  bold "→ Claude Code detected"
  if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE_NAME"; then
    echo "Marketplace '$MARKETPLACE_NAME' already registered."
  else
    echo "Registering marketplace..."
    claude plugin marketplace add "$REPO_OWNER/$REPO_NAME" || {
      red "Failed to add marketplace"; return 1;
    }
  fi
  if claude plugin list 2>/dev/null | grep -q "$PLUGIN_NAME@$MARKETPLACE_NAME"; then
    echo "Plugin '$PLUGIN_NAME' already installed - updating..."
    claude plugin update "$PLUGIN_NAME@$MARKETPLACE_NAME" || true
  else
    echo "Installing plugin '$PLUGIN_NAME@$MARKETPLACE_NAME'..."
    claude plugin install "$PLUGIN_NAME@$MARKETPLACE_NAME" || {
      red "Failed to install plugin"; return 1;
    }
  fi
  green "✓ Claude Code install complete - restart Claude Code to load."
}

# --- GitHub Copilot CLI -------------------------------------------------------
# Copilot CLI reuses Claude Code's plugin format — same marketplace.json and
# plugin.json files, same command shape. No separate manifests needed.
install_copilot() {
  if ! command -v copilot >/dev/null 2>&1; then
    return 1
  fi
  bold "→ GitHub Copilot CLI detected"
  if copilot plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE_NAME"; then
    echo "Marketplace '$MARKETPLACE_NAME' already registered."
  else
    echo "Registering marketplace..."
    copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" || {
      red "Failed to add marketplace (check: does your Copilot CLI build support 'plugin marketplace add'?)"
      return 1
    }
  fi
  if copilot plugin list 2>/dev/null | grep -q "$PLUGIN_NAME@$MARKETPLACE_NAME"; then
    echo "Plugin '$PLUGIN_NAME' already installed - updating..."
    copilot plugin update "$PLUGIN_NAME@$MARKETPLACE_NAME" 2>/dev/null || true
  else
    echo "Installing plugin '$PLUGIN_NAME@$MARKETPLACE_NAME'..."
    copilot plugin install "$PLUGIN_NAME@$MARKETPLACE_NAME" || {
      red "Failed to install plugin"; return 1;
    }
  fi
  green "✓ Copilot CLI install complete - start a new Copilot session to load."
}

# --- Cursor -------------------------------------------------------------------
install_cursor() {
  if ! command -v cursor >/dev/null 2>&1 && [ ! -d "/Applications/Cursor.app" ]; then
    return 1
  fi
  bold "→ Cursor detected"
  ensure_cache
  local cursor_local="$HOME/.cursor/plugins/local"
  mkdir -p "$cursor_local"
  local link="$cursor_local/$PLUGIN_NAME"
  if [ -L "$link" ] || [ -d "$link" ]; then
    echo "Removing existing $link..."
    rm -rf "$link"
  fi
  ln -s "$CACHE_DIR/$PLUGIN_NAME" "$link"
  green "✓ Cursor install complete - symlinked to $link"
  echo "  Restart Cursor or run 'Developer: Reload Window' to load."
}

# --- Codex CLI ----------------------------------------------------------------
install_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    return 1
  fi
  bold "→ Codex CLI detected"
  ensure_cache
  local codex_plugins="$HOME/.codex/plugins"
  mkdir -p "$codex_plugins"
  local link="$codex_plugins/$PLUGIN_NAME"
  if [ -L "$link" ] || [ -d "$link" ]; then
    echo "Removing existing $link..."
    rm -rf "$link"
  fi
  ln -s "$CACHE_DIR/$PLUGIN_NAME" "$link"

  # Also register a user-level marketplace pointing at the cached codeplow repo
  local agents_dir="$HOME/.agents/plugins"
  mkdir -p "$agents_dir"
  local marketplace_file="$agents_dir/marketplace.json"
  cat > "$marketplace_file" <<EOF
{
  "name": "$MARKETPLACE_NAME",
  "interface": { "displayName": "codeplow - by Wael Masri" },
  "owner": { "name": "Wael Masri" },
  "plugins": [
    {
      "name": "$PLUGIN_NAME",
      "source": { "source": "local", "path": "$CACHE_DIR/$PLUGIN_NAME" },
      "description": "Project knowledge base lifecycle via Obsidian vaults",
      "version": "0.1.2",
      "category": "Productivity"
    }
  ]
}
EOF
  green "✓ Codex install complete - plugin linked at $link"
  echo "  Marketplace registered at $marketplace_file"
  echo "  Restart Codex and open /plugins to verify."
}

# --- Run ----------------------------------------------------------------------
INSTALLED_ANY=0

if install_claude_code; then INSTALLED_ANY=1; fi
echo ""
if install_copilot; then INSTALLED_ANY=1; fi
echo ""
if install_cursor; then INSTALLED_ANY=1; fi
echo ""
if install_codex; then INSTALLED_ANY=1; fi
echo ""

if [ "$INSTALLED_ANY" -eq 0 ]; then
  yellow "No supported AI coding tool detected (claude, copilot, cursor, or codex)."
  yellow "Install one of them first, then re-run this script."
  exit 1
fi

bold "All done. Thanks for installing codeplow!"

# Remind about the Obsidian CLI prerequisite
echo ""
if command -v obsidian >/dev/null 2>&1; then
  green "✓ Obsidian CLI is on your PATH - you're set."
else
  yellow "⚠ Obsidian CLI not detected on your PATH."
  case "$OSTYPE" in
    darwin*) has_app=$([ -d /Applications/Obsidian.app ] && echo yes || echo no) ;;
    linux*)  has_app=$(ls ~/Applications/Obsidian*.AppImage /opt/Obsidian/* 2>/dev/null | head -n1 | grep -q . && echo yes || echo no) ;;
    *)       has_app=unknown ;;
  esac
  if [ "$has_app" = "yes" ]; then
    echo "  Obsidian itself is installed, so the CLI just needs to be enabled:"
    echo "    1) Open Obsidian"
    echo "    2) Settings → General → scroll to bottom"
    echo "    3) Toggle \"Command Line Interface\" ON"
    echo "    4) Close and reopen your terminal"
  else
    echo "  Install Obsidian first:"
    echo "    macOS:   brew install --cask obsidian   (or https://obsidian.md/download)"
    echo "    Linux:   flatpak install flathub md.obsidian.Obsidian"
    echo "    Windows: winget install Obsidian.Obsidian"
    echo "  Then enable the CLI in Settings → General → toggle \"Command Line Interface\"."
  fi
fi

echo ""
echo "More plugins at: $REPO_URL"
