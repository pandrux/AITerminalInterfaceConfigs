# windows-additions.ps1
# Dot-sourced from $PROFILE - Windows counterpart to shell/wsl-additions.sh
# Keep this clean: aliases, functions, and environment only.

# Resolve repo root from this script's location
$WindowsAdditionsDir = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $WindowsAdditionsDir

# -----------------------------------------------------------------------------
# AI CLI shortcuts
# -----------------------------------------------------------------------------

function update-ai-win {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\update-windows.ps1" @args
}
