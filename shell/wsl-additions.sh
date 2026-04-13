# wsl-additions.sh
# Sourced by .bashrc — shared across all WSL instances via the dotfiles repo
# Keep this clean: aliases, functions, and environment only.
# Machine-specific overrides go in ~/.config/local-overrides.sh (gitignored)

# Resolve repo root from this script's location
_WSL_ADDITIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "$_WSL_ADDITIONS_DIR/.." && pwd)"

# -----------------------------------------------------------------------------
# API Keys (sourced from a gitignored file)
# -----------------------------------------------------------------------------
AI_KEYS="$HOME/.config/ai-keys.sh"
[ -f "$AI_KEYS" ] && source "$AI_KEYS"

# -----------------------------------------------------------------------------
# PATH additions
# -----------------------------------------------------------------------------
export PATH="$HOME/.local/share/ai-venv/bin:$HOME/.local/bin:/snap/bin:$PATH"

# Default browser — open OAuth flows and links in Windows Chrome
export BROWSER="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"

# nvm (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

# -----------------------------------------------------------------------------
# AI CLI shortcuts
# -----------------------------------------------------------------------------

# Quick one-shot queries (non-interactive, piped input friendly)
# Usage: ask-claude "what does this do?" < somefile.py
ask-claude() { claude -p "$*"; }
ask-gemini() { gemini -p "$*"; }

# Pipe a file to all three agents simultaneously for comparative analysis
# Usage: compare-ai "what is the bug in this code?" < error.py
# Or:    compare-ai "summarize this log" < app.log
compare-ai() {
    local prompt="$1"
    local input
    input=$(cat)   # read stdin into variable

    echo "━━━ CLAUDE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$input" | claude -p "$prompt" &
    local claude_pid=$!

    echo "━━━ GEMINI ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$input" | gemini -p "$prompt" &
    local gemini_pid=$!

    echo "━━━ CODEX ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$input" | codex -q "$prompt" &
    local codex_pid=$!

    wait $claude_pid $gemini_pid $codex_pid
    echo "━━━ DONE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Broadcast a prompt to all tmux panes (interactive sessions)
# Useful when you want all running AI sessions to get the same input
# Requires tmux to be running
broadcast-ai() {
    local prompt="$1"
    if [ -z "$TMUX" ]; then
        echo "Not in a tmux session. Use compare-ai for non-interactive broadcast."
        return 1
    fi
    tmux set-window-option synchronize-panes on
    tmux send-keys "$prompt" Enter
    tmux set-window-option synchronize-panes off
    echo "Prompt sent to all panes. Synchronize-panes is now OFF."
}

# Toggle pane sync manually
alias sync-on='tmux set-window-option synchronize-panes on && echo "Pane sync ON"'
alias sync-off='tmux set-window-option synchronize-panes off && echo "Pane sync OFF"'

# -----------------------------------------------------------------------------
# AI Workbench launcher
# -----------------------------------------------------------------------------
alias ai='zellij --layout ai-workbench'
alias update-ai='bash "$_REPO_ROOT/scripts/update.sh"'

# -----------------------------------------------------------------------------
# General productivity
# -----------------------------------------------------------------------------

# Quick navigation to common project directories
# Adjust these paths to match your actual directory structure
alias ptc='cd ~/projects/ptc && echo "→ ptc"'
alias homelab='cd ~/projects/homelab && echo "→ homelab"'
alias possum='cd ~/projects/possum && echo "→ possum"'

# Pretty-print JSON logs (useful for PTC/ATCS log analysis)
alias jlog='python3 -m json.tool'

# Document conversion shortcuts
# Usage: to-docx report.md    → report.docx
#        to-pdf  report.md    → report.pdf
#        to-pptx slides.md    → slides.pptx
#        to-html report.md    → report.html
to-docx() { pandoc "$1" -o "${1%.*}.docx"; echo "→ ${1%.*}.docx"; }
to-pdf()  { pandoc "$1" -o "${1%.*}.pdf";  echo "→ ${1%.*}.pdf"; }
to-pptx() { pandoc "$1" -o "${1%.*}.pptx"; echo "→ ${1%.*}.pptx"; }
to-html() { pandoc "$1" -o "${1%.*}.html"; echo "→ ${1%.*}.html"; }

# Tail a log and pipe it to Claude for live analysis
# Usage: watch-log /path/to/app.log "explain any errors you see"
watch-log() {
    local logfile="$1"
    local prompt="${2:-summarize any errors or anomalies}"
    tail -f "$logfile" | while IFS= read -r line; do
        echo "$line"
        echo "$line" | claude -p "$prompt" --no-conversation 2>/dev/null
    done
}

# -----------------------------------------------------------------------------
# Load machine-local overrides (gitignored, machine-specific paths/settings)
# -----------------------------------------------------------------------------
LOCAL_OVERRIDES="$HOME/.config/local-overrides.sh"
[ -f "$LOCAL_OVERRIDES" ] && source "$LOCAL_OVERRIDES"

# -----------------------------------------------------------------------------
# Starship prompt (must be last — replaces PS1)
# -----------------------------------------------------------------------------
if command -v starship &>/dev/null; then
    export STARSHIP_CONFIG="$_REPO_ROOT/shell/starship.toml"
    eval "$(starship init bash)"
fi
