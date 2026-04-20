#!/usr/bin/env bash
# session-start-status.sh - invoked by Claude Code SessionStart hook.
# Bash/WSL twin of session-start-status.ps1: fetches origin on the configs
# repo and emits branch/drift status as additionalContext so Claude can
# proactively offer a fast-forward pull when the repo is behind, instead of
# discovering drift mid-edit and triggering a stash/replay.

REPO_PATH="${REPO_PATH:-/mnt/d/AI/Projects/AITerminalInterfaceConfigs}"

# Hard dependency on jq for safe JSON output. Exit silent if missing rather
# than blow up session start.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

emit() {
    jq -n --arg ctx "$1" \
        '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
}

if [ ! -d "$REPO_PATH" ]; then
    emit "AITerminalInterfaceConfigs not found at $REPO_PATH (skipping drift check)."
    exit 0
fi

# Fetch silently; treat any network failure as offline rather than failing.
git -C "$REPO_PATH" fetch --quiet 2>/dev/null || true

status="$(git -C "$REPO_PATH" status --short --branch 2>&1)"
emit "AITerminalInterfaceConfigs ($REPO_PATH) status:
$status"
