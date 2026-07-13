# session-start-mail.ps1 - invoked by Claude Code SessionStart hook.
# If the project uses the AI-to-AI mail convention (see templates/mail/README.md)
# and Claude's inbox contains unprocessed messages, emits a notification as
# additionalContext so Claude checks its mail without the project CLAUDE.md
# having to say so.
#
# Semantics: walk the cwd ancestry for the nearest directory containing
# mail/claude/. Unprocessed = top-level *.md files in that inbox (archived
# messages live in mail/claude/archive/ and are ignored). Exits silent when
# there is no mailbox or no unread mail.

# PS 5.1 defaults stdout to the OEM code page, which transliterates em-dashes
# and other non-ASCII chars on their way out. Force UTF-8 so the JSON emitted
# to Claude Code survives intact.
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
# on stdin. If parsing fails, exit silent.
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

# Nearest mail/claude/ on the ancestry wins.
$inbox = $null
$dir = $cwd
while ($dir -and (Test-Path $dir)) {
    $candidate = Join-Path $dir 'mail\claude'
    if (Test-Path $candidate -PathType Container) {
        $inbox = $candidate
        break
    }
    $parent = Split-Path -Parent $dir
    if (-not $parent -or ($parent -eq $dir)) { break }
    $dir = $parent
}
if (-not $inbox) { exit 0 }

$unread = @(Get-ChildItem -Path $inbox -File -Filter '*.md' -ErrorAction SilentlyContinue |
    Sort-Object Name)
if ($unread.Count -eq 0) { exit 0 }

$mailRoot = Split-Path -Parent $inbox
$list = ($unread | ForEach-Object { "- $($_.Name)" }) -join "`n"
$plural = if ($unread.Count -eq 1) { 'message' } else { 'messages' }

$text = "# Unread AI mail`n`nYour inbox at $inbox has $($unread.Count) unprocessed $plural`:`n`n$list`n`nRead them before starting work; protocol in $mailRoot\README.md. After acting on a message, move it to the inbox's archive/ subfolder."

Emit-Context $text
exit 0
