# init-encryption.ps1 - one-time migration: encrypt the existing plaintext
# memory tree into the .tar.gpg blobs.
#
# Run this exactly once, on the first machine where setup-machine.ps1 has
# completed, AFTER you've moved the sensitive content into the locations the
# encryption envelope expects:
#
#   D:\AI\ai-partner-memories\private\          (work_context.md, work/, etc.)
#   ~/.claude/projects/<encoded-cwd>/memory\    (auto-memory entries)
#
# Will refuse to run if a corresponding .tar.gpg already exists -- prevents
# accidentally clobbering an already-encrypted blob.
#
# After this runs and pushes:
#   - Remaining machines just run setup-machine.ps1; the SessionStart hook
#     decrypts the blobs into working dirs at first session.

[CmdletBinding()]
param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories",
    [switch]$IncludeProjectMemory,
    [string]$ProjectMemoryDir = "$env:USERPROFILE\.claude\projects\D--AI\memory"
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir '_lib.ps1')

Test-EncryptionTools
$passphrase = Get-EncryptionPassphrase

# ai-partner-memories private/.
$privateWorking = Join-Path $MemoryRepoPath 'private'
$privateCipher  = Join-Path $MemoryRepoPath 'private.tar.gpg'

if (Test-Path $privateCipher) {
    Write-Host "[--] $privateCipher already exists; skipping private/ initial encrypt." -ForegroundColor Yellow
} elseif (-not (Test-Path $privateWorking)) {
    Write-Host "[--] $privateWorking does not exist; nothing to encrypt." -ForegroundColor Yellow
} else {
    $files = Get-ChildItem $privateWorking -Recurse -File -Force -ErrorAction SilentlyContinue
    if ($files.Count -eq 0) {
        Write-Host "[--] $privateWorking is empty; nothing to encrypt." -ForegroundColor Yellow
    } else {
        Write-Host "[..] Encrypting $privateWorking ($($files.Count) files) -> $privateCipher" -ForegroundColor Cyan
        Encrypt-Directory -SourceDir $privateWorking -OutputFile $privateCipher -Passphrase $passphrase
        Remove-PlaintextTree -Dir $privateWorking
        Write-Host "[OK] private.tar.gpg created and plaintext removed" -ForegroundColor Green
    }
}

if ($IncludeProjectMemory) {
    $projectMemCipher = (Split-Path -Parent $ProjectMemoryDir) + '\memory.tar.gpg'
    if (Test-Path $projectMemCipher) {
        Write-Host "[--] $projectMemCipher already exists; skipping project memory initial encrypt." -ForegroundColor Yellow
    } elseif (-not (Test-Path $ProjectMemoryDir)) {
        Write-Host "[--] $ProjectMemoryDir does not exist; nothing to encrypt." -ForegroundColor Yellow
    } else {
        $files = Get-ChildItem $ProjectMemoryDir -Recurse -File -Force -ErrorAction SilentlyContinue
        if ($files.Count -eq 0) {
            Write-Host "[--] $ProjectMemoryDir is empty; nothing to encrypt." -ForegroundColor Yellow
        } else {
            Write-Host "[..] Encrypting $ProjectMemoryDir ($($files.Count) files) -> $projectMemCipher" -ForegroundColor Cyan
            Encrypt-Directory -SourceDir $ProjectMemoryDir -OutputFile $projectMemCipher -Passphrase $passphrase
            Remove-PlaintextTree -Dir $ProjectMemoryDir
            Write-Host "[OK] memory.tar.gpg created and plaintext removed" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Initial encryption complete. Commit and push the .tar.gpg files." -ForegroundColor Cyan
