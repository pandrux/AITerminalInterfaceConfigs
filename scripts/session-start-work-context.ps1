# session-start-work-context.ps1 - invoked by Claude Code SessionStart hook.
# When the current project's CLAUDE.md declares `Category: work` or
# `Category: work-adjacent`, emits the contents of work_context.md as
# additionalContext so the work profile is auto-loaded into the session.
#
# Semantics: the nearest CLAUDE.md on the cwd ancestry (excluding the global
# ~/.claude/CLAUDE.md) is authoritative. If it declares work/work-adjacent we
# load; otherwise we exit silent -- even if a more distant ancestor declares
# work. This lets a subproject override its parent workspace.
#
# The global CLAUDE.md documents the category system and its own body contains
# backticked examples of "Category: work". We skip that file outright, and the
# match regex is line-anchored so docs examples in other files also cannot
# trigger a false match.

param(
    [string]$MemoryRepoPath = "D:\AI\ai-partner-memories"
)

# PS 5.1 defaults stdout to the OEM code page, which transliterates em-dashes
# and other non-ASCII chars on their way out. Force UTF-8 so the JSON emitted
# to Claude Code matches what we read from work_context.md.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Emit-Context($text) {
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = $text
        }
    } | ConvertTo-Json -Depth 5 -Compress
    Write-Output $payload
}

# Claude Code passes the session payload (session_id, cwd, hook_event_name, ...)
# on stdin. If parsing fails, exit silent rather than risk guessing -- a manual
# run from a work dir shouldn't spuriously emit work context.
$cwd = $null
try {
    $stdinText = [Console]::In.ReadToEnd()
    if ($stdinText -and $stdinText.Trim()) {
        $parsed = $stdinText | ConvertFrom-Json -ErrorAction Stop
        if ($parsed.cwd) { $cwd = [string]$parsed.cwd }
    }
} catch {
    # swallow -- exits below if $cwd is null
}
if (-not $cwd) { exit 0 }

# Resolve the global CLAUDE.md path so we can skip it on the walk.
$globalFullName = $null
$globalCandidate = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
if (Test-Path $globalCandidate) {
    try { $globalFullName = (Get-Item $globalCandidate).FullName } catch { }
}

# Line-anchored so backtick-wrapped or bullet-list doc examples never match.
$pattern = '(?m)^Category:\s*(work|work-adjacent)\s*$'

$dir = $cwd
$isWork = $false
while ($dir -and (Test-Path $dir)) {
    $candidate = Join-Path $dir 'CLAUDE.md'
    if (Test-Path $candidate) {
        $candidateFullName = $null
        try { $candidateFullName = (Get-Item $candidate).FullName } catch { }
        $isGlobal = $false
        if ($globalFullName -and $candidateFullName -and
            ($candidateFullName -ieq $globalFullName)) {
            $isGlobal = $true
        }
        if (-not $isGlobal) {
            # Nearest project CLAUDE.md found -- its category is authoritative.
            $content = Get-Content $candidate -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($content -and ($content -match $pattern)) {
                $isWork = $true
            }
            break
        }
    }
    $parent = Split-Path -Parent $dir
    if (-not $parent -or ($parent -eq $dir)) { break }
    $dir = $parent
}

if (-not $isWork) { exit 0 }

$workContextPath = Join-Path $MemoryRepoPath 'work_context.md'
if (-not (Test-Path $workContextPath)) {
    Emit-Context "Project declared Category: work but $workContextPath was not found."
    exit 0
}

# -Encoding UTF8 is required: PS 5.1's Get-Content defaults to Default (ANSI)
# when a file has no BOM, mangling multi-byte characters (em-dashes, etc).
$workContent = Get-Content $workContextPath -Raw -Encoding UTF8
$header = "# Auto-loaded work context`n`nSource: $workContextPath`n`nThis project declared Category: work (or work-adjacent) in its CLAUDE.md. The facts below apply to the current session. Files referenced in 'Further reading' are loaded on demand -- read them when the topic comes up.`n`n---`n`n"

Emit-Context ($header + $workContent)
exit 0
