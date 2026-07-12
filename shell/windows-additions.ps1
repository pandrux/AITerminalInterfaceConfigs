# windows-additions.ps1
# Dot-sourced from $PROFILE - Windows counterpart to shell/wsl-additions.sh
# Keep this clean: aliases, functions, and environment only.

# Resolve repo root from this script's location
$WindowsAdditionsDir = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $WindowsAdditionsDir

# -----------------------------------------------------------------------------
# AI pane tinting — Windows counterpart of the wrappers in wsl-additions.sh
# Shifts the WezTerm pane background while an AI CLI runs, resets on exit:
#   Claude → dark wine   Codex → deep purple   Gemini → dark navy
# OSC 11 sets the pane background, OSC 111 resets. Only tints interactive
# sessions (no redirected stdin/stdout), so piped/one-shot use is unaffected.
# -----------------------------------------------------------------------------

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
        if ($interactive) { [Console]::Write("$esc]111$bel") }
    }
}

function claude { _Invoke-AiTinted -Color '#370617' -Name 'claude' -CliArgs $args }
function codex  { _Invoke-AiTinted -Color '#240046' -Name 'codex'  -CliArgs $args }
function gemini { _Invoke-AiTinted -Color '#001524' -Name 'gemini' -CliArgs $args }

# Recovery if a pane ever gets stuck tinted
function untint { [Console]::Write("$([char]27)]111$([char]7)") }

# -----------------------------------------------------------------------------
# AI CLI shortcuts
# -----------------------------------------------------------------------------

function update-ai-win {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$RepoRoot\scripts\update-windows.ps1" @args
}
