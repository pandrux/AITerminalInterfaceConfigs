# audit-classification.ps1 - diagnostic / inventory tool.
#
# Reports the current state of memory encryption across the system:
#   - Whether the passphrase is configured on this machine
#   - Whether gpg / tar are installed
#   - Active session count and PIDs
#   - Ciphertext / plaintext state of each known location
#   - Any anomalies (orphan plaintext, missing ciphertext, dead PIDs)
#
# Run anytime; read-only. Useful before / after major changes and when
# something looks off.

[CmdletBinding()]
param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir '_lib.ps1')

function Format-Bytes {
    param([long]$Size)
    if ($Size -lt 1KB) { return "$Size B" }
    if ($Size -lt 1MB) { return ('{0:N1} KB' -f ($Size / 1KB)) }
    if ($Size -lt 1GB) { return ('{0:N1} MB' -f ($Size / 1MB)) }
    return ('{0:N2} GB' -f ($Size / 1GB))
}

function Show-Location {
    param(
        [string]$Label,
        [string]$Cipher,
        [string]$Plain
    )
    Write-Host ""
    Write-Host "$Label" -ForegroundColor Cyan
    if (Test-Path $Cipher) {
        $i = Get-Item $Cipher
        Write-Host ("  ciphertext: {0}  ({1}, modified {2})" -f $Cipher, (Format-Bytes $i.Length), $i.LastWriteTime)
    } else {
        Write-Host "  ciphertext: (none)" -ForegroundColor DarkGray
    }
    if (Test-Path $Plain) {
        $files = Get-ChildItem $Plain -Recurse -File -Force -ErrorAction SilentlyContinue
        if ($files.Count -eq 0) {
            Write-Host ("  plaintext:  {0}  (empty directory)" -f $Plain) -ForegroundColor DarkGray
        } else {
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            Write-Host ("  plaintext:  {0}  ({1} files, {2})" -f $Plain, $files.Count, (Format-Bytes $totalSize))
        }
    } else {
        Write-Host ("  plaintext:  {0}  (does not exist)" -f $Plain) -ForegroundColor DarkGray
    }
}

Write-Host "AI Memory encryption audit" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Cyan

# Passphrase configured?
if (Test-Path $Script:PassphraseFile) {
    $i = Get-Item $Script:PassphraseFile
    Write-Host ("[OK] Passphrase configured: {0} (modified {1})" -f $Script:PassphraseFile, $i.LastWriteTime) -ForegroundColor Green
} else {
    Write-Host "[--] Passphrase NOT configured on this machine. Run setup-machine.ps1." -ForegroundColor Yellow
}

# Tools available?
try {
    Test-EncryptionTools
    Write-Host "[OK] gpg + tar on PATH" -ForegroundColor Green
} catch {
    Write-Host "[--] $($_.Exception.Message)" -ForegroundColor Yellow
}

# Active sessions.
$active = Read-ActiveSessions
Write-Host ""
Write-Host "Active sessions ($($active.Count)):" -ForegroundColor Cyan
if ($active.Count -eq 0) {
    Write-Host "  (none)" -ForegroundColor DarkGray
} else {
    foreach ($s in $active) {
        Write-Host ("  session {0,-40} started {1}" -f $s.sessionId, $s.started)
    }
}

# Repo private/ <-> private.tar.gpg
Show-Location -Label "ai-partner-memories: candid work content" `
    -Cipher (Join-Path $MemoryRepoPath 'private.tar.gpg') `
    -Plain  (Join-Path $MemoryRepoPath 'private')

# Project auto-memories: enumerate everything under ~/.claude/projects/.
Write-Host ""
Write-Host "Per-project auto-memories:" -ForegroundColor Cyan
$projectsRoot = Join-Path $env:USERPROFILE '.claude\projects'
if (-not (Test-Path $projectsRoot)) {
    Write-Host "  (~/.claude/projects/ does not exist)" -ForegroundColor DarkGray
} else {
    $hadAny = $false
    foreach ($projDir in Get-ChildItem $projectsRoot -Directory -ErrorAction SilentlyContinue) {
        $cipher = Join-Path $projDir.FullName 'memory.tar.gpg'
        $plain  = Join-Path $projDir.FullName 'memory'
        $hasCipher = Test-Path $cipher
        $hasPlain  = (Test-Path $plain) -and `
            (Get-ChildItem $plain -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hasCipher -or $hasPlain) {
            $hadAny = $true
            Show-Location -Label "  project: $($projDir.Name)" `
                -Cipher $cipher -Plain $plain
        }
    }
    if (-not $hadAny) {
        Write-Host "  (no projects with memory infrastructure)" -ForegroundColor DarkGray
    }
}

# Anomaly check.
Write-Host ""
Write-Host "Anomaly check:" -ForegroundColor Cyan
$anomalies = @()

# Plaintext present but no active sessions = orphan from a crashed session.
if ($active.Count -eq 0) {
    $privateWorking = Join-Path $MemoryRepoPath 'private'
    if ((Test-Path $privateWorking) -and `
        (Get-ChildItem $privateWorking -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        $anomalies += "ORPHAN: $privateWorking has plaintext but no session is active. Will be re-encrypted at next SessionStart."
    }
    if (Test-Path $projectsRoot) {
        foreach ($projDir in Get-ChildItem $projectsRoot -Directory -ErrorAction SilentlyContinue) {
            $plain = Join-Path $projDir.FullName 'memory'
            if ((Test-Path $plain) -and `
                (Get-ChildItem $plain -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
                $cipher = Join-Path $projDir.FullName 'memory.tar.gpg'
                if (Test-Path $cipher) {
                    $anomalies += "ORPHAN: $plain has plaintext but no session is active."
                }
            }
        }
    }
}

if ($anomalies.Count -eq 0) {
    Write-Host "  (no anomalies)" -ForegroundColor Green
} else {
    foreach ($a in $anomalies) {
        Write-Host "  $a" -ForegroundColor Yellow
    }
}

Write-Host ""
