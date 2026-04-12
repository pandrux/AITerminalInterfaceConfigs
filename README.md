# terminal-config

Personal terminal configuration — WezTerm, WSL2, and AI CLI tooling.
Designed for consistent use across Windows 11 machines.

## Machines

| Machine | Role | Notes |
|---|---|---|
| Work Desktop | PTC/ATCS engineering, primary AI work | RDP target, sessions persist |
| Home Desktop | Mixed work + homelab + personal | WSL2 hub |
| Laptop | Personal dev only | Focused, lighter setup |

## Quick Start

### On a new Windows machine

```powershell
git clone https://github.com/YOUR_USERNAME/terminal-config
cd terminal-config
.\scripts\bootstrap-windows.ps1
```

### WSL only (no Windows bootstrap needed)

```bash
./scripts/bootstrap-wsl.sh
```

## Key Bindings

Leader key: `CTRL+SPACE` (release, then next key)

| Key | Action |
|---|---|
| `Leader + a` | Launch AI Workbench (4-pane layout) |
| `Leader + w` | Workspace picker |
| `Leader + 1` | Switch to ai-workbench workspace |
| `Leader + 2` | Switch to work-ptc workspace |
| `Leader + 3` | Switch to work-homelab workspace |
| `Leader + 4` | Switch to personal-dev workspace |
| `Leader + \|` | Split pane vertical |
| `Leader + -` | Split pane horizontal |
| `Leader + h/j/k/l` | Navigate panes |
| `Leader + H/J/K/L` | Resize pane |
| `Leader + z` | Zoom/unzoom pane |
| `Leader + t` | New tab |
| `Leader + ,` | Rename tab |

## AI Workbench Layout

Press `Leader + a` to spawn:

```
┌─────────────────────┬─────────────────────┐
│                     │                     │
│    Claude Code      │    Codex CLI        │
│                     │                     │
├─────────────────────┼─────────────────────┤
│                     │                     │
│    Gemini CLI       │    Scratch / Shell  │
│                     │                     │
└─────────────────────┴─────────────────────┘
```

## Shell Functions (WSL)

```bash
# One-shot queries
ask-claude "explain this function" < code.py
ask-gemini "summarize" < report.txt

# Comparative analysis — same input, all three models
compare-ai "what is the bug here?" < error_log.txt

# Broadcast to all panes in current tmux window
broadcast-ai "analyze this stack trace"
```

## File Structure

```
terminal-config/
├── wezterm/
│   └── wezterm.lua          # Main WezTerm config
├── shell/
│   └── wsl-additions.sh     # Sourced by .bashrc
├── scripts/
│   ├── bootstrap-windows.ps1
│   └── bootstrap-wsl.sh
└── .gitignore
```

## Customization Per Machine

Create `~/.config/local-overrides.sh` (gitignored) for machine-specific paths,
aliases, or environment variables that shouldn't be shared across machines.

## API Keys

Stored in `~/.config/ai-keys.sh` (gitignored — never committed).
Template is created by the bootstrap script.
