#!/usr/bin/env bash
# update.sh — Pull latest config and update all tools
# Usage: update-ai (alias) or ./scripts/update.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "=== AI Terminal Config Update ==="
echo ""

# -----------------------------------------------------------------------------
# Pull latest config
# -----------------------------------------------------------------------------
echo "[1/4] Pulling latest config..."
cd "$REPO_ROOT"
git pull --ff-only
echo ""

# -----------------------------------------------------------------------------
# Update AI CLI tools (npm)
# -----------------------------------------------------------------------------
echo "[2/4] Updating AI CLI tools..."

update_npm_tool() {
    local pkg=$1
    local cmd=$2
    if command -v "$cmd" &>/dev/null; then
        echo "  Updating $pkg..."
        npm update -g "$pkg"
        echo "  ✓ $cmd updated"
    else
        echo "  ✗ $cmd not installed — skipping"
    fi
}

update_npm_tool "@anthropic-ai/claude-code" "claude"
update_npm_tool "@openai/codex"             "codex"
update_npm_tool "@google/gemini-cli"        "gemini"
echo ""

# -----------------------------------------------------------------------------
# Update Starship
# -----------------------------------------------------------------------------
echo "[3/4] Updating Starship..."
if command -v starship &>/dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    echo "  ✓ Starship updated"
else
    echo "  ✗ Starship not installed — skipping"
fi
echo ""

# -----------------------------------------------------------------------------
# Update Zellij
# -----------------------------------------------------------------------------
echo "[4/5] Updating Zellij..."
if command -v zellij &>/dev/null; then
    sudo snap refresh zellij
    echo "  ✓ Zellij updated"
else
    echo "  ✗ Zellij not installed — skipping"
fi
echo ""

# -----------------------------------------------------------------------------
# Re-sync Zellij config + layout symlinks (picks up newly added layouts)
# -----------------------------------------------------------------------------
echo "[5/5] Re-syncing Zellij symlinks..."

ZELLIJ_CONFIG_DIR="$HOME/.config/zellij"
ZELLIJ_LAYOUT_DIR="$ZELLIJ_CONFIG_DIR/layouts"
mkdir -p "$ZELLIJ_LAYOUT_DIR"

relink() {
    local src=$1
    local dest=$2
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "  ⚠ $dest is a real file, not a symlink — leaving alone"
        return
    fi
    ln -sfn "$src" "$dest"
    echo "  ✓ $(basename "$dest")"
}

relink "$REPO_ROOT/zellij/config.kdl" "$ZELLIJ_CONFIG_DIR/config.kdl"

for layout in "$REPO_ROOT"/zellij/layouts/*.kdl; do
    [ -f "$layout" ] || continue
    relink "$layout" "$ZELLIJ_LAYOUT_DIR/$(basename "$layout")"
done

echo ""
echo "=== Update complete ==="
echo "  (Restart any running Zellij sessions to pick up config changes)"
echo ""
