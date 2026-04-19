#!/usr/bin/env bash
# sync-memories.sh
# Change-gated sync for the ai-partner-memories repo.
# Bash equivalent of sync-memories.ps1 for ad-hoc manual runs.
#
# Flow:
#   1. If local repo has no changes -> exit 0 (no network hit).
#   2. Otherwise: git add -A, commit, pull --rebase, push.
#   3. On rebase conflict -> abort rebase, log, exit 1.
#
# Logs to ~/.claude/memory-sync.log

set -u

MEMORY_REPO_PATH="${MEMORY_REPO_PATH:-/mnt/d/AI/ai-partner-memories}"
LOG_FILE="${LOG_FILE:-$HOME/.claude/memory-sync.log}"

log() {
    local level=$1; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local line="$ts [$level] $msg"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$line" >> "$LOG_FILE"
    echo "$line"
}

if [ ! -d "$MEMORY_REPO_PATH" ]; then
    log ERROR "Memory repo not found at $MEMORY_REPO_PATH"
    exit 1
fi

# Change gate -- cheap, no network
if [ -z "$(git -C "$MEMORY_REPO_PATH" status --porcelain 2>/dev/null)" ]; then
    exit 0
fi

log INFO "Changes detected, syncing..."

git -C "$MEMORY_REPO_PATH" add -A >/dev/null 2>&1

if git -C "$MEMORY_REPO_PATH" diff --cached --quiet; then
    log INFO "Nothing staged after add; exiting."
    exit 0
fi

host_name="$(hostname)"
ts="$(date '+%Y-%m-%d %H:%M:%S')"
commit_msg="auto-sync from $host_name at $ts"

if ! commit_out="$(git -C "$MEMORY_REPO_PATH" commit -m "$commit_msg" 2>&1)"; then
    log WARN  "git commit failed -- $commit_out"
    exit 1
fi

if ! pull_out="$(git -C "$MEMORY_REPO_PATH" pull --rebase 2>&1)"; then
    log ERROR "git pull --rebase failed. Aborting rebase. -- $pull_out"
    git -C "$MEMORY_REPO_PATH" rebase --abort 2>/dev/null || true
    exit 1
fi

if ! push_out="$(git -C "$MEMORY_REPO_PATH" push 2>&1)"; then
    log ERROR "git push failed; committed locally but not pushed. -- $push_out"
    exit 1
fi

log INFO "Sync complete."
exit 0
