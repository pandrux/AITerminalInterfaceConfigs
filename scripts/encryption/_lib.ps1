# _lib.ps1 - shared helpers for the memory encryption hooks.
# Dot-source from setup-machine.ps1, decrypt-memory.ps1, encrypt-memory.ps1,
# audit-classification.ps1.
#
# Design (see README.md for full notes):
#   - Single user-chosen passphrase, stored in Keeper for recovery.
#   - On each machine, the passphrase is DPAPI-encrypted (CurrentUser scope)
#     and written to ~/.claude/encryption/passphrase.dpapi.
#   - Hooks read the passphrase via DPAPI, pipe it to gpg via stdin
#     (--passphrase-fd 0). Plaintext passphrase never touches disk after setup.
#   - Encryption envelope: tar a directory, gpg --symmetric the tarball,
#     write {name}.tar.gpg next to the source.
#   - Concurrency: ~/.claude/encryption/active-sessions.json holds active PIDs.
#     Encrypt-on-stop only fires when the last session ends.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ProtectedData lives in System.Security in .NET Framework. PS 5.1 doesn't
# load this assembly by default; load it explicitly so DPAPI works on a
# fresh shell.
Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue

$Script:EncryptionDir   = Join-Path $env:USERPROFILE '.claude\encryption'
$Script:PassphraseFile  = Join-Path $Script:EncryptionDir 'passphrase.dpapi'
$Script:SessionsFile    = Join-Path $Script:EncryptionDir 'active-sessions.json'

# Ensure the encryption config dir exists (idempotent).
function Ensure-EncryptionDir {
    if (-not (Test-Path $Script:EncryptionDir)) {
        New-Item -ItemType Directory -Path $Script:EncryptionDir -Force | Out-Null
    }
}

# DPAPI-protect a string and write to disk.
function Protect-PassphraseToDisk {
    param([string]$Plaintext)
    Ensure-EncryptionDir
    $bytes     = [System.Text.Encoding]::UTF8.GetBytes($Plaintext)
    $encrypted = [System.Security.Cryptography.ProtectedData]::Protect(
        $bytes, $null, 'CurrentUser')
    [System.IO.File]::WriteAllBytes($Script:PassphraseFile, $encrypted)
    # Best-effort scrub of the plaintext byte array.
    [Array]::Clear($bytes, 0, $bytes.Length)
}

# Read DPAPI-protected passphrase. Throws if not configured.
function Get-EncryptionPassphrase {
    if (-not (Test-Path $Script:PassphraseFile)) {
        throw "Passphrase not configured on this machine. Run setup-machine.ps1 first."
    }
    $bytes     = [System.IO.File]::ReadAllBytes($Script:PassphraseFile)
    $decrypted = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $bytes, $null, 'CurrentUser')
    return [System.Text.Encoding]::UTF8.GetString($decrypted)
}

# Verify gpg and tar are reachable on PATH.
function Test-EncryptionTools {
    $missing = @()
    foreach ($cmd in @('gpg', 'tar')) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $missing += $cmd
        }
    }
    if ($missing.Count -gt 0) {
        throw "Required tools missing from PATH: $($missing -join ', '). Install gpg (winget install GnuPG.GnuPG) and ensure tar.exe is available (Windows 10+ ships it in System32)."
    }
}

