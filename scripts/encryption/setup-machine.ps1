# setup-machine.ps1 - one-time per-machine encryption setup.
#
# Prompts for the AI memory passphrase (kept in Keeper), DPAPI-protects it,
# and writes it to ~/.claude/encryption/passphrase.dpapi. Re-runnable; will
# ask before overwriting an existing passphrase.
#
# Run after gpg is installed (winget install GnuPG.GnuPG) on each machine
# that runs Claude Code with the encryption hooks enabled.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir '_lib.ps1')

Write-Host "AI Memory encryption setup" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Cyan

# Step 1: verify tools are present.
try {
    Test-EncryptionTools
    Write-Host "[OK] gpg and tar are on PATH" -ForegroundColor Green
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Ensure-EncryptionDir

# Step 2: confirm overwrite if a passphrase is already cached.
if (Test-Path $Script:PassphraseFile) {
    $resp = Read-Host "Passphrase already configured on this machine. Overwrite? (y/N)"
    if ($resp -ne 'y' -and $resp -ne 'Y') {
        Write-Host "Aborted. No changes made." -ForegroundColor Yellow
        exit 0
    }
}

# Step 3: prompt for the passphrase twice.
Write-Host ""
Write-Host "Paste or type the AI memory passphrase from Keeper." -ForegroundColor White
Write-Host "Keeper entry name: 'AI Memory Recovery Password for Encrypted AI Memories -- DO NOT DELETE'" -ForegroundColor DarkGray
Write-Host ""

$secure1 = Read-Host -AsSecureString "Passphrase"
$secure2 = Read-Host -AsSecureString "Confirm passphrase"

$bstr1 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure1)
$bstr2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure2)
try {
    $plain1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr1)
    $plain2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr2)

    if ([string]::IsNullOrEmpty($plain1)) {
        Write-Host "[FAIL] Empty passphrase rejected." -ForegroundColor Red
        exit 1
    }
    if ($plain1 -ne $plain2) {
        Write-Host "[FAIL] Passphrases did not match." -ForegroundColor Red
        exit 1
    }

    # Step 4: roundtrip test before writing the DPAPI blob, so a typo'd
    # passphrase doesn't get committed to disk and break later sessions.
    $tmpDir = Join-Path $env:TEMP "ai-memory-setup-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    try {
        $sample = Join-Path $tmpDir 'sample'
        New-Item -ItemType Directory -Path $sample -Force | Out-Null
        Set-Content -Path (Join-Path $sample 'roundtrip.txt') `
            -Value "encryption-roundtrip-test" -Encoding UTF8

        $cipher = Join-Path $tmpDir 'sample.tar.gpg'
        Encrypt-Directory -SourceDir $sample -OutputFile $cipher -Passphrase $plain1
        Remove-Item $sample -Recurse -Force

        Decrypt-Directory -InputFile $cipher -DestParent $tmpDir -Passphrase $plain1
        $roundtrip = Get-Content (Join-Path $sample 'roundtrip.txt') -Raw
        if ($roundtrip.Trim() -ne 'encryption-roundtrip-test') {
            throw "Roundtrip content mismatch."
        }
        Write-Host "[OK] Encryption roundtrip verified" -ForegroundColor Green
    } finally {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Step 5: persist DPAPI-protected passphrase.
    Protect-PassphraseToDisk -Plaintext $plain1
    Write-Host "[OK] Passphrase stored at $Script:PassphraseFile" -ForegroundColor Green
} finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
    $plain1 = $null; $plain2 = $null
    [System.GC]::Collect()
}

Write-Host ""
Write-Host "Setup complete on this machine." -ForegroundColor Cyan
Write-Host "Hooks will activate at the next Claude Code session start." -ForegroundColor DarkGray
