# AITerminalInterfaceConfigs

Personal terminal configuration — WezTerm, WSL2, Zellij, and AI CLI tooling.
Designed for consistent use across Windows 11 machines.

## Machines

| Machine | Role | Notes |
|---|---|---|
| Work Desktop | PTC/ATCS engineering, primary AI work | RDP target, sessions persist |
| Home Desktop | Mixed work + homelab + personal | WSL2 hub |
| Laptop | Personal dev only | Focused, lighter setup |

## Prerequisites

### WSL2 (one-time setup per machine)

Open PowerShell as Administrator:

```powershell
wsl --install
# Reboot, then:
wsl --install -d Ubuntu
```

On first launch, create your Linux username and password.

### WezTerm

Install from [wezfurlong.org/wezterm](https://wezfurlong.org/wezterm/) or:

```powershell
winget install wez.wezterm
```

## Quick Start

### On a new Windows machine

```powershell
git clone https://github.com/pandrux/AITerminalInterfaceConfigs.git
cd AITerminalInterfaceConfigs
.\scripts\bootstrap-windows.ps1
```

### WSL only (no Windows bootstrap needed)

```bash
./scripts/bootstrap-wsl.sh
```

### Launch the AI Workbench

After bootstrap, open a WSL terminal and type:

```bash
ai
```

This opens Zellij with a 4-pane layout, all three AI CLIs running:

```
+---------------------+---------------------+
|                     |                     |
|    Claude Code      |    Codex CLI        |
|                     |                     |
+---------------------+---------------------+
|                     |                     |
|    Gemini CLI       |    Scratch / Shell  |
|                     |                     |
+---------------------+---------------------+
```

Sessions persist — detach with `Ctrl+O, d` and reattach with `zellij attach`.
Ideal for RDP sessions that stay alive.

## What the Bootstrap Installs

### WSL side (`bootstrap-wsl.sh`)

1. **System packages**: pip3, Zellij (snap), bubblewrap (Codex sandbox),
   Starship, Pandoc, texlive, LibreOffice, Python venv with `python-pptx`
2. **Node.js** v22 (via nvm)
3. **AI CLI tools**: Claude Code, Codex CLI, Gemini CLI (npm, global)
4. **Shell config**: links `wsl-additions.sh` into `.bashrc`
5. **Zellij config + layouts**: symlinks `config.kdl` and layouts into `~/.config/zellij/`
6. **API keys template**: creates `~/.config/ai-keys.sh` (gitignored)
7. **Claude Code statusline**: symlinks `claude/statusline.py` into `~/.claude/`
   and registers it in `~/.claude/settings.json`

### Windows side (`bootstrap-windows.ps1`)

1. Symlinks `wezterm.lua` into WezTerm config location
2. Checks for WezTerm
3. Checks for CLI tools: Claude Code, Codex CLI, Gemini CLI, Node.js, Git
4. Symlinks `claude/statusline.py` into `~/.claude/` and registers it in
   `~/.claude/settings.json`
5. Optionally triggers WSL bootstrap (pass `-SkipWSL` to skip)

## Key Bindings

### WezTerm

Leader key: `CTRL+SPACE` (release, then next key)

| Key | Action |
|---|---|
| `Leader + a` | Launch AI Workbench (4-pane layout) |
| `Leader + w` | Workspace picker |
| `Leader + 1-4` | Switch to named workspace |
| `Leader + \|` | Split pane vertical |
| `Leader + -` | Split pane horizontal |
| `Leader + h/j/k/l` | Navigate panes |
| `Leader + H/J/K/L` | Resize pane |
| `Leader + z` | Zoom/unzoom pane |
| `Leader + t` | New tab |
| `Leader + ,` | Rename tab |

### Zellij (inside WSL)

| Key | Action |
|---|---|
| `Alt + Arrow keys` | Navigate panes |
| `Ctrl+P` then `d/r` | Split down / right |
| `Ctrl+P` then `c` | Rename pane |
| `Ctrl+T` then `n` | New tab |
| `Ctrl+T` then `r` | Rename tab |
| `Ctrl+O` then `d` | Detach session |
| `Ctrl+Q` | Quit Zellij |

Reattach a detached session: `zellij attach`

## Shell Functions (WSL)

```bash
# Launch the AI workbench
ai

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
AITerminalInterfaceConfigs/
+-- wezterm/
|   +-- wezterm.lua              # Main WezTerm config (Windows side)
+-- shell/
|   +-- wsl-additions.sh         # Sourced by .bashrc
|   +-- starship.toml            # Starship prompt config
+-- scripts/
|   +-- bootstrap-windows.ps1    # Windows setup
|   +-- bootstrap-wsl.sh         # WSL setup
|   +-- ai.sh                    # AI workbench launcher
|   +-- update.sh                # Update all tools
+-- zellij/
|   +-- config.kdl               # Zellij base config (theme, defaults)
|   +-- layouts/
|       +-- ai-workbench.kdl     # Two-tab AI layout
+-- claude/
|   +-- statusline.py            # Claude Code statusline (symlinked into ~/.claude/)
+-- .claude/
|   +-- settings.json            # Repo-scoped Claude Code permissions
+-- skills/                      # Reusable AI workflows (placeholder)
+-- docs/                        # Session notes, setup transcripts
+-- .gitattributes
+-- .gitignore
+-- README.md
```

## Customization Per Machine

Create `~/.config/local-overrides.sh` (gitignored) for machine-specific paths,
aliases, or environment variables that shouldn't be shared across machines.

## API Keys

Stored in `~/.config/ai-keys.sh` (gitignored — never committed).
Template is created by the bootstrap script. Most AI CLIs authenticate via
browser-based OAuth, so API keys are only needed for non-interactive/scripted use.