# Tar a directory and gpg-symmetric-encrypt it. Plaintext intermediate tar
# lives in user-profile temp briefly; overwritten and removed on completion.
function Encrypt-Directory {
    param(
        [Parameter(Mandatory)] [string] $SourceDir,    # e.g. D:\AI\ai-partner-memories\private
        [Parameter(Mandatory)] [string] $OutputFile,   # e.g. D:\AI\ai-partner-memories\private.tar.gpg
        [Parameter(Mandatory)] [string] $Passphrase
    )
    if (-not (Test-Path $SourceDir)) {
        throw "Encrypt-Directory: source not found: $SourceDir"
    }
    $sourceFull = (Resolve-Path $SourceDir).Path
    $parent     = Split-Path -Parent $sourceFull
    $name       = Split-Path -Leaf   $sourceFull

    $tmpTar = New-TemporaryFile
    try {
        & tar -cf $tmpTar.FullName -C $parent $name
        if ($LASTEXITCODE -ne 0) {
            throw "tar create failed (exit $LASTEXITCODE) for $sourceFull"
        }

        $Passphrase | & gpg --batch --yes --pinentry-mode loopback `
            --passphrase-fd 0 --symmetric --cipher-algo AES256 `
            --output $OutputFile $tmpTar.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "gpg encrypt failed (exit $LASTEXITCODE) for $sourceFull"
        }
    } finally {
        if (Test-Path $tmpTar.FullName) {
            try {
                $size = (Get-Item $tmpTar.FullName).Length
                $junk = [byte[]]::new([math]::Min($size + 64, 1MB))
                [System.IO.File]::WriteAllBytes($tmpTar.FullName, $junk)
            } catch { }
            Remove-Item $tmpTar.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

# gpg-decrypt and untar into the parent directory. Throws on bad passphrase.
function Decrypt-Directory {
    param(
        [Parameter(Mandatory)] [string] $InputFile,    # e.g. private.tar.gpg
        [Parameter(Mandatory)] [string] $DestParent,   # parent dir to extract into
        [Parameter(Mandatory)] [string] $Passphrase
    )
    if (-not (Test-Path $InputFile))   { throw "Decrypt-Directory: ciphertext not found: $InputFile" }
    if (-not (Test-Path $DestParent))  { throw "Decrypt-Directory: dest parent missing: $DestParent" }

    $tmpTar = New-TemporaryFile
    try {
        $Passphrase | & gpg --batch --yes --pinentry-mode loopback `
            --passphrase-fd 0 --decrypt `
            --output $tmpTar.FullName $InputFile
        if ($LASTEXITCODE -ne 0) {
            throw "gpg decrypt failed (exit $LASTEXITCODE) for $InputFile -- wrong passphrase?"
        }
        & tar -xf $tmpTar.FullName -C $DestParent
        if ($LASTEXITCODE -ne 0) {
            throw "tar extract failed (exit $LASTEXITCODE) for $InputFile"
        }
    } finally {
        if (Test-Path $tmpTar.FullName) {
            try {
                $size = (Get-Item $tmpTar.FullName).Length
                $junk = [byte[]]::new([math]::Min($size + 64, 1MB))
                [System.IO.File]::WriteAllBytes($tmpTar.FullName, $junk)
            } catch { }
            Remove-Item $tmpTar.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

# Best-effort secure removal of a directory tree's contents. Overwrites file
# bodies with random bytes before delete to discourage casual undelete.
function Remove-PlaintextTree {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return }
    Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $size = $_.Length
            if ($size -gt 0) {
                $junk = [byte[]]::new([math]::Min($size, 1MB))
                [System.IO.File]::WriteAllBytes($_.FullName, $junk)
            }
        } catch { }
    }
    Remove-Item $Dir -Recurse -Force -ErrorAction SilentlyContinue
}

# Active-sessions tracking ----------------------------------------------------
#
# Sessions are tracked by Claude Code's session_id (provided in the SessionStart
# / SessionEnd hook payload). The PowerShell PID running the hook is transient
# and unrelated to the Claude session, so we don't use it as a key.
#
# Stale-entry recovery is plaintext-state-based: see decrypt-memory.ps1 for
# the cases. We don't try to validate liveness from inside a hook.

function Read-ActiveSessions {
    if (-not (Test-Path $Script:SessionsFile)) {
        return @()
    }
    try {
        $raw = Get-Content $Script:SessionsFile -Raw -Encoding UTF8
        $obj = $raw | ConvertFrom-Json
        if ($obj -and $obj.sessions) { return @($obj.sessions) }
    } catch { }
    return @()
}

function Write-ActiveSessions {
    param([array]$Sessions)
    Ensure-EncryptionDir
    $payload = @{ sessions = @($Sessions) } | ConvertTo-Json -Depth 4
    Set-Content -Path $Script:SessionsFile -Value $payload -Encoding UTF8
}

function Add-ActiveSession {
    param([Parameter(Mandatory)] [string] $SessionId)
    $sessions = Read-ActiveSessions
    $entry = @{
        sessionId = $SessionId
        started   = (Get-Date -Format 'o')
    }
    # Replace any prior entry with the same SessionId (idempotent).
    $sessions = @($sessions | Where-Object { $_.sessionId -ne $SessionId })
    $sessions += $entry
    Write-ActiveSessions -Sessions $sessions
}

function Remove-ActiveSession {
    param([Parameter(Mandatory)] [string] $SessionId)
    $sessions  = Read-ActiveSessions
    $remaining = @($sessions | Where-Object { $_.sessionId -ne $SessionId })
    Write-ActiveSessions -Sessions $remaining
    return $remaining.Count
}

function Clear-ActiveSessions {
    Write-ActiveSessions -Sessions @()
}

# Project-specific auto-memory location resolution ---------------------------

# Convert a cwd path like "D:\AI" to the encoded directory name Claude Code
# uses under ~/.claude/projects/, e.g. "D--AI". Empirically: drive colon and
# path separators collapse to "-".
function ConvertTo-ProjectDirName {
    param([string]$Cwd)
    if (-not $Cwd) { return $null }
    $normalized = $Cwd -replace '[:\\/]+', '-'
    return $normalized.TrimEnd('-')
}

function Get-ProjectMemoryDir {
    param([string]$Cwd)
    $name = ConvertTo-ProjectDirName -Cwd $Cwd
    if (-not $name) { return $null }
    return Join-Path $env:USERPROFILE ".claude\projects\$name\memory"
}
