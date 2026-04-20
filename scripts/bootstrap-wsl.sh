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

# Mark repo as safe for git — required when the repo lives on a Windows mount
# (/mnt/c, /mnt/d, ...) because the NTFS owner UID doesn't match the WSL user.
if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$REPO_ROOT"; then
    git config --global --add safe.directory "$REPO_ROOT"
    echo "  Added $REPO_ROOT to git safe.directory"
fi

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
echo "[1/8] System packages..."

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

if command -v jq &>/dev/null; then
    echo "  ✓ jq already installed"
else
    echo "  Installing jq..."
    sudo apt-get install -y jq
    echo "  ✓ jq installed"
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
echo "[2/8] Node.js..."
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
echo "[3/8] AI CLI tools..."

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
echo "[4/8] Shell config..."

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
echo "[5/8] Zellij config + layouts..."

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
echo "[6/8] API keys..."

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

# -----------------------------------------------------------------------------
# Claude Code statusline + settings
# -----------------------------------------------------------------------------
echo "[7/8] Claude Code statusline..."

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"
STATUSLINE_TARGET="$CLAUDE_DIR/statusline.py"
STATUSLINE_SOURCE="$REPO_ROOT/claude/statusline.py"

if [ -L "$STATUSLINE_TARGET" ] || [ -f "$STATUSLINE_TARGET" ]; then
    if [ ! -L "$STATUSLINE_TARGET" ]; then
        mv "$STATUSLINE_TARGET" "$STATUSLINE_TARGET.bak-$(date +%Y%m%d-%H%M)"
        ln -s "$STATUSLINE_SOURCE" "$STATUSLINE_TARGET"
        echo "  Backed up existing statusline.py and linked repo version"
    else
        echo "  statusline.py already linked"
    fi
else
    ln -s "$STATUSLINE_SOURCE" "$STATUSLINE_TARGET"
    echo "  Linked $STATUSLINE_TARGET -> $STATUSLINE_SOURCE"
fi

SETTINGS_FILE="$CLAUDE_DIR/settings.json"
# Prefer /usr/bin/python3 over anything `command -v` finds — the ai-venv
# pptx environment may be on PATH and we don't want statusline tied to it.
if [ -x /usr/bin/python3 ]; then
    PY_BIN="/usr/bin/python3"
else
    PY_BIN="$(command -v python3 || command -v python || echo python3)"
fi
STATUSLINE_CMD="$PY_BIN $STATUSLINE_TARGET"

if command -v jq &>/dev/null; then
    if [ ! -f "$SETTINGS_FILE" ]; then echo '{}' > "$SETTINGS_FILE"; fi
    tmp="$(mktemp)"
    jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    echo "  Registered statusLine in $SETTINGS_FILE"
else
    echo "  (jq not installed — skipping settings.json patch; add manually:)"
    echo "    \"statusLine\": {\"type\":\"command\",\"command\":\"$STATUSLINE_CMD\"}"
fi

