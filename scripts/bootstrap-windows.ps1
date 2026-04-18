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
    [switch]$SkipWSL,
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories",
    [string]$MemoryRepoUrl  = "https://github.com/pandrux/ai-partner-memories.git"
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
Write-Host "[1/6] WezTerm config..." -ForegroundColor Yellow

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
Write-Host "[2/6] Checking WezTerm..." -ForegroundColor Yellow
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
Write-Host "[3/6] Checking CLI tools..." -ForegroundColor Yellow

$tools = @(
    @{ Name = "Claude Code"; Cmd = "claude";  Install = "npm install -g @anthropic-ai/claude-code" },
    @{ Name = "Codex CLI";   Cmd = "codex";   Install = "npm install -g @openai/codex" },
    @{ Name = "Gemini CLI";  Cmd = "gemini";  Install = "npm install -g @google/gemini-cli" },
    @{ Name = "Node.js";     Cmd = "node";    Install = "winget install OpenJS.NodeJS.LTS" },
    @{ Name = "Git";         Cmd = "git";     Install = "winget install Git.Git" },
    @{ Name = "Python 3.13"; Cmd = "python";  Install = "winget install Python.Python.3.13" },
    @{ Name = "Cursor IDE";  Cmd = "cursor";  Install = "winget install Anysphere.Cursor" },
    @{ Name = "Pandoc";      Cmd = "pandoc";  Install = "winget install JohnMacFarlane.Pandoc" }
)

$autoInstall = @("Cursor IDE", "Pandoc")  # tools we auto-install via winget if missing

foreach ($tool in $tools) {
    $found = Get-Command $tool.Cmd -ErrorAction SilentlyContinue
    # Windows Store App Execution Alias stubs look "found" but aren't real
    if ($found -and $found.Source -match 'WindowsApps\\.*\.exe$') { $found = $null }

    if ($found) {
        Write-Host "  [OK] $($tool.Name)" -ForegroundColor Green
    } elseif ($autoInstall -contains $tool.Name -and $tool.Install -match '^winget install (.+)$') {
        $wingetId = $Matches[1]
        Write-Host "  [AUTO] Installing $($tool.Name) via winget ($wingetId)..." -ForegroundColor Yellow
        winget install --id $wingetId --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] $($tool.Name) installed" -ForegroundColor Green
        } else {
            Write-Host "  [FAIL] $($tool.Name) install returned $LASTEXITCODE" -ForegroundColor Red
        }
    } else {
        Write-Host "  [MISSING] $($tool.Name) -- Install: $($tool.Install)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# 4. Claude Code statusline + settings
# -----------------------------------------------------------------------------
Write-Host "[4/6] Claude Code statusline..." -ForegroundColor Yellow

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
# 5. Private memory repo (ai-partner-memories)
# -----------------------------------------------------------------------------
Write-Host "[5/6] Private memory repo..." -ForegroundColor Yellow

$skipMemoryLink = $false

if (-not (Test-Path $MemoryRepoPath)) {
    $MemoryParent = Split-Path -Parent $MemoryRepoPath
    if (-not (Test-Path $MemoryParent)) {
        New-Item -ItemType Directory -Path $MemoryParent | Out-Null
    }
    Write-Host "  Cloning $MemoryRepoUrl..."
    git clone $MemoryRepoUrl $MemoryRepoPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Clone failed (is GitHub auth configured?). Skipping CLAUDE.md link." -ForegroundColor Red
        $skipMemoryLink = $true
    } else {
        Write-Host "  Cloned to $MemoryRepoPath" -ForegroundColor Green
    }
} else {
    Write-Host "  Memory repo already present at $MemoryRepoPath" -ForegroundColor Green
}

if (-not $skipMemoryLink) {
    $ClaudeMdTarget = "$ClaudeDir\CLAUDE.md"
    $ClaudeMdSource = "$MemoryRepoPath\CLAUDE.md"

    if (Test-Path $ClaudeMdSource) {
        if (Test-Path $ClaudeMdTarget) {
            $existingTarget = (Get-Item $ClaudeMdTarget).Target
            if ($existingTarget -and ($existingTarget -eq $ClaudeMdSource)) {
                Write-Host "  CLAUDE.md already linked" -ForegroundColor Green
            } else {
                $backup = "$ClaudeMdTarget.bak-$(Get-Date -Format 'yyyyMMdd-HHmm')"
                Move-Item $ClaudeMdTarget $backup
                Write-Host "  Backed up existing CLAUDE.md to $backup"
                New-Item -ItemType SymbolicLink -Path $ClaudeMdTarget -Target $ClaudeMdSource | Out-Null
                Write-Host "  Linked: $ClaudeMdTarget -> $ClaudeMdSource" -ForegroundColor Green
            }
        } else {
            New-Item -ItemType SymbolicLink -Path $ClaudeMdTarget -Target $ClaudeMdSource | Out-Null
            Write-Host "  Linked: $ClaudeMdTarget -> $ClaudeMdSource" -ForegroundColor Green
        }
    } else {
        Write-Host "  WARN: $ClaudeMdSource does not exist (repo may be empty)" -ForegroundColor Yellow
    }
}

# -----------------------------------------------------------------------------
# 6. WSL bootstrap (optional)
# -----------------------------------------------------------------------------
if (-not $SkipWSL) {
    Write-Host "[6/6] Running WSL bootstrap..." -ForegroundColor Yellow
    $wslScript = "$RepoRoot\scripts\bootstrap-wsl.sh"

    $wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslAvailable) {
        # Convert any Windows drive letter (C:, D:, E:, ...) to /mnt/<lower>
        if ($wslScript -match '^([A-Za-z]):(.*)$') {
            $wslPath = "/mnt/$($Matches[1].ToLower())$($Matches[2] -replace '\\', '/')"
        } else {
            $wslPath = $wslScript -replace '\\', '/'
        }
        wsl -d $WSLDistro -- bash -l "$wslPath"
    } else {
        Write-Host "  WSL not available. Skipping." -ForegroundColor DarkGray
    }
} else {
    Write-Host "[6/6] WSL bootstrap skipped (-SkipWSL)" -ForegroundColor DarkGray
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

