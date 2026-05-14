#!/usr/bin/env bash
# user-prompt-time.sh - invoked by Claude Code UserPromptSubmit hook.
# Bash/WSL twin of user-prompt-time.ps1.
#
# Emits the current wall-clock time as additionalContext so the model has
# fresh time-of-day awareness on every prompt. Designed to be fast: no stdin
# parsing, no I/O, no network. Fires on every prompt.

# Hard dependency on jq for safe JSON output. Exit silent rather than blow up
# every prompt if jq isn't installed.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

# Drain stdin so the parent doesn't block on the pipe write, but ignore content.
# UserPromptSubmit provides session payload + prompt; this hook doesn't need it.
cat >/dev/null 2>&1 || true

timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
day_of_week="$(date '+%A')"
context="Current local time: ${timestamp} (${day_of_week})"

jq -n --arg ctx "$context" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$ctx}}'
exit 0
