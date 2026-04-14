#!/usr/bin/env bash
# codeplow - one-step uninstaller
# Removes codeplow from any installed AI coding tools on this machine.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/uninstall.sh | bash
#
# Or locally:
#   bash ~/.codeplow/scripts/uninstall.sh
#
# What it does (idempotent - safe to run even if only partially installed):
#   Claude Code: uninstall plugin, remove marketplace
#   Cursor:      remove the symlink in ~/.cursor/plugins/local/
#   Codex:       remove ~/.agents/plugins/marketplace.json (if it's ours)
#   Cache:       remove ~/.codeplow if it exists
#
# What it does NOT do:
#   - Touch Obsidian, Obsidian's config, or any of your vaults
#   - Delete notes, handoffs, or anything you created in vaults
#   - Change your PATH or shell config
#
# If anything was installed outside this script's scope, it won't be touched.

set -uo pipefail

MARKETPLACE_NAME="codeplow"
PLUGIN_NAME="obsidian-kb"
CACHE_DIR="$HOME/.codeplow"

bold()   { printf '\033[1m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red()    { printf '\033[31m%s\033[0m\n' "$*"; }
info()   { printf '  %s\n' "$*"; }

bold "codeplow uninstaller"
echo "This removes codeplow from each AI coding tool where it's installed."
echo "Your Obsidian vaults and the notes/handoffs inside them are NOT touched."
echo ""

REMOVED_ANY=0

# --- Claude Code --------------------------------------------------------------
uninstall_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    return 1
  fi
  bold "→ Claude Code"

  if claude plugin list 2>/dev/null | grep -q "$PLUGIN_NAME@$MARKETPLACE_NAME"; then
    info "Uninstalling plugin '$PLUGIN_NAME@$MARKETPLACE_NAME'..."
    if claude plugin uninstall "$PLUGIN_NAME@$MARKETPLACE_NAME" >/dev/null 2>&1; then
      green "  ✓ Plugin uninstalled."
    else
      yellow "  ⚠ Could not uninstall plugin automatically. You can remove it via: claude plugin uninstall $PLUGIN_NAME@$MARKETPLACE_NAME"
    fi
  else
    info "Plugin '$PLUGIN_NAME@$MARKETPLACE_NAME' was not installed - skipping."
  fi

  if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE_NAME"; then
    info "Removing marketplace '$MARKETPLACE_NAME'..."
    if claude plugin marketplace remove "$MARKETPLACE_NAME" >/dev/null 2>&1; then
      green "  ✓ Marketplace removed."
    else
      yellow "  ⚠ Could not remove marketplace automatically. You can remove it via: claude plugin marketplace remove $MARKETPLACE_NAME"
    fi
  else
    info "Marketplace '$MARKETPLACE_NAME' was not registered - skipping."
  fi

  return 0
}

# --- Cursor -------------------------------------------------------------------
uninstall_cursor() {
  if ! command -v cursor >/dev/null 2>&1 && [ ! -d "/Applications/Cursor.app" ]; then
    return 1
  fi
  bold "→ Cursor"
  local link="$HOME/.cursor/plugins/local/$PLUGIN_NAME"
  if [ -L "$link" ] || [ -e "$link" ]; then
    rm -rf "$link"
    green "  ✓ Removed $link"
  else
    info "No codeplow link at $link - skipping."
  fi
  return 0
}

# --- Codex CLI ----------------------------------------------------------------
uninstall_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    return 1
  fi
  bold "→ Codex CLI"
  local codex_link="$HOME/.codex/plugins/$PLUGIN_NAME"
  if [ -L "$codex_link" ] || [ -e "$codex_link" ]; then
    rm -rf "$codex_link"
    green "  ✓ Removed $codex_link"
  else
    info "No codeplow link at $codex_link - skipping."
  fi

  # Remove the marketplace file only if it's ours (check for the codeplow name)
  local marketplace_file="$HOME/.agents/plugins/marketplace.json"
  if [ -f "$marketplace_file" ] && grep -q "\"$MARKETPLACE_NAME\"" "$marketplace_file" 2>/dev/null; then
    # If the file only contains our marketplace, remove it entirely.
    # If it contains other marketplaces too, don't touch it (unlikely in our install flow, but respectful).
    if grep -c '"name"' "$marketplace_file" 2>/dev/null | grep -q "^1$"; then
      rm "$marketplace_file"
      green "  ✓ Removed $marketplace_file (only contained codeplow)."
    else
      yellow "  ⚠ $marketplace_file contains other marketplaces - leaving it alone."
      info "    Edit it manually to remove the codeplow entry if you want."
    fi
  else
    info "No codeplow marketplace file found - skipping."
  fi
  return 0
}

# --- Cache dir ----------------------------------------------------------------
uninstall_cache() {
  if [ -d "$CACHE_DIR" ]; then
    bold "→ Local cache"
    rm -rf "$CACHE_DIR"
    green "  ✓ Removed $CACHE_DIR"
    return 0
  fi
  return 1
}

# --- Run ----------------------------------------------------------------------

if uninstall_claude_code; then REMOVED_ANY=1; fi
echo ""
if uninstall_cursor; then REMOVED_ANY=1; fi
echo ""
if uninstall_codex; then REMOVED_ANY=1; fi
echo ""
if uninstall_cache; then REMOVED_ANY=1; fi
echo ""

if [ "$REMOVED_ANY" -eq 0 ]; then
  yellow "Nothing to remove - codeplow doesn't appear to be installed on this machine."
  yellow "If you think it's installed somewhere else, let me know."
  exit 0
fi

bold "Done. codeplow has been removed."
echo "Your Obsidian vaults and their notes are untouched."
echo "Thanks for trying it - feedback welcome at https://github.com/waelmas/codeplow/issues"
