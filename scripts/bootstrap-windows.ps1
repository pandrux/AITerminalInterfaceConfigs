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
        Write-Host "  [OK] $($tool.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $($tool.Name) -- Install: $($tool.Install)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# 4. Claude Code statusline + settings
# -----------------------------------------------------------------------------
Write-Host "[4/5] Claude Code statusline..." -ForegroundColor Yellow

$ClaudeDir = "$env:USERPROFILE\.claude"
$StatuslineTarget = "$ClaudeDir\statusline.py"
$StatuslineSource = "$RepoRoot\claude\statusline.py"

if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir | Out-Null
}

if (Test-Path $StatuslineTarget) {
    $backup = "$StatuslineTarget.bak-$(Get-Date -Format 'yyyyMMdd-HHmm')"
    Move-Item $StatuslineTarget $backup
    Write-Host "  Backed up existing statusline.py to $backup"
}

New-Item -ItemType SymbolicLink -Path $StatuslineTarget -Target $StatuslineSource | Out-Null
Write-Host "  Linked: $StatuslineTarget -> $StatuslineSource" -ForegroundColor Green

# Patch settings.json to register the statusLine command (PS 5.1-compatible)
$SettingsFile = "$ClaudeDir\settings.json"
$settings = $null
if (Test-Path $SettingsFile) {
    try { $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json } catch { $settings = $null }
}
if (-not $settings) { $settings = New-Object PSObject }

# Find a real Python — skip the Windows Store App Execution Alias stub
# ($env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe prints an install prompt
# and exits 49, which silently breaks statusline.)
$pythonPath = $null
$candidates = @(
    "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
    "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
    "$env:ProgramFiles\Python313\python.exe",
    "$env:ProgramFiles\Python312\python.exe",
    "$env:ProgramFiles\Python311\python.exe"
)
foreach ($c in $candidates) {
    if (Test-Path $c) { $pythonPath = $c; break }
}
if (-not $pythonPath) {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd -and $pythonCmd.Source -notmatch 'WindowsApps\\python\.exe$') {
        $pythonPath = $pythonCmd.Source
    }
}
$skipStatusLineRegistration = $false
if (-not $pythonPath) {
    Write-Host "  WARN: No real Python found. Install with: winget install Python.Python.3.13" -ForegroundColor Yellow
    Write-Host "  WARN: Skipping statusLine registration." -ForegroundColor Yellow
    $skipStatusLineRegistration = $true
}
if (-not $skipStatusLineRegistration) {
    $statuslineCmd = "`"$($pythonPath.Replace('\', '/'))`" `"$($StatuslineTarget.Replace('\', '/'))`""
    $statusLineObj = New-Object PSObject -Property @{ type = "command"; command = $statuslineCmd }
    $settings | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $statusLineObj -Force

    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    Write-Host "  Registered statusLine: $pythonPath" -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# 5. WSL bootstrap (optional)
# -----------------------------------------------------------------------------
if (-not $SkipWSL) {
    Write-Host "[5/5] Running WSL bootstrap..." -ForegroundColor Yellow
    $wslScript = "$RepoRoot\scripts\bootstrap-wsl.sh"

    $wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslAvailable) {
        wsl -d $WSLDistro -- bash -l "$($wslScript.Replace('\', '/').Replace('C:', '/mnt/c'))"
    } else {
        Write-Host "  WSL not available. Skipping." -ForegroundColor DarkGray
    }
} else {
    Write-Host "[5/5] WSL bootstrap skipped (-SkipWSL)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Bootstrap complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open WezTerm -- config is live"
Write-Host "  2. Press CTRL+SPACE then 'a' to launch the AI workbench layout"
Write-Host "  3. Press CTRL+SPACE then 'w' to see/switch workspaces"
Write-Host "  4. Edit wezterm\wezterm.lua in the repo to customize further"
Write-Host ""