# SessionStart hook registration. Each hook is idempotent via filename match
# against existing hook commands, so re-running bootstrap won't double-register.
register_session_start_hook() {
    local script_path="$1"
    local timeout="$2"
    local status_msg="$3"

    if [ ! -f "$script_path" ]; then
        echo "  WARN: $script_path not found; skipping hook."
        return 0
    fi
    if ! command -v jq &>/dev/null; then
        echo "  (jq not installed — skipping SessionStart hook for $(basename "$script_path"))"
        return 0
    fi
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
    fi

    local leaf
    leaf="$(basename "$script_path")"
    # Invoke via `bash` explicitly: the repo on /mnt/d may be on DrvFs where
    # the executable bit isn't reliably preserved.
    local cmd="bash $script_path"

    local already
    already="$(jq --arg leaf "$leaf" '
        (.hooks.SessionStart // [])
        | map(.hooks // [])
        | flatten
        | map(.command // "")
        | any(contains($leaf))
    ' "$SETTINGS_FILE")"

    if [ "$already" = "true" ]; then
        echo "  SessionStart hook already registered: $leaf"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    jq --arg cmd "$cmd" --argjson timeout "$timeout" --arg msg "$status_msg" '
        .hooks //= {}
        | .hooks.SessionStart //= []
        | .hooks.SessionStart += [{
            hooks: [{
                type: "command",
                command: $cmd,
                timeout: $timeout,
                statusMessage: $msg
            }]
          }]
    ' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    echo "  Registered SessionStart hook: $script_path"
}

# Drift-check hook: fetches origin on this repo so Claude can offer a
# fast-forward pull at session start instead of running into mid-edit
# stash/replay from weekend drift. Mirror of the Windows-side hook.
register_session_start_hook \
    "$REPO_ROOT/scripts/session-start-status.sh" \
    15 \
    "Checking AITerminalInterfaceConfigs for upstream drift..."

# Work-context hook: auto-loads work_context.md from ai-partner-memories when
# the session's project CLAUDE.md declares Category: work or work-adjacent.
# No-op otherwise. Mirror of the Windows-side hook registered in
# bootstrap-windows.ps1.
register_session_start_hook \
    "$REPO_ROOT/scripts/session-start-work-context.sh" \
    10 \
    "Loading work context if Category: work..."

# -----------------------------------------------------------------------------
# Private memory repo (ai-partner-memories)
# -----------------------------------------------------------------------------
echo "[8/8] Private memory repo..."

MEMORY_REPO_PATH="${MEMORY_REPO_PATH:-/mnt/d/AI/ai-partner-memories}"
MEMORY_REPO_URL="https://github.com/pandrux/ai-partner-memories.git"
MEMORY_SKIP=""

if [ ! -d "$MEMORY_REPO_PATH" ]; then
    MEMORY_PARENT="$(dirname "$MEMORY_REPO_PATH")"
    mkdir -p "$MEMORY_PARENT"
    echo "  Cloning $MEMORY_REPO_URL..."
    if git clone "$MEMORY_REPO_URL" "$MEMORY_REPO_PATH"; then
        echo "  ✓ Cloned to $MEMORY_REPO_PATH"
    else
        echo "  ✗ Clone failed (is GitHub auth configured?). Skipping CLAUDE.md link."
        MEMORY_SKIP=1
    fi
else
    echo "  ✓ Memory repo already present at $MEMORY_REPO_PATH"
fi

# Mark safe.directory when the repo lives on a Windows mount
if [[ "$MEMORY_REPO_PATH" == /mnt/* ]]; then
    if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$MEMORY_REPO_PATH"; then
        git config --global --add safe.directory "$MEMORY_REPO_PATH"
        echo "  Added $MEMORY_REPO_PATH to git safe.directory"
    fi
fi

if [ -z "$MEMORY_SKIP" ]; then
    CLAUDE_MD_TARGET="$CLAUDE_DIR/CLAUDE.md"
    CLAUDE_MD_SOURCE="$MEMORY_REPO_PATH/CLAUDE.md"

    if [ -f "$CLAUDE_MD_SOURCE" ]; then
        if [ -L "$CLAUDE_MD_TARGET" ]; then
            existing="$(readlink "$CLAUDE_MD_TARGET")"
            if [ "$existing" = "$CLAUDE_MD_SOURCE" ]; then
                echo "  ✓ CLAUDE.md already linked"
            else
                rm "$CLAUDE_MD_TARGET"
                ln -s "$CLAUDE_MD_SOURCE" "$CLAUDE_MD_TARGET"
                echo "  ✓ Re-linked $CLAUDE_MD_TARGET -> $CLAUDE_MD_SOURCE"
            fi
        elif [ -f "$CLAUDE_MD_TARGET" ]; then
            mv "$CLAUDE_MD_TARGET" "$CLAUDE_MD_TARGET.bak-$(date +%Y%m%d-%H%M)"
            ln -s "$CLAUDE_MD_SOURCE" "$CLAUDE_MD_TARGET"
            echo "  Backed up existing CLAUDE.md and linked repo version"
        else
            ln -s "$CLAUDE_MD_SOURCE" "$CLAUDE_MD_TARGET"
            echo "  ✓ Linked $CLAUDE_MD_TARGET -> $CLAUDE_MD_SOURCE"
        fi
    else
        echo "  WARN: $CLAUDE_MD_SOURCE does not exist (repo may be empty)"
    fi

    # AGENTS.md symlink for Codex CLI (mirrors the CLAUDE.md pattern above).
    AGENTS_MD_TARGET="$HOME/.codex/AGENTS.md"
    AGENTS_MD_SOURCE="$MEMORY_REPO_PATH/AGENTS.md"
    mkdir -p "$HOME/.codex"

    if [ -f "$AGENTS_MD_SOURCE" ]; then
        if [ -L "$AGENTS_MD_TARGET" ]; then
            existing="$(readlink "$AGENTS_MD_TARGET")"
            if [ "$existing" = "$AGENTS_MD_SOURCE" ]; then
                echo "  ✓ AGENTS.md already linked"
            else
                rm "$AGENTS_MD_TARGET"
                ln -s "$AGENTS_MD_SOURCE" "$AGENTS_MD_TARGET"
                echo "  ✓ Re-linked $AGENTS_MD_TARGET -> $AGENTS_MD_SOURCE"
            fi
        elif [ -f "$AGENTS_MD_TARGET" ]; then
            mv "$AGENTS_MD_TARGET" "$AGENTS_MD_TARGET.bak-$(date +%Y%m%d-%H%M)"
            ln -s "$AGENTS_MD_SOURCE" "$AGENTS_MD_TARGET"
            echo "  Backed up existing AGENTS.md and linked repo version"
        else
            ln -s "$AGENTS_MD_SOURCE" "$AGENTS_MD_TARGET"
            echo "  ✓ Linked $AGENTS_MD_TARGET -> $AGENTS_MD_SOURCE"
        fi
    else
        echo "  WARN: $AGENTS_MD_SOURCE does not exist (repo may be empty)"
    fi
fi

echo ""
echo "=== WSL Bootstrap complete ==="
echo ""
echo "  Restart your WSL shell or run: source ~/.bashrc"
echo "  Then: claude, codex, gemini — all available"
echo "  Type 'ai' to launch the AI workbench in Zellij"
echo ""
