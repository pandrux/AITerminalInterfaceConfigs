# decrypt-memory.ps1 - SessionStart hook.
#
# Materializes the plaintext working directories at session start, registers
# this session_id in the active-sessions list, and recovers from any orphan
# state left by a crashed prior session.
#
# Decrypts:
#   - D:\AI\ai-partner-memories\private.tar.gpg -> private/ subtree
#   - ~/.claude/projects/<encoded-cwd>/memory.tar.gpg -> memory/ subtree
#     (only when the current project has its own auto-memory)
#
# State machine (per location):
#   plaintext present + list non-empty -> another session is alive; just join.
#   plaintext present + list empty     -> orphan from a crash. Re-encrypt the
#                                         orphan to fold its edits in, then
#                                         decrypt fresh. Add this session.
#   plaintext missing + list non-empty -> stale list (rare). Clear list,
#                                         decrypt, add this session.
#   plaintext missing + list empty     -> clean state. Decrypt, add session.
#
# Hook payload (stdin JSON) provides session_id and cwd. Exit silent on any
# irrecoverable error so the session can still start.

[CmdletBinding()]
param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories"
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir '_lib.ps1')

# Read hook payload.
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

if (-not $sessionId) { $sessionId = "unknown-$([guid]::NewGuid().ToString('N').Substring(0,8))" }

try {
    $passphrase = Get-EncryptionPassphrase
} catch {
    # Setup not run on this machine yet. Exit silent so the session can
    # continue (memory will just be plaintext or whatever it was).
    Write-Host "[encryption] $($_.Exception.Message)" -ErrorAction SilentlyContinue
    exit 0
}

function Has-PlaintextContent {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return $false }
    return [bool] (Get-ChildItem $Dir -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
}

# Process one (cipher, plaintext-dir, dest-parent) tuple. Returns $true if
# it had to recover from an orphan, $false otherwise.
function Sync-Location {
    param(
        [string]$CipherFile,
        [string]$PlaintextDir,
        [string]$DestParent,
        [string]$Passphrase,
        [bool]  $ListWasEmpty
    )
    $hasPlain = Has-PlaintextContent -Dir $PlaintextDir
    $hasCipher = Test-Path $CipherFile

    # Nothing to do if neither cipher nor plaintext exists for this location.
    if (-not $hasCipher -and -not $hasPlain) { return $false }

    if ($hasPlain -and -not $ListWasEmpty) {
        # Other live session has plaintext open. Trust it; do nothing.
        return $false
    }

    $orphanRecovered = $false
    if ($hasPlain -and $ListWasEmpty) {
        # Orphan from a crashed session. Re-encrypt to capture any in-flight
        # edits, then decrypt fresh below.
        try {
            Encrypt-Directory -SourceDir $PlaintextDir `
                -OutputFile $CipherFile `
                -Passphrase $Passphrase
            Remove-PlaintextTree -Dir $PlaintextDir
            $orphanRecovered = $true
            $hasPlain = $false
            $hasCipher = $true
        } catch {
            Write-Host "[encryption] orphan re-encrypt of $PlaintextDir failed: $($_.Exception.Message)" `
                -ErrorAction SilentlyContinue
        }
    }

    if (-not $hasPlain -and $hasCipher) {
        try {
            if (-not (Test-Path $DestParent)) {
                New-Item -ItemType Directory -Path $DestParent -Force | Out-Null
            }
            Decrypt-Directory -InputFile $CipherFile `
                -DestParent $DestParent `
                -Passphrase $Passphrase
        } catch {
            Write-Host "[encryption] decrypt of $CipherFile failed: $($_.Exception.Message)" `
                -ErrorAction SilentlyContinue
        }
    }

    return $orphanRecovered
}

# Determine "list was empty" once before any mutations.
$listWasEmpty = ((Read-ActiveSessions).Count -eq 0)

# If the list claims sessions exist but no plaintext does anywhere, the list
# is stale -- treat as empty.
$privateWorking = Join-Path $MemoryRepoPath 'private'
$projectMemDir  = Get-ProjectMemoryDir -Cwd $cwd
$anyPlain = (Has-PlaintextContent -Dir $privateWorking) -or `
    ($projectMemDir -and (Has-PlaintextContent -Dir $projectMemDir))
if (-not $listWasEmpty -and -not $anyPlain) {
    Clear-ActiveSessions
    $listWasEmpty = $true
}

$orphanFound = $false

# ai-partner-memories private/.
$orphan1 = Sync-Location `
    -CipherFile   (Join-Path $MemoryRepoPath 'private.tar.gpg') `
    -PlaintextDir $privateWorking `
    -DestParent   $MemoryRepoPath `
    -Passphrase   $passphrase `
    -ListWasEmpty $listWasEmpty
if ($orphan1) { $orphanFound = $true }

# Project-specific auto-memory.
if ($projectMemDir) {
    $projectParent    = Split-Path -Parent $projectMemDir
    $projectMemCipher = Join-Path $projectParent 'memory.tar.gpg'
    $orphan2 = Sync-Location `
        -CipherFile   $projectMemCipher `
        -PlaintextDir $projectMemDir `
        -DestParent   $projectParent `
        -Passphrase   $passphrase `
        -ListWasEmpty $listWasEmpty
    if ($orphan2) { $orphanFound = $true }
}

# Register this session.
Add-ActiveSession -SessionId $sessionId

if ($orphanFound) {
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = "Encryption: previous session left plaintext on disk; re-encrypted before this start."
        }
    } | ConvertTo-Json -Depth 5 -Compress
    Write-Output $payload
}

exit 0
