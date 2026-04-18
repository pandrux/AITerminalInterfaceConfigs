# sync-memories.ps1
# Change-gated sync for the ai-partner-memories repo.
# Intended to run on a 5-minute Task Scheduler trigger; safe for manual runs too.
#
# Flow:
#   1. If local repo has no changes -> exit 0 (no network hit).
#   2. Otherwise: git add -A, commit, pull --rebase, push.
#   3. On rebase conflict -> abort rebase, log, exit 1.
#
# Logs to $env:USERPROFILE\.claude\memory-sync.log

param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories",
    [string]$LogFile        = "$env:USERPROFILE\.claude\memory-sync.log"
)

$ErrorActionPreference = "Continue"

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$ts [$Level] $Message"
    $logDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

if (-not (Test-Path $MemoryRepoPath)) {
    Write-Log "ERROR" "Memory repo not found at $MemoryRepoPath"
    exit 1
}

# Change gate — cheap, no network
$status = git -C $MemoryRepoPath status --porcelain 2>&1
if ([string]::IsNullOrWhiteSpace($status)) {
    exit 0
}

Write-Log "INFO" "Changes detected, syncing..."

# Stage everything in the repo
git -C $MemoryRepoPath add -A 2>&1 | Out-Null

# Bail if nothing actually got staged (edge case: all changes were ignored by .gitignore)
git -C $MemoryRepoPath diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Log "INFO" "Nothing staged after add; exiting."
    exit 0
}

$hostname = $env:COMPUTERNAME
$ts       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$commitMsg = "auto-sync from $hostname at $ts"

$commitOut = git -C $MemoryRepoPath commit -m $commitMsg 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "WARN" "git commit exit $LASTEXITCODE -- $commitOut"
    exit 1
}

$pullOut = git -C $MemoryRepoPath pull --rebase 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR" "git pull --rebase failed. Aborting rebase. -- $pullOut"
    git -C $MemoryRepoPath rebase --abort 2>&1 | Out-Null
    exit 1
}

$pushOut = git -C $MemoryRepoPath push 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR" "git push failed (exit $LASTEXITCODE); committed locally but not pushed. -- $pushOut"
    exit 1
}

Write-Log "INFO" "Sync complete."
exit 0
