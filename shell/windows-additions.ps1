# windows-additions.ps1
# Dot-sourced from $PROFILE - Windows counterpart to shell/wsl-additions.sh
# Keep this clean: aliases, functions, and environment only.

# Resolve repo root from this script's location
$WindowsAdditionsDir = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $WindowsAdditionsDir

# -----------------------------------------------------------------------------
# AI pane tinting — Windows counterpart of the wrappers in wsl-additions.sh
# Shifts the WezTerm pane background while an AI CLI runs, resets on exit:
#   Codex → deep purple   Gemini → dark navy
#   Claude → by launch directory (see $AiZoneColors). Deep red is reserved
#   for <AI root>\ProdEvents so a red pane always means production work.
# OSC 11 sets the pane background. ConPTY (conhost) swallows OSC 111
# (reset-background) before it reaches WezTerm, so "reset" re-sets the
# scheme's own background via OSC 11 instead. Only tints interactive
# sessions (no redirected stdin/stdout), so piped/one-shot use is unaffected.
# -----------------------------------------------------------------------------

# Must match config.color_scheme in wezterm/wezterm.lua (AdventureTime background)
$AiTintResetColor = '#1f1d45'

# Claude's tint follows the workspace it was launched from. Zones are the
# event/project folders under the AI root this repo lives in (D:\AI on the
# desktops, C:\AI on the laptop), so no drive letter is assumed. A zone matches
# its root or anything beneath it (case-insensitive, either slash style). Keep
# in sync with _ai_zone_color in wsl-additions.sh.
$AiRoot = Split-Path -Parent (Split-Path -Parent $RepoRoot)
$AiZoneColors = [ordered]@{
    'ProdEvents' = '#370617'   # deep red   - production incidents (red = prod, only)
    'LabEvents'  = '#0b3a3a'   # dark teal  - lab investigations
    'Projects'   = '#0b2e1a'   # dark green - ongoing initiatives
}
$AiZoneFallbackColor = '#2f2f2f'   # slate      - anywhere else

function _Get-AiZoneColor {
    param([string]$Path)
    $p = ($Path -replace '/', '\').TrimEnd('\')
    foreach ($zone in $AiZoneColors.Keys) {
        $root = Join-Path $AiRoot $zone
        if ($p -eq $root -or $p.StartsWith("$root\", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $AiZoneColors[$zone]
        }
    }
    return $AiZoneFallbackColor
}

function _Invoke-AiTinted {
    param(
        [string]$Color,
        [string]$Name,
        [string[]]$CliArgs
    )
    # Functions below shadow the real executables; resolve the binary explicitly
    $app = Get-Command $Name -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $app) {
        Write-Error "'$Name' not found on PATH"
        return
    }
    $esc = [char]27; $bel = [char]7
    $interactive = -not ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected)
    if ($interactive) { [Console]::Write("$esc]11;$Color$bel") }
    try {
        & $app @CliArgs
    }
    finally {
        if ($interactive) { [Console]::Write("$esc]11;$AiTintResetColor$bel") }
    }
}

function claude { _Invoke-AiTinted -Color (_Get-AiZoneColor $PWD.ProviderPath) -Name 'claude' -CliArgs $args }
function codex  { _Invoke-AiTinted -Color '#240046' -Name 'codex'  -CliArgs $args }
function gemini { _Invoke-AiTinted -Color '#001524' -Name 'gemini' -CliArgs $args }

# Recovery if a pane ever gets stuck tinted
function untint { [Console]::Write("$([char]27)]11;$AiTintResetColor$([char]7)") }

# -----------------------------------------------------------------------------
# AI CLI shortcuts
# -----------------------------------------------------------------------------

function update-ai-win {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\update-windows.ps1" @args
}

# Reconcile every repo under the AI root with origin/main.
# See scripts/README-ai-sync.md.
function ai-sync {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\ai-sync.ps1" @args
}

# Instantiate the AI-to-AI mail structure in a project (default: cwd).
# Usage: init-ai-mail [-Path <projectRoot>] [-Agents claude,codex,...]
function init-ai-mail {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\init-ai-mail.ps1" @args
}
