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
echo "[4/4] Updating Zellij..."
if command -v zellij &>/dev/null; then
    sudo snap refresh zellij
    echo "  ✓ Zellij updated"
else
    echo "  ✗ Zellij not installed — skipping"
fi

echo ""
echo "=== Update complete ==="
echo ""
