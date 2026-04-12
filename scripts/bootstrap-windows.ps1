# bootstrap-windows.ps1
# Run this on any new Windows 11 machine to set up the terminal config
# Usage: .\bootstrap-windows.ps1 [-WSLDistro "Ubuntu"]
#
# What it does:
#   1. Checks for WezTerm installation
#   2. Links wezterm.lua from repo into WezTerm's config location
#   3. Checks for required CLI tools and reports status
#   4. Optionally runs WSL bootstrap

param(
    [string]$WSLDistro = "Ubuntu",
    [switch]$SkipWSL
)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent

Write-Host ""
Write-Host "=== Terminal Config Bootstrap ===" -ForegroundColor Cyan
Write-Host "Repo: $RepoRoot"
Write-Host "WSL Distro: $WSLDistro"
Write-Host ""

# -----------------------------------------------------------------------------
# 1. WezTerm config
# -----------------------------------------------------------------------------
Write-Host "[1/4] WezTerm config..." -ForegroundColor Yellow

$WeztermConfigDir = "$env:USERPROFILE\.config\wezterm"
$WeztermConfigFile = "$WeztermConfigDir\wezterm.lua"
$SourceConfig = "$RepoRoot\wezterm\wezterm.lua"

if (-not (Test-Path $WeztermConfigDir)) {
    New-Item -ItemType Directory -Path $WeztermConfigDir | Out-Null
    Write-Host "  Created $WeztermConfigDir"
}

if (Test-Path $WeztermConfigFile) {
    $backup = "$WeztermConfigFile.bak-$(Get-Date -Format 'yyyyMMdd-HHmm')"
    Move-Item $WeztermConfigFile $backup
    Write-Host "  Backed up existing config to $backup"
}

# Create a symlink so edits to the repo file are reflected immediately
New-Item -ItemType SymbolicLink -Path $WeztermConfigFile -Target $SourceConfig | Out-Null
Write-Host "  Linked: $WeztermConfigFile -> $SourceConfig" -ForegroundColor Green

# -----------------------------------------------------------------------------
# 2. Check WezTerm is installed
# -----------------------------------------------------------------------------
Write-Host "[2/4] Checking WezTerm..." -ForegroundColor Yellow
$wezterm = Get-Command wezterm -ErrorAction SilentlyContinue
if ($wezterm) {
    Write-Host "  WezTerm found: $($wezterm.Source)" -ForegroundColor Green
} else {
    Write-Host "  WezTerm NOT found. Install from: https://wezfurlong.org/wezterm/" -ForegroundColor Red
    Write-Host "  Or via winget: winget install wez.wezterm"
}

# -----------------------------------------------------------------------------
# 3. Check Windows-side AI CLI tools
# -----------------------------------------------------------------------------
Write-Host "[3/4] Checking CLI tools..." -ForegroundColor Yellow

$tools = @(
    @{ Name = "Claude Code"; Cmd = "claude";  Install = "npm install -g @anthropic-ai/claude-code" },
    @{ Name = "Codex CLI";   Cmd = "codex";   Install = "npm install -g @openai/codex" },
    @{ Name = "Gemini CLI";  Cmd = "gemini";  Install = "npm install -g @google/gemini-cli" },
    @{ Name = "Node.js";     Cmd = "node";    Install = "winget install OpenJS.NodeJS.LTS" },
    @{ Name = "Git";         Cmd = "git";     Install = "winget install Git.Git" }
)

foreach ($tool in $tools) {
    $found = Get-Command $tool.Cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  ✓ $($tool.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($tool.Name) — Install: $($tool.Install)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# 4. WSL bootstrap (optional)
# -----------------------------------------------------------------------------
if (-not $SkipWSL) {
    Write-Host "[4/4] Running WSL bootstrap..." -ForegroundColor Yellow
    $wslScript = "$RepoRoot\scripts\bootstrap-wsl.sh"

    $wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslAvailable) {
        wsl -d $WSLDistro -- bash -l "$($wslScript.Replace('\', '/').Replace('C:', '/mnt/c'))"
    } else {
        Write-Host "  WSL not available. Skipping." -ForegroundColor DarkGray
    }
} else {
    Write-Host "[4/4] WSL bootstrap skipped (-SkipWSL)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Bootstrap complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open WezTerm — config is live"
Write-Host "  2. Press CTRL+SPACE then 'a' to launch the AI workbench layout"
Write-Host "  3. Press CTRL+SPACE then 'w' to see/switch workspaces"
Write-Host "  4. Edit wezterm\wezterm.lua in the repo to customize further"
Write-Host ""
