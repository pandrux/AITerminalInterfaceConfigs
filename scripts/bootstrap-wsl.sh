#!/usr/bin/env bash
# bootstrap-wsl.sh
# Sets up WSL2 side: installs AI CLI tools, links shell config from repo
# Run directly or called by bootstrap-windows.ps1

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo "=== WSL Bootstrap ==="
echo "Repo: $REPO_ROOT"
echo ""

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
echo "[1/6] System packages..."

# Ensure apt cache is fresh
sudo apt-get update -qq

if command -v pip3 &>/dev/null; then
    echo "  ✓ pip3 already installed"
else
    echo "  Installing pip3..."
    sudo apt-get install -y python3-pip
    echo "  ✓ pip3 installed"
fi

if command -v zellij &>/dev/null; then
    echo "  ✓ Zellij already installed"
else
    echo "  Installing Zellij via snap..."
    sudo snap install zellij --classic
    echo "  ✓ Zellij installed"
fi

if dpkg -s bubblewrap &>/dev/null 2>&1; then
    echo "  ✓ bubblewrap already installed"
else
    echo "  Installing bubblewrap..."
    sudo apt-get install -y bubblewrap
    echo "  ✓ bubblewrap installed"
fi

if command -v starship &>/dev/null; then
    echo "  ✓ Starship already installed"
else
    echo "  Installing Starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    echo "  ✓ Starship installed"
fi

if command -v pandoc &>/dev/null; then
    echo "  ✓ Pandoc already installed"
else
    echo "  Installing Pandoc..."
    sudo apt-get install -y pandoc
    echo "  ✓ Pandoc installed"
fi

if dpkg -s texlive-latex-recommended &>/dev/null 2>&1; then
    echo "  ✓ texlive-latex-recommended already installed"
else
    echo "  Installing texlive (for PDF generation via Pandoc)..."
    sudo apt-get install -y texlive-latex-recommended
    echo "  ✓ texlive installed"
fi

if command -v libreoffice &>/dev/null; then
    echo "  ✓ LibreOffice already installed"
else
    echo "  Installing LibreOffice CLI..."
    sudo apt-get install -y libreoffice-core libreoffice-writer libreoffice-calc libreoffice-impress --no-install-recommends
    echo "  ✓ LibreOffice installed"
fi

AI_VENV="$HOME/.local/share/ai-venv"
if [ -d "$AI_VENV" ] && "$AI_VENV/bin/python3" -c "import pptx" &>/dev/null 2>&1; then
    echo "  ✓ Python venv + python-pptx already installed"
else
    echo "  Setting up Python venv with python-pptx..."
    sudo apt-get install -y python3-venv python3.12-venv -qq
    python3 -m venv "$AI_VENV"
    "$AI_VENV/bin/pip" install python-pptx
    echo "  ✓ python-pptx installed in $AI_VENV"
fi

# -----------------------------------------------------------------------------
# Node.js (via nvm) — required for Claude Code, Codex, Gemini CLI
# -----------------------------------------------------------------------------
echo "[2/6] Node.js..."
if ! command -v node &>/dev/null; then
    echo "  Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm use 22
    echo "  Node.js $(node --version) installed"
else
    echo "  Node.js $(node --version) — already installed"
fi

# -----------------------------------------------------------------------------
# AI CLI tools
# -----------------------------------------------------------------------------
echo "[3/6] AI CLI tools..."

install_npm_tool() {
    local pkg=$1
    local cmd=$2
    # Check nvm's bin specifically — Windows PATH can shadow missing Linux installs
    local nvm_bin="$HOME/.nvm/versions/node/$(node --version)/bin"
    if [ -x "$nvm_bin/$cmd" ]; then
        echo "  ✓ $cmd already installed (Linux)"
    else
        echo "  Installing $pkg..."
        npm install -g "$pkg"
        echo "  ✓ $cmd installed"
    fi
}

install_npm_tool "@anthropic-ai/claude-code" "claude"
install_npm_tool "@openai/codex"             "codex"
install_npm_tool "@google/gemini-cli"        "gemini"

# -----------------------------------------------------------------------------
# Shell config — link .bashrc additions from repo
# -----------------------------------------------------------------------------
echo "[4/6] Shell config..."

SHELL_ADDITIONS="$REPO_ROOT/shell/wsl-additions.sh"
MARKER="# === terminal-config repo additions ==="

if ! grep -q "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
    echo "" >> "$HOME/.bashrc"
    echo "$MARKER" >> "$HOME/.bashrc"
    echo "source \"$SHELL_ADDITIONS\"" >> "$HOME/.bashrc"
    echo "  Linked shell additions to .bashrc"
else
    echo "  Shell additions already linked"
fi

# -----------------------------------------------------------------------------
# Zellij config + layouts — link from repo into Zellij config
# -----------------------------------------------------------------------------
echo "[5/6] Zellij config + layouts..."

ZELLIJ_CONFIG_DIR="$HOME/.config/zellij"
ZELLIJ_LAYOUT_DIR="$ZELLIJ_CONFIG_DIR/layouts"
mkdir -p "$ZELLIJ_LAYOUT_DIR"

# Link base config
ZELLIJ_CONFIG="$ZELLIJ_CONFIG_DIR/config.kdl"
if [ -L "$ZELLIJ_CONFIG" ] || [ -f "$ZELLIJ_CONFIG" ]; then
    echo "  config.kdl already linked"
else
    ln -s "$REPO_ROOT/zellij/config.kdl" "$ZELLIJ_CONFIG"
    echo "  Linked config.kdl"
fi

for layout in "$REPO_ROOT"/zellij/layouts/*.kdl; do
    [ -f "$layout" ] || continue
    dest="$ZELLIJ_LAYOUT_DIR/$(basename "$layout")"
    if [ -L "$dest" ] || [ -f "$dest" ]; then
        echo "  $(basename "$layout") already linked"
    else
        ln -s "$layout" "$dest"
        echo "  Linked $(basename "$layout")"
    fi
done

# -----------------------------------------------------------------------------
# API keys reminder
# -----------------------------------------------------------------------------
echo "[6/6] API keys..."

KEYS_FILE="$HOME/.config/ai-keys.sh"
if [ ! -f "$KEYS_FILE" ]; then
    mkdir -p "$(dirname "$KEYS_FILE")"
    cat > "$KEYS_FILE" << 'EOF'
# AI API Keys — do NOT commit this file
# Source this from your .bashrc or wsl-additions.sh

# Perplexity (get from: https://www.perplexity.ai/settings/api)
# export PERPLEXITY_API_KEY="pplx-..."

# Google AI Studio (for Gemini CLI with API key auth)
# export GOOGLE_API_KEY="..."

# OpenAI (if using API key instead of ChatGPT account)
# export OPENAI_API_KEY="sk-..."
EOF
    echo "  Created $KEYS_FILE — fill in your API keys"
    echo "  This file is gitignored and will not be committed"
else
    echo "  API keys file already exists"
fi

echo ""
echo "=== WSL Bootstrap complete ==="
echo ""
echo "  Restart your WSL shell or run: source ~/.bashrc"
echo "  Then: claude, codex, gemini — all available"
echo "  Type 'ai' to launch the AI workbench in Zellij"
echo ""
