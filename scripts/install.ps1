# codeplow - one-step installer (Windows / PowerShell)
#
# Usage:
#   iwr -useb https://raw.githubusercontent.com/waelmas/codeplow/main/scripts/install.ps1 | iex
#
# Or clone first:
#   git clone https://github.com/waelmas/codeplow "$HOME\codeplow"
#   powershell -ExecutionPolicy Bypass -File "$HOME\codeplow\scripts\install.ps1"
#
# Detects which AI coding tools are installed (Claude Code, Cursor, Codex)
# and installs codeplow for each. Idempotent - safe to re-run.

$ErrorActionPreference = 'Continue'

$RepoUrl         = 'https://github.com/waelmas/codeplow'
$MarketplaceName = 'codeplow'
$PluginName      = 'obsidian-kb'
$CacheDir        = Join-Path $env:USERPROFILE '.codeplow'

function Write-Heading($msg) { Write-Host "`n$msg" -ForegroundColor Cyan }
function Write-OK($msg)      { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn2($msg)   { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err2($msg)    { Write-Host "  ✘ $msg" -ForegroundColor Red }

Write-Host "codeplow installer (Windows)" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "Repo:        $RepoUrl"
Write-Host "Marketplace: $MarketplaceName"
Write-Host ""

function Ensure-Cache {
    if (Test-Path (Join-Path $CacheDir '.git')) {
        Write-Host "Updating cached repo at $CacheDir..."
        git -C $CacheDir pull --ff-only origin main *> $null
    } else {
        Write-Host "Cloning $RepoUrl into $CacheDir..."
        git clone --depth 1 $RepoUrl $CacheDir *> $null
    }
}

$InstalledAny = $false

# --- Claude Code ------------------------------------------------------------
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Heading '→ Claude Code detected'
    $marketplaces = (claude plugin marketplace list 2>&1 | Out-String)
    if ($marketplaces -notmatch [regex]::Escape($MarketplaceName)) {
        Write-Host '  Registering marketplace...'
        claude plugin marketplace add "waelmas/$MarketplaceName"
    } else {
        Write-Host "  Marketplace '$MarketplaceName' already registered."
    }
    $plugins = (claude plugin list 2>&1 | Out-String)
    if ($plugins -match "$PluginName@$MarketplaceName") {
        Write-Host "  Plugin '$PluginName' already installed - updating..."
        claude plugin update "$PluginName@$MarketplaceName"
    } else {
        Write-Host "  Installing plugin '$PluginName@$MarketplaceName'..."
        claude plugin install "$PluginName@$MarketplaceName"
    }
    Write-OK "Claude Code install complete - restart Claude Code to load."
    $InstalledAny = $true
}

# --- GitHub Copilot CLI -----------------------------------------------------
# Copilot CLI reuses Claude Code's plugin format — same manifests, same commands.
if (Get-Command copilot -ErrorAction SilentlyContinue) {
    Write-Heading '→ GitHub Copilot CLI detected'
    $marketplaces = (copilot plugin marketplace list 2>&1 | Out-String)
    if ($marketplaces -notmatch [regex]::Escape($MarketplaceName)) {
        Write-Host '  Registering marketplace...'
        copilot plugin marketplace add "waelmas/$MarketplaceName"
    } else {
        Write-Host "  Marketplace '$MarketplaceName' already registered."
    }
    $plugins = (copilot plugin list 2>&1 | Out-String)
    if ($plugins -match "$PluginName@$MarketplaceName") {
        Write-Host "  Plugin '$PluginName' already installed - updating..."
        copilot plugin update "$PluginName@$MarketplaceName" 2>&1 | Out-Null
    } else {
        Write-Host "  Installing plugin '$PluginName@$MarketplaceName'..."
        copilot plugin install "$PluginName@$MarketplaceName"
    }
    Write-OK "Copilot CLI install complete - start a new Copilot session to load."
    $InstalledAny = $true
}

# --- Cursor -----------------------------------------------------------------
$CursorExe = Join-Path $env:LOCALAPPDATA 'Programs\cursor\Cursor.exe'
if ((Get-Command cursor -ErrorAction SilentlyContinue) -or (Test-Path $CursorExe)) {
    Write-Heading '→ Cursor detected'
    Ensure-Cache
    $cursorLocal = Join-Path $env:USERPROFILE '.cursor\plugins\local'
    New-Item -ItemType Directory -Force -Path $cursorLocal | Out-Null
    $link = Join-Path $cursorLocal $PluginName
    if (Test-Path $link) {
        Write-Host "  Removing existing $link..."
        Remove-Item -Recurse -Force $link
    }
    # On Windows, symbolic links need admin OR developer mode. Fall back to a directory junction,
    # which any user can create and Cursor treats as a folder.
    $target = Join-Path $CacheDir $PluginName
    try {
        New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
        Write-OK "Symlinked $link -> $target"
    } catch {
        cmd.exe /c mklink /J "$link" "$target" | Out-Null
        Write-OK "Junctioned $link -> $target (developer mode not enabled - used junction)"
    }
    Write-Host "  Restart Cursor or run 'Developer: Reload Window' to load."
    $InstalledAny = $true
}

# --- Codex CLI --------------------------------------------------------------
if (Get-Command codex -ErrorAction SilentlyContinue) {
    Write-Heading '→ Codex CLI detected'
    Ensure-Cache
    $codexPlugins = Join-Path $env:USERPROFILE '.codex\plugins'
    New-Item -ItemType Directory -Force -Path $codexPlugins | Out-Null
    $link = Join-Path $codexPlugins $PluginName
    if (Test-Path $link) {
        Write-Host "  Removing existing $link..."
        Remove-Item -Recurse -Force $link
    }
    $target = Join-Path $CacheDir $PluginName
    try {
        New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
    } catch {
        cmd.exe /c mklink /J "$link" "$target" | Out-Null
    }

    # Register a user-level marketplace pointing at the cached plugin dir
    $agentsDir = Join-Path $env:USERPROFILE '.agents\plugins'
    New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
    $marketplaceFile = Join-Path $agentsDir 'marketplace.json'
    $pluginPath = ($target -replace '\\','/')
    $json = @"
{
  "name": "$MarketplaceName",
  "interface": { "displayName": "codeplow - by Wael Masri" },
  "owner": { "name": "Wael Masri" },
  "plugins": [
    {
      "name": "$PluginName",
      "source": { "source": "local", "path": "$pluginPath" },
      "description": "Project knowledge base lifecycle via Obsidian vaults",
      "version": "0.1.2",
      "category": "Productivity"
    }
  ]
}
"@
    Set-Content -Path $marketplaceFile -Value $json -Encoding UTF8
    Write-OK "Codex install complete - plugin linked at $link"
    Write-Host "  Marketplace registered at $marketplaceFile"
    Write-Host "  Restart Codex and open /plugins to verify."
    $InstalledAny = $true
}

Write-Host ""
if (-not $InstalledAny) {
    Write-Warn2 'No supported AI coding tool detected (claude, copilot, cursor, or codex).'
    Write-Warn2 'Install one of them first, then re-run this script.'
    exit 1
}

Write-Host 'All done. Thanks for installing codeplow!' -ForegroundColor Green

# Remind about the Obsidian CLI prerequisite
Write-Host ''
if (Get-Command obsidian -ErrorAction SilentlyContinue) {
    Write-OK 'Obsidian CLI is on your PATH - you''re set.'
} else {
    Write-Warn2 'Obsidian CLI not detected on your PATH.'
    $obsidianExe = Join-Path $env:LOCALAPPDATA 'Obsidian\Obsidian.exe'
    if (Test-Path $obsidianExe) {
        Write-Host '  Obsidian itself is installed, so the CLI just needs to be enabled:'
        Write-Host '    1) Open Obsidian'
        Write-Host '    2) Settings → General → scroll to bottom'
        Write-Host '    3) Toggle "Command Line Interface" ON'
        Write-Host '    4) Close and reopen your PowerShell session'
    } else {
        Write-Host '  Install Obsidian first:'
        Write-Host '    winget install Obsidian.Obsidian'
        Write-Host '    (or download: https://obsidian.md/download)'
        Write-Host '  Then enable the CLI in Settings → General → toggle "Command Line Interface".'
    }
}

Write-Host ''
Write-Host "More plugins at: $RepoUrl"
