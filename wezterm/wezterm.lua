local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- =============================================================================
-- wezterm.lua — Tom's AI Workbench Terminal Config
-- =============================================================================
-- Repo: github.com/pandrux/AITerminalInterfaceConfigs
--
-- LEADER KEY : CTRL+SPACE  (WezTerm layer)
-- TMUX PREFIX: CTRL+A      (tmux layer inside WSL2 — no conflict)
--
-- WORKSPACES
--   Leader + w        : fuzzy workspace picker
--   Leader + SHIFT+W  : create/name a new workspace
--   Leader + 1        : ai-workbench
--   Leader + 2        : work-ptc
--   Leader + 3        : work-homelab
--   Leader + 4        : personal-dev
--
-- PANE MANAGEMENT
--   ALT+SHIFT+H/V     : split right / split down (leaderless, high-frequency)
--   ALT+SHIFT+Arrows  : navigate panes
--   Leader + h/j/k/l  : navigate panes (vim-style)
--   Leader + H/J/K/L  : resize pane
--   Leader + z        : zoom/unzoom pane
--   Leader + SPACE    : pane select overlay
--   Leader + x        : close pane
--   Leader + .        : rename pane  ("Claude — log analysis", etc.)
--
-- TABS
--   Leader + c        : new tab
--   Leader + n/p      : next / prev tab
--   Leader + ,        : rename tab
--   ALT + 1-5         : jump to tab by number
--
-- AI WORKBENCH
--   Leader + a        : spawn 4-pane AI layout in current workspace
--                       [ Claude Code | Codex CLI  ]
--                       [ Gemini CLI  | Scratch    ]
-- =============================================================================

-- =============================================================================
-- LEADER
-- CTRL+SPACE for WezTerm. CTRL+A is left free for tmux inside WSL2.
-- =============================================================================
config.leader = { key = 'Space', mods = 'CTRL', timeout_milliseconds = 1000 }

-- =============================================================================
-- APPEARANCE
-- =============================================================================
config.color_scheme = 'AdventureTime'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 11
config.window_background_opacity = 0.95

config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32

-- =============================================================================
-- WINDOW
-- =============================================================================
config.initial_cols = 220
config.initial_rows = 55
config.window_padding = { left = 6, right = 6, top = 6, bottom = 0 }

-- RDP-friendly rendering — reduces flicker on remote sessions
config.max_fps = 60
config.animation_fps = 1
config.cursor_blink_rate = 0

-- =============================================================================
-- SCROLLBACK
-- AI responses can be long — keep plenty
-- =============================================================================
config.scrollback_lines = 10000

-- =============================================================================
-- MISC
-- =============================================================================
config.audible_bell = 'Disabled'
config.check_for_updates = false
config.copy_on_select = true

-- =============================================================================
-- RIGHT STATUS — workspace name + pane count
-- =============================================================================
wezterm.on('update-right-status', function(window, _)
    local workspace = window:active_workspace()
    local pane_count = #window:active_tab():panes()
    window:set_right_status(wezterm.format {
        { Foreground = { AnsiColor = 'Fuchsia' } },
        { Text = ' [' .. workspace .. ']  ' .. pane_count .. ' panes ' },
    })
end)

-- =============================================================================
-- WSL2 HELPER
-- Change "Ubuntu" to your WSL distro name if different.
-- Check yours with: wsl -l -v
-- =============================================================================
local WSL_DISTRO = 'Ubuntu'

local function wsl_pane(pane, direction, size)
    return pane:split {
        direction = direction,
        size = size,
        args = { 'wsl.exe', '-d', WSL_DISTRO, '--', 'bash', '-l' },
    }
end

-- =============================================================================
-- AI WORKBENCH LAUNCHER
-- Leader + a  →  new tab with 4-pane layout:
--   [ Claude Code | Codex CLI  ]
--   [ Gemini CLI  | Scratch    ]
-- Panes are labeled so Leader+SPACE pane-select overlay is readable.
-- =============================================================================
local function launch_ai_workbench(window)
    local tab, claude_pane, _ = window:mux_window():spawn_tab {}
    tab:set_title('ai-workbench')

    -- Top-left: Claude Code (runs in default shell / PowerShell)
    claude_pane:set_title('Claude')
    claude_pane:send_text('claude\n')

    -- Top-right: Codex CLI (WSL2)
    local codex_pane = wsl_pane(claude_pane, 'Right', 0.5)
    codex_pane:set_title('Codex')
    codex_pane:send_text('codex\n')

    -- Bottom-left: Gemini CLI (WSL2)
    local gemini_pane = wsl_pane(claude_pane, 'Bottom', 0.5)
    gemini_pane:set_title('Gemini')
    gemini_pane:send_text('gemini\n')

    -- Bottom-right: Scratch shell (WSL2 — stage input, run scripts)
    local scratch_pane = wsl_pane(codex_pane, 'Bottom', 0.5)
    scratch_pane:set_title('Scratch')
    scratch_pane:send_text('echo "=== Scratch — stage input here ==="\n')

    -- Return focus to Claude pane
    claude_pane:activate()
end

