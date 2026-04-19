#!/usr/bin/env bash
# verify-symlinks.sh
# Read-only check that all bootstrap-created symlinks exist, point at the
# right target, and the target file is present. Exits 0 if all OK, 1 if any
# link is missing / wrong / dangling. Re-run bootstrap-wsl.sh to repair.
#
# Usage:
#   ./verify-symlinks.sh
#   MEMORY_REPO_PATH=/mnt/d/AI/ai-partner-memories ./verify-symlinks.sh

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_REPO_PATH="${MEMORY_REPO_PATH:-/mnt/d/AI/ai-partner-memories}"

ok=0
fail=0

if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; GREY='\033[0;90m'; NC='\033[0m'
else
    GREEN=''; RED=''; CYAN=''; GREY=''; NC=''
fi

check_link() {
    local label="$1"
    local path="$2"
    local expected="$3"

    if [ ! -L "$path" ]; then
        if [ -e "$path" ]; then
            printf "  ${RED}[ FAIL ]${NC} %s\n" "$label"
            printf "           %s\n" "$path"
            printf "           exists but is a regular file, not a symlink\n"
        else
            printf "  ${RED}[ FAIL ]${NC} %s\n" "$label"
            printf "           %s\n" "$path"
            printf "           link missing\n"
        fi
        fail=$((fail + 1))
        return
    fi

    local actual
    actual="$(readlink "$path")"
    if [ "$actual" != "$expected" ]; then
        printf "  ${RED}[ FAIL ]${NC} %s\n" "$label"
        printf "           %s\n" "$path"
        printf "           expected: %s\n" "$expected"
        printf "           actual:   %s\n" "$actual"
        fail=$((fail + 1))
        return
    fi

    if [ ! -e "$path" ]; then
        printf "  ${RED}[ FAIL ]${NC} %s\n" "$label"
        printf "           %s\n" "$path"
        printf "           dangling -- target does not exist: %s\n" "$expected"
        fail=$((fail + 1))
        return
    fi

    printf "  ${GREEN}[  OK  ]${NC} %s\n" "$label"
    printf "           ${GREY}%s -> %s${NC}\n" "$path" "$expected"
    ok=$((ok + 1))
}

printf "\n${CYAN}=== Symlink verification ===${NC}\n\n"

# ai-partner-memories
check_link "CLAUDE.md (Claude global)" "$HOME/.claude/CLAUDE.md" "$MEMORY_REPO_PATH/CLAUDE.md"
check_link "AGENTS.md (Codex global)"  "$HOME/.codex/AGENTS.md"  "$MEMORY_REPO_PATH/AGENTS.md"

# AITerminalInterfaceConfigs (WSL-side)
check_link "Zellij config"             "$HOME/.config/zellij/config.kdl" "$REPO_ROOT/zellij/config.kdl"
check_link "statusline.py"             "$HOME/.claude/statusline.py"     "$REPO_ROOT/claude/statusline.py"

# Zellij layouts -- one per file in the repo
for layout in "$REPO_ROOT"/zellij/layouts/*.kdl; do
    [ -f "$layout" ] || continue
    name="$(basename "$layout")"
    check_link "Zellij layout $name" "$HOME/.config/zellij/layouts/$name" "$layout"
done

printf "\n"
total=$((ok + fail))
if [ "$fail" -eq 0 ]; then
    printf "${GREEN}Summary: %d/%d OK${NC}\n" "$ok" "$total"
    exit 0
else
    printf "${RED}Summary: %d/%d OK, %d FAIL${NC}\n" "$ok" "$total" "$fail"
    printf "  Run scripts/bootstrap-wsl.sh to recreate broken links.\n"
    exit 1
fi
