# verify-symlinks.ps1
# Read-only check that all bootstrap-created symlinks exist, point at the
# right target, and the target file is present. Exits 0 if all OK, 1 if any
# link is missing / wrong / dangling. Re-run bootstrap-windows.ps1 (admin)
# to repair.
#
# Usage:
#   .\verify-symlinks.ps1
#   .\verify-symlinks.ps1 -MemoryRepoPath "D:\AI\ai-partner-memories"

param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories"
)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent

$expected = @(
    @{ Label = "CLAUDE.md (Claude global)";  Path = "$env:USERPROFILE\.claude\CLAUDE.md";              Target = "$MemoryRepoPath\CLAUDE.md" },
    @{ Label = "AGENTS.md (Codex global)";   Path = "$env:USERPROFILE\.codex\AGENTS.md";               Target = "$MemoryRepoPath\AGENTS.md" },
    @{ Label = "WezTerm config";             Path = "$env:USERPROFILE\.config\wezterm\wezterm.lua";    Target = "$RepoRoot\wezterm\wezterm.lua" },
    @{ Label = "statusline.py";              Path = "$env:USERPROFILE\.claude\statusline.py";          Target = "$RepoRoot\claude\statusline.py" }
)

Write-Host ""
Write-Host "=== Symlink verification ===" -ForegroundColor Cyan
Write-Host ""

$ok   = 0
$fail = 0

foreach ($item in $expected) {
    $label  = $item.Label
    $path   = $item.Path
    $target = $item.Target

    if (-not (Test-Path $path)) {
        Write-Host ("  [ FAIL ] {0}" -f $label) -ForegroundColor Red
        Write-Host ("           {0}" -f $path)
        Write-Host  "           link missing"
        $fail++; continue
    }

    $info = Get-Item $path -Force
    if ($info.LinkType -ne "SymbolicLink") {
        Write-Host ("  [ FAIL ] {0}" -f $label) -ForegroundColor Red
        Write-Host ("           {0}" -f $path)
        Write-Host  "           exists but is a regular file, not a symlink"
        $fail++; continue
    }

    $actual = $info.Target
    if ($actual -is [array]) { $actual = $actual[0] }

    if ($actual -ne $target) {
        Write-Host ("  [ FAIL ] {0}" -f $label) -ForegroundColor Red
        Write-Host ("           {0}" -f $path)
        Write-Host ("           expected: {0}" -f $target)
        Write-Host ("           actual:   {0}" -f $actual)
        $fail++; continue
    }

    if (-not (Test-Path $target)) {
        Write-Host ("  [ FAIL ] {0}" -f $label) -ForegroundColor Red
        Write-Host ("           {0}" -f $path)
        Write-Host ("           dangling -- target does not exist: {0}" -f $target)
        $fail++; continue
    }

    Write-Host ("  [  OK  ] {0}" -f $label) -ForegroundColor Green
    Write-Host ("           {0} -> {1}" -f $path, $target) -ForegroundColor DarkGray
    $ok++
}

Write-Host ""
$total = $ok + $fail
if ($fail -eq 0) {
    Write-Host ("Summary: {0}/{1} OK" -f $ok, $total) -ForegroundColor Green
    exit 0
} else {
    Write-Host ("Summary: {0}/{1} OK, {2} FAIL" -f $ok, $total, $fail) -ForegroundColor Red
    Write-Host  "  Run scripts\bootstrap-windows.ps1 (admin PowerShell) to recreate broken links."
    exit 1
}
