# update-windows.ps1 - Pull latest config and update Windows-side AI CLI tools
# Usage: .\scripts\update-windows.ps1
#
# Windows counterpart to update.sh (which targets WSL). Updates the three
# npm-installed AI CLIs on the Windows side: claude, codex, gemini.

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent

Write-Host ""
Write-Host "=== AI Terminal Config Update (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# -----------------------------------------------------------------------------
# 1. Pull latest config
# -----------------------------------------------------------------------------
Write-Host "[1/2] Pulling latest config..." -ForegroundColor Yellow
Push-Location $RepoRoot
try {
    git pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARN: git pull returned $LASTEXITCODE -- continuing with update" -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}
Write-Host ""

# -----------------------------------------------------------------------------
# 2. Update npm-installed AI CLIs
# -----------------------------------------------------------------------------
Write-Host "[2/2] Updating AI CLI tools..." -ForegroundColor Yellow

# Guard: npm itself must resolve to a real binary, not the Windows Store stub
$npm = Get-Command npm -ErrorAction SilentlyContinue
if ($npm -and $npm.Source -match 'WindowsApps\\.*\.exe$') { $npm = $null }
if (-not $npm) {
    Write-Host "  [FAIL] npm not found. Install Node.js: winget install OpenJS.NodeJS.LTS" -ForegroundColor Red
    exit 1
}

$tools = @(
    @{ Name = "Claude Code"; Cmd = "claude"; Package = "@anthropic-ai/claude-code" },
    @{ Name = "Codex CLI";   Cmd = "codex";  Package = "@openai/codex" },
    @{ Name = "Gemini CLI";  Cmd = "gemini"; Package = "@google/gemini-cli" }
)

foreach ($tool in $tools) {
    $found = Get-Command $tool.Cmd -ErrorAction SilentlyContinue
    if ($found -and $found.Source -match 'WindowsApps\\.*\.exe$') { $found = $null }

    if (-not $found) {
        Write-Host "  [SKIP] $($tool.Name) not installed -- install: npm install -g $($tool.Package)" -ForegroundColor DarkGray
        continue
    }

    Write-Host "  Updating $($tool.Name) ($($tool.Package))..."
    npm update -g $tool.Package
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $($tool.Name) updated" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($tool.Name) update returned $LASTEXITCODE" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Update complete ===" -ForegroundColor Cyan
Write-Host "  (Restart any running Claude/Codex/Gemini sessions to pick up new versions)"
Write-Host ""