-- =============================================================================
-- KEY BINDINGS
-- =============================================================================
config.keys = {

    -- -------------------------------------------------------------------------
    -- SHIFT+ENTER passthrough for Claude Code
    -- Sends proper escape sequence so Claude sees Shift+Enter, not plain Enter
    -- -------------------------------------------------------------------------
    { key = 'Enter', mods = 'SHIFT', action = act.SendString '\x1b[13;2u' },

    -- -------------------------------------------------------------------------
    -- SPLITS — leaderless, high-frequency
    -- -------------------------------------------------------------------------
    { key = 'h', mods = 'ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'v', mods = 'ALT|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

    -- -------------------------------------------------------------------------
    -- PANE NAVIGATION — leaderless
    -- -------------------------------------------------------------------------
    { key = 'LeftArrow',  mods = 'ALT|SHIFT', action = act.ActivatePaneDirection 'Left'  },
    { key = 'DownArrow',  mods = 'ALT|SHIFT', action = act.ActivatePaneDirection 'Down'  },
    { key = 'UpArrow',    mods = 'ALT|SHIFT', action = act.ActivatePaneDirection 'Up'    },
    { key = 'RightArrow', mods = 'ALT|SHIFT', action = act.ActivatePaneDirection 'Right' },

    -- -------------------------------------------------------------------------
    -- SPLITS — leader variants
    -- -------------------------------------------------------------------------
    { key = "'", mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = '5', mods = 'LEADER|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

    -- -------------------------------------------------------------------------
    -- PANE NAVIGATION — leader + vim keys
    -- -------------------------------------------------------------------------
    { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left'  },
    { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down'  },
    { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up'    },
    { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },

    -- -------------------------------------------------------------------------
    -- PANE RESIZE — leader + shifted vim keys
    -- -------------------------------------------------------------------------
    { key = 'H', mods = 'LEADER', action = act.AdjustPaneSize { 'Left',  5 } },
    { key = 'J', mods = 'LEADER', action = act.AdjustPaneSize { 'Down',  3 } },
    { key = 'K', mods = 'LEADER', action = act.AdjustPaneSize { 'Up',    3 } },
    { key = 'L', mods = 'LEADER', action = act.AdjustPaneSize { 'Right', 5 } },

    -- -------------------------------------------------------------------------
    -- PANE MANAGEMENT
    -- -------------------------------------------------------------------------
    { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState              },
    { key = ' ', mods = 'LEADER', action = act.PaneSelect { mode = 'Activate' } },
    { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },

    -- Rename pane — label AI sessions: "Claude — log analysis", "Codex — ptc", etc.
    {
        key = '.', mods = 'LEADER',
        action = act.PromptInputLine {
            description = 'Rename pane:',
            action = wezterm.action_callback(function(_, pane, line)
                if line then pane:set_title(line) end
            end),
        },
    },

    -- -------------------------------------------------------------------------
    -- TABS
    -- -------------------------------------------------------------------------
    { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1)       },
    { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1)      },

    -- Jump to tab by number (ALT+number — no leader needed)
    { key = '1', mods = 'ALT', action = act.ActivateTab(0) },
    { key = '2', mods = 'ALT', action = act.ActivateTab(1) },
    { key = '3', mods = 'ALT', action = act.ActivateTab(2) },
    { key = '4', mods = 'ALT', action = act.ActivateTab(3) },
    { key = '5', mods = 'ALT', action = act.ActivateTab(4) },

    -- Rename tab
    {
        key = ',', mods = 'LEADER',
        action = act.PromptInputLine {
            description = 'Rename tab:',
            action = wezterm.action_callback(function(window, _, line)
                if line then window:active_tab():set_title(line) end
            end),
        },
    },

    -- -------------------------------------------------------------------------
    -- WORKSPACES
    -- -------------------------------------------------------------------------

    -- Fuzzy picker — see all workspaces, switch instantly
    { key = 'w', mods = 'LEADER', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },

    -- Create or switch to a named workspace
    {
        key = 'w', mods = 'LEADER|SHIFT',
        action = act.PromptInputLine {
            description = 'New workspace name:',
            action = wezterm.action_callback(function(window, pane, line)
                if line and #line > 0 then
                    window:perform_action(act.SwitchToWorkspace { name = line }, pane)
                end
            end),
        },
    },

    -- Quick-jump to named workspaces (Leader + number)
    { key = '1', mods = 'LEADER', action = act.SwitchToWorkspace { name = 'ai-workbench' } },
    { key = '2', mods = 'LEADER', action = act.SwitchToWorkspace { name = 'work-ptc'     } },
    { key = '3', mods = 'LEADER', action = act.SwitchToWorkspace { name = 'work-homelab' } },
    { key = '4', mods = 'LEADER', action = act.SwitchToWorkspace { name = 'personal-dev' } },

    -- -------------------------------------------------------------------------
    -- AI WORKBENCH LAUNCHER
    -- -------------------------------------------------------------------------
    {
        key = 'a', mods = 'LEADER',
        action = wezterm.action_callback(function(window, _)
            launch_ai_workbench(window)
        end),
    },

    -- -------------------------------------------------------------------------
    -- COPY / PASTE
    -- -------------------------------------------------------------------------
    { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard'    },
    { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },

    -- -------------------------------------------------------------------------
    -- SEARCH SCROLLBACK — dig through AI output
    -- -------------------------------------------------------------------------
    { key = 'f', mods = 'CTRL|SHIFT', action = act.Search { CaseInSensitiveString = '' } },

    -- -------------------------------------------------------------------------
    -- FONT SIZE
    -- -------------------------------------------------------------------------
    { key = '=', mods = 'CTRL', action = act.IncreaseFontSize },
    { key = '-', mods = 'CTRL', action = act.DecreaseFontSize },
    { key = '0', mods = 'CTRL', action = act.ResetFontSize    },
}

-- =============================================================================
-- MOUSE — right-click pastes (convenient on touchpad / RDP)
-- =============================================================================
config.mouse_bindings = {
    {
        event  = { Down = { streak = 1, button = 'Right' } },
        mods   = 'NONE',
        action = act.PasteFrom 'Clipboard',
    },
}

-- =============================================================================
return config
