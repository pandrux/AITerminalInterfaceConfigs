# session-start-status.ps1 - invoked by Claude Code SessionStart hook
# Fetches origin and reports branch/drift status as additionalContext so
# Claude can proactively offer a fast-forward pull when the repo is behind.

param(
    [string]$RepoPath = "D:\AI\Projects\AITerminalInterfaceConfigs"
)

function Emit-Context($text) {
    $payload = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = $text
        }
    } | ConvertTo-Json -Depth 5 -Compress
    Write-Output $payload
}

if (-not (Test-Path $RepoPath)) {
    Emit-Context "AITerminalInterfaceConfigs not found at $RepoPath (skipping drift check)."
    exit 0
}

# Fetch silently; never let a network failure block session start.
try {
    git -C $RepoPath fetch --quiet 2>$null
} catch {
    # swallow - treat as offline
}

$status = (git -C $RepoPath status --short --branch 2>&1 | Out-String).Trim()
Emit-Context "AITerminalInterfaceConfigs ($RepoPath) status:`n$status"
