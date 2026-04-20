#!/usr/bin/env bash
# session-start-work-context.sh - invoked by Claude Code SessionStart hook.
# Bash/WSL twin of session-start-work-context.ps1.
#
# When the nearest CLAUDE.md on the cwd ancestry (excluding the global
# ~/.claude/CLAUDE.md) declares `Category: work` or `Category: work-adjacent`,
# emits the contents of work_context.md as additionalContext so the work
# profile is auto-loaded into the session. Exits silent otherwise.
#
# The nearest CLAUDE.md is authoritative -- a subproject that declares a
# different category overrides its parent workspace, even if the parent
# declares Category: work.

MEMORY_REPO_PATH="${MEMORY_REPO_PATH:-/mnt/d/AI/ai-partner-memories}"
WORK_CONTEXT_FILE="$MEMORY_REPO_PATH/work_context.md"

# Hard dependency on jq for both parsing stdin and emitting safe JSON output.
# Exit silent rather than blow up the session start if jq isn't installed.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

payload="$(cat)"
[ -z "$payload" ] && exit 0

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$cwd" ] && exit 0

# Resolve the global CLAUDE.md path so we can skip it on the walk.
# (The global file documents the Category system and contains backticked
# examples of "Category: work" that would otherwise match the regex.)
global_claude_md=""
if [ -e "${HOME:-}/.claude/CLAUDE.md" ]; then
    global_claude_md="$(readlink -f "$HOME/.claude/CLAUDE.md" 2>/dev/null || echo "$HOME/.claude/CLAUDE.md")"
fi

is_work=0
dir="$cwd"
while [ -n "$dir" ] && [ -d "$dir" ]; do
    candidate="$dir/CLAUDE.md"
    if [ -f "$candidate" ]; then
        candidate_resolved="$(readlink -f "$candidate" 2>/dev/null || echo "$candidate")"
        if [ "$candidate_resolved" != "$global_claude_md" ]; then
            # Nearest project CLAUDE.md -- its category is authoritative.
            # ^Category:\s*(work|work-adjacent)\s*$ line-anchored so that
            # backtick-wrapped or bulleted doc examples cannot false-match.
            if grep -Eq '^Category:[[:space:]]*(work|work-adjacent)[[:space:]]*$' "$candidate"; then
                is_work=1
            fi
            break
        fi
    fi
    parent="$(dirname "$dir")"
    if [ "$parent" = "$dir" ] || [ -z "$parent" ]; then
        break
    fi
    dir="$parent"
done

[ "$is_work" -ne 1 ] && exit 0

if [ ! -f "$WORK_CONTEXT_FILE" ]; then
    jq -n --arg msg "Project declared Category: work but $WORK_CONTEXT_FILE was not found." \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$msg}}'
    exit 0
fi

header="# Auto-loaded work context

Source: $WORK_CONTEXT_FILE

This project declared Category: work (or work-adjacent) in its CLAUDE.md. The facts below apply to the current session. Files referenced in 'Further reading' are loaded on demand -- read them when the topic comes up.

---

"

work_content="$(cat "$WORK_CONTEXT_FILE")"
combined="${header}${work_content}"

jq -n --arg ctx "$combined" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
