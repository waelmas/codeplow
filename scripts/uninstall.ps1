# codeplow - one-step uninstaller (Windows / PowerShell)
#
# Usage:
#   iwr -useb https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/uninstall.ps1 | iex
#
# Or locally:
#   powershell -ExecutionPolicy Bypass -File "$HOME\.codeplow\scripts\uninstall.ps1"
#
# Idempotent - safe to run even if only partially installed.
#
# Does NOT touch:
#   - Obsidian or its settings
#   - Any of your vaults
#   - Notes/handoffs inside vaults
#   - Your PATH or PowerShell profile

$ErrorActionPreference = 'Continue'

$MarketplaceName = 'codeplow'
$PluginName      = 'obsidian-kb'
$CacheDir        = Join-Path $env:USERPROFILE '.codeplow'

function Write-Heading($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK($msg)      { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Info($msg)    { Write-Host "  $msg" }
function Write-Warn2($msg)   { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

Write-Host 'codeplow uninstaller (Windows)' -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "This removes codeplow from each AI coding tool where it's installed."
Write-Host "Your Obsidian vaults and the notes/handoffs inside them are NOT touched."
Write-Host ""

$RemovedAny = $false

# --- Claude Code ------------------------------------------------------------
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Heading '→ Claude Code'
    $plugins = (claude plugin list 2>&1 | Out-String)
    if ($plugins -match "$PluginName@$MarketplaceName") {
        Write-Info "Uninstalling plugin '$PluginName@$MarketplaceName'..."
        claude plugin uninstall "$PluginName@$MarketplaceName" *> $null
        Write-OK 'Plugin uninstalled.'
    } else {
        Write-Info "Plugin '$PluginName@$MarketplaceName' was not installed - skipping."
    }
    $marketplaces = (claude plugin marketplace list 2>&1 | Out-String)
    if ($marketplaces -match [regex]::Escape($MarketplaceName)) {
        Write-Info "Removing marketplace '$MarketplaceName'..."
        claude plugin marketplace remove $MarketplaceName *> $null
        Write-OK 'Marketplace removed.'
    } else {
        Write-Info "Marketplace '$MarketplaceName' was not registered - skipping."
    }
    $RemovedAny = $true
}

# --- GitHub Copilot CLI -----------------------------------------------------
if (Get-Command copilot -ErrorAction SilentlyContinue) {
    Write-Heading '→ GitHub Copilot CLI'
    $plugins = (copilot plugin list 2>&1 | Out-String)
    if ($plugins -match "$PluginName@$MarketplaceName") {
        Write-Info "Uninstalling plugin '$PluginName@$MarketplaceName'..."
        copilot plugin uninstall "$PluginName@$MarketplaceName" *> $null
        Write-OK 'Plugin uninstalled.'
    } else {
        Write-Info "Plugin '$PluginName@$MarketplaceName' was not installed - skipping."
    }
    $marketplaces = (copilot plugin marketplace list 2>&1 | Out-String)
    if ($marketplaces -match [regex]::Escape($MarketplaceName)) {
        Write-Info "Removing marketplace '$MarketplaceName'..."
        copilot plugin marketplace remove $MarketplaceName *> $null
        Write-OK 'Marketplace removed.'
    } else {
        Write-Info "Marketplace '$MarketplaceName' was not registered - skipping."
    }
    $RemovedAny = $true
}

# --- Cursor -----------------------------------------------------------------
$CursorExe = Join-Path $env:LOCALAPPDATA 'Programs\cursor\Cursor.exe'
if ((Get-Command cursor -ErrorAction SilentlyContinue) -or (Test-Path $CursorExe)) {
    Write-Heading '→ Cursor'
    $link = Join-Path $env:USERPROFILE ".cursor\plugins\local\$PluginName"
    if (Test-Path $link) {
        Remove-Item -Recurse -Force $link
        Write-OK "Removed $link"
    } else {
        Write-Info "No codeplow link at $link - skipping."
    }
    $RemovedAny = $true
}

# --- Codex CLI --------------------------------------------------------------
if (Get-Command codex -ErrorAction SilentlyContinue) {
    Write-Heading '→ Codex CLI'
    $codexLink = Join-Path $env:USERPROFILE ".codex\plugins\$PluginName"
    if (Test-Path $codexLink) {
        Remove-Item -Recurse -Force $codexLink
        Write-OK "Removed $codexLink"
    } else {
        Write-Info "No codeplow link at $codexLink - skipping."
    }

    # Remove the marketplace file ONLY if it contains just codeplow
    $marketplaceFile = Join-Path $env:USERPROFILE '.agents\plugins\marketplace.json'
    if (Test-Path $marketplaceFile) {
        $content = Get-Content $marketplaceFile -Raw
        if ($content -match [regex]::Escape($MarketplaceName)) {
            # Count how many distinct marketplace name entries exist at the top level
            $nameCount = ([regex]::Matches($content, '"name"\s*:\s*"')).Count
            if ($nameCount -eq 1) {
                Remove-Item $marketplaceFile
                Write-OK "Removed $marketplaceFile (only contained codeplow)."
            } else {
                Write-Warn2 "$marketplaceFile contains other marketplaces - leaving it alone."
                Write-Info 'Edit it manually to remove the codeplow entry if you want.'
            }
        } else {
            Write-Info "No codeplow entry in $marketplaceFile - skipping."
        }
    } else {
        Write-Info 'No codeplow marketplace file found - skipping.'
    }
    $RemovedAny = $true
}

# --- Cache dir --------------------------------------------------------------
if (Test-Path $CacheDir) {
    Write-Heading '→ Local cache'
    Remove-Item -Recurse -Force $CacheDir
    Write-OK "Removed $CacheDir"
    $RemovedAny = $true
}

Write-Host ''
if (-not $RemovedAny) {
    Write-Warn2 "Nothing to remove - codeplow doesn't appear to be installed on this machine."
    exit 0
}

Write-Host 'Done. codeplow has been removed.' -ForegroundColor Green
Write-Host 'Your Obsidian vaults and their notes are untouched.'
Write-Host 'Thanks for trying it - feedback welcome at https://github.com/waelmas/codeplow/issues'
