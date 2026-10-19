# ai-tint.Tests.ps1 - behavioral tests for the zone-aware AI pane tint.
#
# Dot-sources shell/windows-additions.ps1 under Windows PowerShell 5.1 (the
# engine WezTerm spawns, so the one the profile actually runs in) and asserts
# which tint colour _Get-AiZoneColor picks for a given launch directory.
# Zone roots sit under the AI root this repo lives in (D:\AI on the desktops,
# C:\AI on the laptop), so expected paths are built from the test's location.
# No Pester dependency. Exit code 1 on any failure.
#
# Run:  pwsh -NoProfile -File scripts\tests\ai-tint.Tests.ps1

$ErrorActionPreference = 'Stop'
$RepoRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Additions = Join-Path $RepoRoot 'shell\windows-additions.ps1'
$AiRoot    = Split-Path -Parent (Split-Path -Parent $RepoRoot)   # <AI root>: grandparent of the repo
$script:Failures = 0

# Colours under test. Prod keeps the historical Claude wine so that red means
# "production" and nothing else; everything else is distinct from it.
$Red   = '#370617'
$Teal  = '#0b3a3a'
$Green = '#0b2e1a'
$Slate = '#2f2f2f'

function Get-ZoneColor([string]$Path, [string]$OverrideAiRoot) {
    $setup = ". '$Additions';"
    if ($OverrideAiRoot) { $setup += " `$AiRoot = '$OverrideAiRoot';" }
    $cmd = "$setup _Get-AiZoneColor '$Path'"
    # Merge stderr so a missing function or a thrown error shows up as the "got".
    $out = powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $cmd 2>&1
    return (@($out) -join "`n").Trim()
}

function Assert-Equal([string]$Actual, [string]$Expected, [string]$TestName) {
    if ($Actual -eq $Expected) {
        Write-Host "  PASS  $TestName" -ForegroundColor Green
    } else {
        Write-Host "  FAIL  $TestName" -ForegroundColor Red
        Write-Host "        expected: $Expected"
        Write-Host "        got:      '$Actual'"
        $script:Failures++
    }
}

Write-Host "windows-additions.ps1 zone tint tests (AI root: $AiRoot)" -ForegroundColor Cyan

# --- Zone roots and their subfolders --------------------------------------------
Assert-Equal (Get-ZoneColor "$AiRoot\ProdEvents\ProdEvent_03062026 - ProdCRC") $Red   'ProdEvents subfolder tints deep red'
Assert-Equal (Get-ZoneColor "$AiRoot\LabEvents\TCSIM_TESTING")                 $Teal  'LabEvents subfolder tints dark teal'
Assert-Equal (Get-ZoneColor "$AiRoot\Projects\AITerminalInterfaceConfigs")     $Green 'Projects subfolder tints dark green'
Assert-Equal (Get-ZoneColor "$AiRoot\ProdEvents")                              $Red   'zone root itself tints'

# --- Outside every zone: slate, never red ---------------------------------------
Assert-Equal (Get-ZoneColor $AiRoot)              $Slate 'AI root itself falls back to slate'
Assert-Equal (Get-ZoneColor "$AiRoot\Reference")  $Slate 'non-zone sibling under the AI root falls back to slate'
Assert-Equal (Get-ZoneColor $env:USERPROFILE)     $Slate 'path outside the AI root falls back to slate'

# --- Matching edge cases --------------------------------------------------------
Assert-Equal (Get-ZoneColor "$($AiRoot.ToLower())\PRODEVENTS\x")         $Red   'zone match is case-insensitive'
Assert-Equal (Get-ZoneColor "$AiRoot\ProdEvents\")                       $Red   'trailing backslash still matches'
Assert-Equal (Get-ZoneColor ("$AiRoot\LabEvents\x" -replace '\\', '/')) $Teal  'forward slashes still match'
Assert-Equal (Get-ZoneColor "$AiRoot\ProdEventsArchive")                 $Slate 'sibling sharing a zone-name prefix does not match'

# --- The AI root is derived from the repo location, not a fixed drive -----------
# Models the other machine's layout: C:\AI when run from a D:\AI checkout and
# vice versa. The zones must follow the root, and the old drive must stop
# matching so a stale hardcoded path cannot leak a red pane.
$Other = if ($AiRoot -like 'C:*') { 'D:\AI' } else { 'C:\AI' }
Assert-Equal (Get-ZoneColor "$Other\ProdEvents\x"  -OverrideAiRoot $Other) $Red   'zones follow the AI root when it moves'
Assert-Equal (Get-ZoneColor "$AiRoot\ProdEvents\x" -OverrideAiRoot $Other) $Slate 'old drive stops matching once the AI root moves'

# --- Summary ------------------------------------------------------------------
if ($script:Failures -gt 0) {
    Write-Host "`n$($script:Failures) failing" -ForegroundColor Red
    exit 1
}
Write-Host "`nAll passed" -ForegroundColor Green
exit 0
