# register-vault.ps1 - register an Obsidian vault programmatically (Windows)
#
# Usage:
#   .\register-vault.ps1 -VaultPath "C:\path\to\vault"
#
# Exit codes:
#   0  success (registered and verified, or already registered)
#   1  bad usage / missing .obsidian marker
#   3  Obsidian config not found
#   4  vault did not appear after registration (backup restored)
#
# What it does:
#   1. Locates Obsidian's vault registry at %APPDATA%\obsidian\obsidian.json
#   2. Backs up the registry with a timestamped suffix
#   3. Injects a new vault entry with a random 16-char hex ID
#   4. Force-quits Obsidian (otherwise the edit is overwritten on next clean quit)
#   5. Relaunches Obsidian
#   6. Verifies the vault appears in `obsidian vaults verbose`
#   7. On failure, restores the backup and exits non-zero

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$VaultPath
)

$ErrorActionPreference = 'Stop'

# Validate: must be an Obsidian vault (has .obsidian folder)
$ObsidianMarker = Join-Path $VaultPath ".obsidian"
if (-not (Test-Path $ObsidianMarker -PathType Container)) {
    Write-Error "'$VaultPath' is not an Obsidian vault (no .obsidian subfolder). Run kb-scaffold first."
    exit 1
}

$ConfigPath = Join-Path $env:APPDATA "obsidian\obsidian.json"
if (-not (Test-Path $ConfigPath -PathType Leaf)) {
    Write-Error "Obsidian config not found at: $ConfigPath. Is Obsidian installed and has it been run once?"
    exit 3
}

# Check if already registered (idempotent)
$ConfigJson = Get-Content $ConfigPath -Raw | ConvertFrom-Json
if ($ConfigJson.vaults) {
    foreach ($vault in $ConfigJson.vaults.PSObject.Properties) {
        if ($vault.Value.path -eq $VaultPath) {
            Write-Host "Info: vault at '$VaultPath' is already registered - no action needed."
            exit 0
        }
    }
}

# Back up the config
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupPath = "$ConfigPath.bak-$Timestamp"
Copy-Item -Path $ConfigPath -Destination $BackupPath
Write-Host "Backed up: $BackupPath"

# Generate a 16-char hex ID
$HexChars = '0123456789abcdef'.ToCharArray()
$NewId = -join (1..16 | ForEach-Object { $HexChars | Get-Random })

# Force-quit Obsidian
Write-Host "Quitting Obsidian..."
$Processes = Get-Process -Name "Obsidian" -ErrorAction SilentlyContinue
if ($Processes) {
    $Processes | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Inject the new vault entry
if (-not $ConfigJson.vaults) {
    $ConfigJson | Add-Member -MemberType NoteProperty -Name 'vaults' -Value ([pscustomobject]@{})
}
$TsMillis = [int64]([DateTimeOffset]::Now.ToUnixTimeMilliseconds())
$ConfigJson.vaults | Add-Member -MemberType NoteProperty -Name $NewId -Value ([pscustomobject]@{
    path = $VaultPath
    ts   = $TsMillis
})
$ConfigJson | ConvertTo-Json -Depth 20 | Set-Content -Path $ConfigPath -Encoding UTF8
Write-Host "Injected vault entry id=$NewId"

# Relaunch Obsidian
Write-Host "Relaunching Obsidian..."
$ObsidianExe = "$env:LOCALAPPDATA\Obsidian\Obsidian.exe"
if (Test-Path $ObsidianExe) {
    Start-Process -FilePath $ObsidianExe
} else {
    # Fall back to shell association
    Start-Process -FilePath "obsidian.exe" -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 5

# Verify
$VerifyOutput = ""
try {
    $VerifyOutput = & obsidian vaults verbose 2>$null
} catch {
    $VerifyOutput = ""
}

if ($VerifyOutput -match [regex]::Escape($VaultPath)) {
    Write-Host "Success: vault registered at '$VaultPath'"
    exit 0
}

# Failed - restore backup
Write-Error "Vault did not appear in 'obsidian vaults verbose' after registration."
Write-Host "Restoring backup: $BackupPath -> $ConfigPath"
Copy-Item -Path $BackupPath -Destination $ConfigPath -Force
Write-Host "You can register the vault manually via Obsidian's UI:"
Write-Host "  -> vault switcher (bottom-left) -> 'Open folder as vault' -> select '$VaultPath'"
exit 4
