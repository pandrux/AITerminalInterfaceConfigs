# encrypt-memory.ps1 - SessionEnd hook.
#
# Removes this session_id from the active-sessions list. If no other sessions
# remain, encrypts the plaintext working directories back to .tar.gpg and
# removes the plaintext copies. If other sessions are still active, leaves
# plaintext in place for them.
#
# Encrypts:
#   - D:\AI\ai-partner-memories\private/ -> private.tar.gpg
#   - ~/.claude/projects/<encoded-cwd>/memory/ -> memory.tar.gpg
#     (only when the current project has its own auto-memory)
#
# Note: SessionEnd has no decision control -- the session has already
# terminated by the time this fires. We just clean up.

[CmdletBinding()]
param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories"
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir '_lib.ps1')

# Read hook payload (need session_id and cwd).
$cwd       = $null
$sessionId = $null
try {
    $stdinText = [Console]::In.ReadToEnd()
    if ($stdinText -and $stdinText.Trim()) {
        $parsed = $stdinText | ConvertFrom-Json -ErrorAction Stop
        if ($parsed.cwd)        { $cwd       = [string]$parsed.cwd }
        if ($parsed.session_id) { $sessionId = [string]$parsed.session_id }
    }
} catch { }

# Without a session_id we can't deregister cleanly. Exit -- a future
# SessionStart's orphan recovery will clean up if needed.
if (-not $sessionId) { exit 0 }

$remainingCount = Remove-ActiveSession -SessionId $sessionId

if ($remainingCount -gt 0) {
    # Other sessions still active. Leave plaintext in place; the last session
    # to exit will trigger the encrypt.
    exit 0
}

# Last session out. Get the passphrase.
try {
    $passphrase = Get-EncryptionPassphrase
} catch {
    # Passphrase not configured -- nothing we can do. Leave plaintext as-is.
    exit 0
}

$privateWorking = Join-Path $MemoryRepoPath 'private'
$privateCipher  = Join-Path $MemoryRepoPath 'private.tar.gpg'

if ((Test-Path $privateWorking) -and `
    (Get-ChildItem $privateWorking -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    try {
        Encrypt-Directory -SourceDir $privateWorking `
            -OutputFile $privateCipher `
            -Passphrase $passphrase
        Remove-PlaintextTree -Dir $privateWorking
    } catch {
        Write-Host "[encryption] encrypt private/ failed: $($_.Exception.Message)" `
            -ErrorAction SilentlyContinue
    }
}

$projectMemDir = Get-ProjectMemoryDir -Cwd $cwd
if ($projectMemDir -and (Test-Path $projectMemDir) -and `
    (Get-ChildItem $projectMemDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    $projectMemCipher = (Split-Path -Parent $projectMemDir) + '\memory.tar.gpg'
    try {
        Encrypt-Directory -SourceDir $projectMemDir `
            -OutputFile $projectMemCipher `
            -Passphrase $passphrase
        Remove-PlaintextTree -Dir $projectMemDir
    } catch {
        Write-Host "[encryption] encrypt project memory failed: $($_.Exception.Message)" `
            -ErrorAction SilentlyContinue
    }
}

exit 0
