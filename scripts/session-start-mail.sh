#!/usr/bin/env bash
# session-start-mail.sh - invoked by Claude Code SessionStart hook.
# Bash/WSL twin of session-start-mail.ps1.
#
# If the project uses the AI-to-AI mail convention (see templates/mail/README.md)
# and Claude's inbox contains unprocessed messages, emits a notification as
# additionalContext. Unprocessed = top-level *.md files in the nearest
# mail/claude/ on the cwd ancestry (archive/ is ignored). Exits silent when
# there is no mailbox or no unread mail.

# Hard dependency on jq for both parsing stdin and emitting safe JSON output.
# Exit silent rather than blow up the session start if jq isn't installed.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

payload="$(cat)"
[ -z "$payload" ] && exit 0

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$cwd" ] && exit 0

# Nearest mail/claude/ on the ancestry wins.
inbox=""
dir="$cwd"
while [ -n "$dir" ] && [ -d "$dir" ]; do
    if [ -d "$dir/mail/claude" ]; then
        inbox="$dir/mail/claude"
        break
    fi
    parent="$(dirname "$dir")"
    if [ "$parent" = "$dir" ] || [ -z "$parent" ]; then
        break
    fi
    dir="$parent"
done
[ -z "$inbox" ] && exit 0

unread="$(find "$inbox" -maxdepth 1 -type f -name '*.md' -printf '%f\n' 2>/dev/null | sort)"
[ -z "$unread" ] && exit 0

count="$(printf '%s\n' "$unread" | wc -l)"
plural="messages"
[ "$count" -eq 1 ] && plural="message"
list="$(printf '%s\n' "$unread" | sed 's/^/- /')"
mail_root="$(dirname "$inbox")"

text="# Unread AI mail

Your inbox at $inbox has $count unprocessed $plural:

$list

Read them before starting work; protocol in $mail_root/README.md. After acting on a message, move it to the inbox's archive/ subfolder."

jq -n --arg ctx "$text" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
