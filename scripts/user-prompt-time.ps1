# user-prompt-time.ps1 - invoked by Claude Code UserPromptSubmit hook.
# Emits the current wall-clock time as additionalContext so the model has
# fresh time-of-day awareness on every prompt. Closes the gap where Claude
# sees the date in CLAUDE.md but not the hour/minute.
#
# Designed to be fast (sub-100ms): no stdin parsing, no I/O, no network.
# Fires on every prompt, so any added cost compounds across a session.

# PS 5.1 defaults stdout to OEM code page; force UTF-8 so the emitted JSON
# is consistent with the SessionStart hooks.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$now = Get-Date
$timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss zzz')
$dayOfWeek = $now.DayOfWeek

$context = "Current local time: $timestamp ($dayOfWeek)"

$payload = @{
    hookSpecificOutput = @{
        hookEventName     = 'UserPromptSubmit'
        additionalContext = $context
    }
} | ConvertTo-Json -Depth 5 -Compress

Write-Output $payload
exit 0
