#!/usr/bin/env bash
# ai-tint.test.sh - behavioral tests for the zone-aware AI pane tint (WSL side).
#
# Sources shell/wsl-additions.sh in a child bash and asserts which tint colour
# _ai_zone_color picks for a given launch directory. Zone roots sit under the
# AI root this repo lives in (/mnt/c/AI, /mnt/d/AI, ...), so expected paths are
# built from the test's location. No bats dependency. Exit code 1 on any failure.
#
# Run (inside WSL):    bash scripts/tests/ai-tint.test.sh
# Run (from Windows):  wsl.exe -d Ubuntu -- bash /mnt/d/AI/Projects/AITerminalInterfaceConfigs/scripts/tests/ai-tint.test.sh

set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"
additions="$repo_root/shell/wsl-additions.sh"
ai_root="$(cd "$repo_root/../.." && pwd)"   # <AI root>: grandparent of the repo
failures=0

# Colours under test. Prod keeps the historical Claude wine so that red means
# "production" and nothing else; everything else is distinct from it.
red='#370617'
teal='#0b3a3a'
green='#0b2e1a'
slate='#2f2f2f'

zone_color() { # path [override_ai_root]
    local setup="source '$additions' >/dev/null 2>&1;"
    [ -n "${2:-}" ] && setup="$setup _AI_ROOT='$2';"
    # Merge stderr so a missing function shows up as the "got".
    bash -c "$setup _ai_zone_color '$1'" 2>&1
}

assert_equal() { # actual expected name
    if [ "$1" = "$2" ]; then
        printf '  PASS  %s\n' "$3"
    else
        printf '  FAIL  %s\n        expected: %s\n        got:      %s\n' "$3" "$2" "$1"
        failures=$((failures + 1))
    fi
}

echo "wsl-additions.sh zone tint tests (AI root: $ai_root)"

# --- Zone roots and their subfolders --------------------------------------------
assert_equal "$(zone_color "$ai_root/ProdEvents/ProdEvent_03062026 - ProdCRC")" "$red"   'ProdEvents subfolder tints deep red'
assert_equal "$(zone_color "$ai_root/LabEvents/TCSIM_TESTING")"                 "$teal"  'LabEvents subfolder tints dark teal'
assert_equal "$(zone_color "$ai_root/Projects/AITerminalInterfaceConfigs")"     "$green" 'Projects subfolder tints dark green'
assert_equal "$(zone_color "$ai_root/ProdEvents")"                              "$red"   'zone root itself tints'

# --- Outside every zone: slate, never red ---------------------------------------
assert_equal "$(zone_color "$ai_root")"           "$slate" 'AI root itself falls back to slate'
assert_equal "$(zone_color "$ai_root/Reference")" "$slate" 'non-zone sibling under the AI root falls back to slate'
assert_equal "$(zone_color "$HOME")"              "$slate" 'path outside the AI root falls back to slate'

# --- Matching edge cases --------------------------------------------------------
assert_equal "$(zone_color "${ai_root,,}/PRODEVENTS/x")"  "$red"   'zone match is case-insensitive (DrvFs is)'
assert_equal "$(zone_color "$ai_root/LabEvents/")"        "$teal"  'trailing slash still matches'
assert_equal "$(zone_color "$ai_root/ProdEventsArchive")" "$slate" 'sibling sharing a zone-name prefix does not match'

# --- The AI root is derived from the repo location, not a fixed drive -----------
# Models the other machine's layout: /mnt/c/AI when run from a /mnt/d/AI
# checkout and vice versa. The zones must follow the root, and the old drive
# must stop matching so a stale hardcoded path cannot leak a red pane.
case "$ai_root" in /mnt/c/*) other=/mnt/d/AI ;; *) other=/mnt/c/AI ;; esac
assert_equal "$(zone_color "$other/ProdEvents/x"   "$other")" "$red"   'zones follow the AI root when it moves'
assert_equal "$(zone_color "$ai_root/ProdEvents/x" "$other")" "$slate" 'old drive stops matching once the AI root moves'

# --- Summary ------------------------------------------------------------------
if [ "$failures" -gt 0 ]; then
    printf '\n%s failing\n' "$failures"
    exit 1
fi
printf '\nAll passed\n'
exit 0
