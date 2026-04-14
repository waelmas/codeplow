#!/usr/bin/env bash
# register-vault.sh - register an Obsidian vault programmatically (macOS + Linux)
#
# Usage:
#   register-vault.sh <absolute-vault-path>
#
# Exits:
#   0  success (vault registered and verified, or already registered)
#   1  bad usage / missing .obsidian marker
#   2  unsupported OS
#   3  Obsidian config not found
#   4  vault did not appear after registration (backup restored)
#
# What it does:
#   1. Locates Obsidian's vault registry (obsidian.json) for the current OS
#   2. Backs up the registry with a timestamped suffix
#   3. Injects a new vault entry: { "<random-16-hex-id>": { "path": "...", "ts": <now-ms> } }
#   4. Force-quits Obsidian (otherwise the edit is overwritten on next clean quit)
#   5. Relaunches Obsidian
#   6. Verifies the vault appears in `obsidian vaults verbose`
#   7. On failure, restores the backup and exits non-zero

set -euo pipefail

VAULT_PATH="${1:-}"
if [[ -z "$VAULT_PATH" ]]; then
  echo "Usage: $(basename "$0") <absolute-vault-path>" >&2
  exit 1
fi

# Validate: must be an Obsidian vault (has .obsidian/ marker)
if [[ ! -d "$VAULT_PATH/.obsidian" ]]; then
  echo "Error: '$VAULT_PATH' is not an Obsidian vault (no .obsidian/ subfolder)." >&2
  echo "       Run kb-scaffold first to create the folder + marker, then register." >&2
  exit 1
fi

# Detect OS and set the config path
if [[ "$OSTYPE" == "darwin"* ]]; then
  CONFIG_PATH="$HOME/Library/Application Support/obsidian/obsidian.json"
  OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Standard Linux (flatpak has a different path - see below)
  CONFIG_PATH="$HOME/.config/obsidian/obsidian.json"
  if [[ ! -f "$CONFIG_PATH" ]]; then
    # Try flatpak location
    FLATPAK_PATH="$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"
    if [[ -f "$FLATPAK_PATH" ]]; then
      CONFIG_PATH="$FLATPAK_PATH"
    fi
  fi
  OS="linux"
else
  echo "Error: Unsupported OS '$OSTYPE'. Use register-vault.ps1 on Windows." >&2
  exit 2
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Error: Obsidian config not found at: $CONFIG_PATH" >&2
  echo "       Is Obsidian installed and has it been run at least once?" >&2
  exit 3
fi

# Check if already registered (idempotent)
if command -v python3 >/dev/null 2>&1; then
  if python3 - "$CONFIG_PATH" "$VAULT_PATH" <<'PYEOF' 2>/dev/null
import json, sys
cfg, want = sys.argv[1], sys.argv[2]
with open(cfg) as f: data = json.load(f)
vaults = (data.get("vaults") or {})
sys.exit(0 if any(v.get("path") == want for v in vaults.values()) else 1)
PYEOF
  then
    echo "Info: vault at '$VAULT_PATH' is already registered - no action needed."
    exit 0
  fi
fi

# Back up the config
BACKUP_PATH="${CONFIG_PATH}.bak-$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "Backed up: $BACKUP_PATH"

# Generate a 16-char hex ID (Obsidian's own format)
if command -v openssl >/dev/null 2>&1; then
  NEW_ID=$(openssl rand -hex 8)
else
  NEW_ID=$(python3 -c "import secrets; print(secrets.token_hex(8))")
fi

# Force-quit Obsidian (gentle first, then hard)
echo "Quitting Obsidian..."
if [[ "$OS" == "macos" ]]; then
  osascript -e 'tell application "Obsidian" to quit' 2>/dev/null || true
  sleep 1
  if pgrep -x Obsidian >/dev/null 2>&1; then
    pkill -9 -x Obsidian 2>/dev/null || true
  fi
else  # linux
  pkill -x obsidian 2>/dev/null || pkill -f "Obsidian" 2>/dev/null || true
  sleep 1
  if pgrep -x obsidian >/dev/null 2>&1; then
    pkill -9 -x obsidian 2>/dev/null || true
  fi
fi
sleep 2

# Inject the new vault entry (Python for reliable JSON handling)
python3 - "$CONFIG_PATH" "$NEW_ID" "$VAULT_PATH" <<'PYEOF'
import json, sys, time
cfg, new_id, vault_path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(cfg) as f: data = json.load(f)
data.setdefault("vaults", {})[new_id] = {
    "path": vault_path,
    "ts": int(time.time() * 1000),
}
with open(cfg, "w") as f:
    json.dump(data, f, indent=2)
print(f"Injected vault entry id={new_id}")
PYEOF

# Relaunch Obsidian
echo "Relaunching Obsidian..."
if [[ "$OS" == "macos" ]]; then
  open -a Obsidian
else
  # Try common Linux launchers in order
  if command -v obsidian >/dev/null 2>&1; then
    (obsidian >/dev/null 2>&1 &) || true
  elif [[ -n "$(ls ~/Applications/Obsidian*.AppImage 2>/dev/null || true)" ]]; then
    (~/Applications/Obsidian*.AppImage >/dev/null 2>&1 &) || true
  elif command -v flatpak >/dev/null 2>&1; then
    (flatpak run md.obsidian.Obsidian >/dev/null 2>&1 &) || true
  else
    echo "Warning: couldn't find a way to launch Obsidian - please relaunch it manually." >&2
  fi
fi
sleep 5

# Verify the vault appears
if timeout 5 obsidian vaults verbose 2>/dev/null | grep -qF "$VAULT_PATH"; then
  echo "Success: vault registered at '$VAULT_PATH'"
  exit 0
fi

# Failed - restore backup
echo "Error: vault did not appear in 'obsidian vaults verbose' after registration." >&2
echo "       Restoring backup: $BACKUP_PATH → $CONFIG_PATH" >&2
cp "$BACKUP_PATH" "$CONFIG_PATH"
echo "       You can register the vault manually via Obsidian's UI:" >&2
echo "       → vault switcher (bottom-left) → 'Open folder as vault' → select '$VAULT_PATH'" >&2
exit 4
