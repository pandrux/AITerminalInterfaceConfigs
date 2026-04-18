# collect-local-memory.ps1
# One-shot: copy this machine's ~/.claude/projects/*/memory/ into the private
# ai-partner-memories repo under memory-staging/<hostname>/, then commit and
# push. Run once per machine; the laptop session will then review and migrate
# the staged content into Layer 1 / Layer 2 / Layer 3 of the permanent structure.
#
# Self-contained: clones the memory repo if not already present.
#
# Usage:
#   .\collect-local-memory.ps1
#   .\collect-local-memory.ps1 -MachineLabel "work-desktop"

param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories",
    [string]$MemoryRepoUrl  = "https://github.com/pandrux/ai-partner-memories.git",
    [string]$MachineLabel   = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Collect local memory ===" -ForegroundColor Cyan
Write-Host "Machine label: $MachineLabel"
Write-Host "Memory repo:   $MemoryRepoPath"
Write-Host ""

# -----------------------------------------------------------------------------
# Ensure memory repo is present
# -----------------------------------------------------------------------------
if (-not (Test-Path $MemoryRepoPath)) {
    Write-Host "Memory repo not present; cloning..." -ForegroundColor Yellow
    $parent = Split-Path -Parent $MemoryRepoPath
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    git clone $MemoryRepoUrl $MemoryRepoPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Clone failed. Ensure GitHub auth is configured." -ForegroundColor Red
        exit 1
    }
}

# Pull latest so we stage onto a current tree
git -C $MemoryRepoPath pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Write-Host "Initial pull failed; proceeding with local state." -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# Enumerate local memory directories
# -----------------------------------------------------------------------------
$ClaudeProjectsDir = "$env:USERPROFILE\.claude\projects"

if (-not (Test-Path $ClaudeProjectsDir)) {
    Write-Host "No ~\.claude\projects directory on this machine -- nothing to collect."
    exit 0
}

$memoryDirs = Get-ChildItem -Path $ClaudeProjectsDir -Directory | ForEach-Object {
    $mem = Join-Path $_.FullName "memory"
    if (Test-Path $mem) {
        [pscustomobject]@{ ProjectName = $_.Name; Path = $mem }
    }
}

if (-not $memoryDirs) {
    Write-Host "No memory/ subdirectories found -- nothing to collect."
    exit 0
}

Write-Host "Found $($memoryDirs.Count) project memory dir(s):" -ForegroundColor Yellow
foreach ($m in $memoryDirs) {
    Write-Host "  - $($m.ProjectName)"
}
Write-Host ""

# -----------------------------------------------------------------------------
# Stage into memory-staging/<machine>/
# -----------------------------------------------------------------------------
$StagingBase = Join-Path $MemoryRepoPath "memory-staging\$MachineLabel"

if (Test-Path $StagingBase) {
    Write-Host "Removing previous snapshot for $MachineLabel"
    Remove-Item -Recurse -Force $StagingBase
}
New-Item -ItemType Directory -Path $StagingBase -Force | Out-Null

foreach ($m in $memoryDirs) {
    $dest = Join-Path $StagingBase "$($m.ProjectName)\memory"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path "$($m.Path)\*" -Destination $dest -Recurse -Force
    Write-Host "  Staged $($m.ProjectName)" -ForegroundColor Green
}

# Drop a small README so the staging area is self-explanatory
$readmePath = Join-Path $StagingBase "_collected.md"
@"
# Memory snapshot: $MachineLabel

Collected: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Source: $ClaudeProjectsDir
Projects: $($memoryDirs.Count)

This directory is a staging area for one-time migration of this machine's
pre-existing Claude Code memory into the three-layer structure
(CLAUDE.md / techniques.md / per-project memory). It is expected to be
deleted after migration is complete.
"@ | Set-Content -Path $readmePath -Encoding UTF8

# -----------------------------------------------------------------------------
# Commit + push
# -----------------------------------------------------------------------------
Write-Host ""
Write-Host "Committing and pushing..." -ForegroundColor Yellow

git -C $MemoryRepoPath add memory-staging
git -C $MemoryRepoPath commit -m "Stage memory snapshot from $MachineLabel for migration"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  commit returned $LASTEXITCODE (possibly no changes since last run)"
}
git -C $MemoryRepoPath pull --rebase
if ($LASTEXITCODE -ne 0) {
    Write-Host "  pull --rebase failed; attempting to abort rebase and continue." -ForegroundColor Red
    git -C $MemoryRepoPath rebase --abort 2>$null
    exit 1
}
git -C $MemoryRepoPath push
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Push failed -- check output above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host "Snapshot pushed as memory-staging\$MachineLabel\ in ai-partner-memories."
Write-Host "Next: on your laptop, continue your Claude session and say 'I ran it on $MachineLabel'."
Write-Host ""
