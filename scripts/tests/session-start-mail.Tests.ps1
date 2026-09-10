# session-start-mail.Tests.ps1 - behavioral tests for the SessionStart mail hook.
#
# Runs the real hook under Windows PowerShell 5.1 exactly as Claude Code
# invokes it (powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...),
# feeding a session payload on stdin and asserting on the emitted JSON.
# No Pester dependency. Exit code 1 on any failure.
#
# Run:  pwsh -NoProfile -File scripts\tests\session-start-mail.Tests.ps1

$ErrorActionPreference = 'Stop'
$Hook = Join-Path (Split-Path -Parent $PSScriptRoot) 'session-start-mail.ps1'
$script:Failures = 0

function Invoke-Hook([string]$Cwd) {
    $payload = @{ cwd = $Cwd; hook_event_name = 'SessionStart' } | ConvertTo-Json -Compress
    # Merge stderr: a hook that spews errors at session start is not silent.
    $out = $payload | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Hook 2>&1
    return (@($out) -join "`n")
}

function New-TempDir([string]$Name) {
    $suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $p = Join-Path ([System.IO.Path]::GetTempPath()) "ssm-test-$Name-$suffix"
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

function Assert-Contains([string]$Actual, [string]$Expected, [string]$TestName) {
    if ($Actual.Contains($Expected)) {
        Write-Host "  PASS  $TestName" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  $TestName" -ForegroundColor Red
        Write-Host "        expected output to contain: $Expected"
        Write-Host "        got: '$Actual'"
        $script:Failures++
    }
}

function Assert-Silent([string]$Actual, [string]$TestName) {
    if ([string]::IsNullOrWhiteSpace($Actual)) {
        Write-Host "  PASS  $TestName" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  $TestName" -ForegroundColor Red
        Write-Host "        expected no output, got: '$Actual'"
        $script:Failures++
    }
}

Write-Host "session-start-mail.ps1 tests" -ForegroundColor Cyan

# --- Test 1: .ai-mail pointer resolves an inbox outside the cwd ancestry ------
# Models the IGLOO layout: project on D:, mailbox on a P: share.
$root    = New-TempDir 'pointer'
$share   = Join-Path $root 'share\mail'
$project = Join-Path $root 'project'
New-Item -ItemType Directory -Path (Join-Path $share 'tom\archive') -Force | Out-Null
New-Item -ItemType Directory -Path $project -Force | Out-Null
Set-Content -Path (Join-Path $share 'tom\20260910-hello.md') -Value "---`nfrom: ryan`nsubject: hi`n---`nhello"
Set-Content -Path (Join-Path $project '.ai-mail') -Value "root=$share`ninbox=tom"
$out = Invoke-Hook $project
Assert-Contains $out '20260910-hello.md' 'pointer file resolves inbox outside cwd ancestry'
Remove-Item $root -Recurse -Force

# --- Test 2: nested cwd still finds the pointer in an ancestor ---------------
# Real case: Claude launched from <project>\Scripts, pointer at <project>\.ai-mail.
$root    = New-TempDir 'nested'
$share   = Join-Path $root 'share\mail'
$project = Join-Path $root 'project'
$nested  = Join-Path $project 'Scripts\deep'
New-Item -ItemType Directory -Path (Join-Path $share 'tom\archive') -Force | Out-Null
New-Item -ItemType Directory -Path $nested -Force | Out-Null
Set-Content -Path (Join-Path $share 'tom\20260910-nested.md') -Value "---`nfrom: ryan`nsubject: nested`n---`nx"
Set-Content -Path (Join-Path $project '.ai-mail') -Value "root=$share`ninbox=tom"
$out = Invoke-Hook $nested
Assert-Contains $out '20260910-nested.md' 'nested cwd finds pointer in ancestor'
Remove-Item $root -Recurse -Force

# --- Test 3: pointer root unreachable (share offline) -> silent, no errors ----
$root    = New-TempDir 'offline'
$project = Join-Path $root 'project'
New-Item -ItemType Directory -Path $project -Force | Out-Null
Set-Content -Path (Join-Path $project '.ai-mail') -Value "root=Q:\does\not\exist\mail`ninbox=tom"
$out = Invoke-Hook $project
Assert-Silent $out 'unreachable pointer root stays silent'
Remove-Item $root -Recurse -Force

# --- Test 4: pointer resolves, inbox empty -> silent ---------------------------
$root    = New-TempDir 'empty'
$share   = Join-Path $root 'share\mail'
$project = Join-Path $root 'project'
New-Item -ItemType Directory -Path (Join-Path $share 'tom\archive') -Force | Out-Null
New-Item -ItemType Directory -Path $project -Force | Out-Null
Set-Content -Path (Join-Path $project '.ai-mail') -Value "root=$share`ninbox=tom"
$out = Invoke-Hook $project
Assert-Silent $out 'empty pointed inbox stays silent'
Remove-Item $root -Recurse -Force

# --- Test 5: archived mail in the pointed inbox is not reported ----------------
$root    = New-TempDir 'archived'
$share   = Join-Path $root 'share\mail'
$project = Join-Path $root 'project'
New-Item -ItemType Directory -Path (Join-Path $share 'tom\archive') -Force | Out-Null
New-Item -ItemType Directory -Path $project -Force | Out-Null
Set-Content -Path (Join-Path $share 'tom\archive\20260901-old.md') -Value "old"
Set-Content -Path (Join-Path $project '.ai-mail') -Value "root=$share`ninbox=tom"
$out = Invoke-Hook $project
Assert-Silent $out 'archived mail in pointed inbox is ignored'
Remove-Item $root -Recurse -Force

# --- Test 6: legacy mail\claude\ in the ancestry still works (no pointer) ------
$root    = New-TempDir 'legacy'
$project = Join-Path $root 'project'
New-Item -ItemType Directory -Path (Join-Path $project 'mail\claude\archive') -Force | Out-Null
Set-Content -Path (Join-Path $project 'mail\claude\20260910-legacy.md') -Value "---`nfrom: codex`nsubject: legacy`n---`nx"
$out = Invoke-Hook (Join-Path $project 'mail')
Assert-Contains $out '20260910-legacy.md' 'legacy mail\claude ancestry walk unchanged'
Remove-Item $root -Recurse -Force

# --- Test 7: malformed stdin payload -> silent, no errors ---------------------
# Contract: the hook must never spew at session start, whatever it is fed.
$raw = '{"cwd":"D:\AI"}'   # single backslash = bad JSON escape
$out = (@($raw | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Hook 2>&1) -join "`n")
Assert-Silent $out 'malformed JSON payload stays silent'

# --- Summary ------------------------------------------------------------------
if ($script:Failures -gt 0) {
    Write-Host "`n$($script:Failures) failing" -ForegroundColor Red
    exit 1
}
Write-Host "`nAll passed" -ForegroundColor Green
exit 0
