<#
.SYNOPSIS
    Reconciles local AI repositories with origin/main.

.DESCRIPTION
    Discovers git repositories under $BaseDir and, for each one on the main
    branch, performs a safe reconcile with origin:

      1. If the working tree is dirty, auto-commits as
         "auto-sync: <hostname> <ISO-timestamp>" so nothing is lost.
      2. Fetches origin.
      3. If local is ahead of origin/main, pushes.
      4. If local is behind and the working tree is clean, fast-forwards.
      5. If local and origin have diverged, logs a warning and skips.
         Divergence requires human resolution; this script will not guess.

    Designed to be invoked from multiple triggers (nightly scheduled task,
    logon scheduled task, or manually via the `ai-sync` shell alias before
    starting a new Claude Code session) with identical behavior each time.

.PARAMETER BaseDir
    Root directory to scan for git repositories. Defaults to D:\AI.

.PARAMETER WhatIf
    Report what would happen without making changes.

.EXAMPLE
    .\ai-sync.ps1
    Reconcile all repos under D:\AI.

.EXAMPLE
    .\ai-sync.ps1 -WhatIf
    Show what would change without touching anything.

.EXAMPLE
    .\ai-sync.ps1 -BaseDir D:\Projects
    Scan a different root.

.NOTES
    Exit code 0 = all repos aligned; non-zero = one or more need human attention.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$BaseDir = 'D:\AI'
)

$ErrorActionPreference = 'Continue'

function Invoke-GitQuiet {
    param([string[]]$Args)
    & git @Args 2>&1 | Out-Null
    return $LASTEXITCODE
}

# Discover git repos
$gitDirs = Get-ChildItem -Path $BaseDir -Recurse -Force -Filter '.git' -Directory -ErrorAction SilentlyContinue
if (-not $gitDirs) {
    Write-Host "No git repositories found under $BaseDir"
    exit 0
}

$summary = @()
$issues  = 0
$ts      = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'

foreach ($gitDir in $gitDirs) {
    $repoPath = $gitDir.Parent.FullName
    $repoName = $gitDir.Parent.Name

    Write-Host "`n=== $repoName ==="
    Push-Location $repoPath
    try {
        $branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
        if ($branch -ne 'main') {
            Write-Host "  [skip] on branch '$branch', not 'main'"
            $summary += "$repoName: skipped (branch=$branch)"
            continue
        }

        # Auto-commit dirty tree
        $dirty = & git status --porcelain
        if ($dirty) {
            $hostname = $env:COMPUTERNAME
            $msg = "auto-sync: $hostname $ts"
            if ($PSCmdlet.ShouldProcess($repoName, "Auto-commit dirty tree")) {
                Invoke-GitQuiet @('add','-A')           | Out-Null
                Invoke-GitQuiet @('commit','-m',$msg)   | Out-Null
                Write-Host "  [commit] $msg"
            }
        }

        # Fetch
        if ($PSCmdlet.ShouldProcess($repoName, "Fetch origin")) {
            Invoke-GitQuiet @('fetch','origin','--quiet') | Out-Null
        }

        # Confirm remote branch exists
        $remoteHead = & git rev-parse --verify --quiet origin/main 2>$null
        if (-not $remoteHead) {
            Write-Warning "  [skip] no origin/main found"
            $summary += "$repoName: skipped (no origin/main)"
            continue
        }

        $local  = (& git rev-parse HEAD).Trim()
        $remote = $remoteHead.Trim()
        $base   = (& git merge-base HEAD origin/main).Trim()

        if ($local -eq $remote) {
            Write-Host "  [sync] already in sync"
            $summary += "$repoName: in sync"
        } elseif ($local -eq $base) {
            # behind — fast-forward
            if ($PSCmdlet.ShouldProcess($repoName, "Fast-forward from origin/main")) {
                Invoke-GitQuiet @('merge','--ff-only','origin/main') | Out-Null
                Write-Host "  [pull] fast-forwarded"
                $summary += "$repoName: pulled"
            }
        } elseif ($remote -eq $base) {
            # ahead — push
            if ($PSCmdlet.ShouldProcess($repoName, "Push to origin/main")) {
                Invoke-GitQuiet @('push','origin','main') | Out-Null
                Write-Host "  [push] pushed local commits"
                $summary += "$repoName: pushed"
            }
        } else {
            Write-Warning "  [WARN] diverged from origin/main — manual resolution needed"
            $summary += "$repoName: DIVERGED (manual)"
            $issues++
        }
    } finally {
        Pop-Location
    }
}

Write-Host "`n=== Summary ($ts) ==="
$summary | ForEach-Object { Write-Host "  $_" }

if ($issues -gt 0) {
    Write-Host "`n$issues repo(s) need manual attention"
    exit 1
}
exit 0
