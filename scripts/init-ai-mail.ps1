# init-ai-mail.ps1 - instantiate the AI-to-AI mail structure in a project.
#
# Creates the mailbox layout used for async agent coordination (see
# templates/mail/README.md for the protocol; PTCRailroadSim is the reference
# implementation):
#
#   mail/
#     README.md            <- protocol doc, generated from the template
#     <agent>/             <- one inbox per agent
#       archive/.gitkeep   <- processed messages land here
#
# Also wires each agent's instruction file (CLAUDE.md, AGENTS.md, GEMINI.md)
# in the project root: creates it with the mail section if missing, appends
# the section at the bottom if the file exists without one.
#
# Idempotent: existing folders and an existing mail/README.md are left alone,
# so re-running against a live mailbox never destroys messages; instruction
# files that already reference mail/README.md are left untouched.
#
# Usage:
#   .\init-ai-mail.ps1                          # mail/ in current directory, claude + codex
#   .\init-ai-mail.ps1 -Path D:\AI\Projects\X   # explicit project root
#   .\init-ai-mail.ps1 -Agents claude,codex,gemini

param(
    [string]$Path = ".",
    [string[]]$Agents = @("claude", "codex")
)

$ErrorActionPreference = "Stop"
$RepoRoot = $PSScriptRoot | Split-Path -Parent

if (-not (Test-Path $Path -PathType Container)) {
    Write-Host "ERROR: '$Path' is not an existing directory." -ForegroundColor Red
    exit 1
}
$ProjectRoot = (Resolve-Path $Path).Path
$MailRoot = Join-Path $ProjectRoot "mail"

Write-Host ""
Write-Host "=== AI mail init: $MailRoot ===" -ForegroundColor Cyan

# --- Folder structure -------------------------------------------------------
foreach ($agent in $Agents) {
    $archiveDir = Join-Path $MailRoot "$agent\archive"
    if (Test-Path $archiveDir) {
        Write-Host "  [OK] mail/$agent/archive already exists" -ForegroundColor Green
    } else {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        Write-Host "  Created mail/$agent/archive" -ForegroundColor Green
    }
    # .gitkeep so the empty archive survives a git clone
    $gitkeep = Join-Path $archiveDir ".gitkeep"
    if (-not (Test-Path $gitkeep)) {
        New-Item -ItemType File -Path $gitkeep | Out-Null
    }
}

# --- Protocol README from template ------------------------------------------
$ReadmeTarget = Join-Path $MailRoot "README.md"
$TemplateSource = Join-Path $RepoRoot "templates\mail\README.md"

if (Test-Path $ReadmeTarget) {
    Write-Host "  [OK] mail/README.md already exists -- left untouched" -ForegroundColor Green
} elseif (-not (Test-Path $TemplateSource)) {
    Write-Host "  WARN: template not found at $TemplateSource; skipping README." -ForegroundColor Yellow
} else {
    # Fill the {{AGENT_LAYOUT}} placeholder with one bullet per agent so the
    # doc matches the folders actually created. Em-dash built from its code
    # point: this file stays pure ASCII so PS 5.1 parses it under any codepage.
    $emDash = [char]0x2014
    $layoutLines = foreach ($agent in $Agents) {
        $proper = $agent.Substring(0,1).ToUpper() + $agent.Substring(1)
        "- ``mail/$agent/`` $emDash **$proper's inbox.**"
    }
    $template = Get-Content $TemplateSource -Raw -Encoding UTF8
    $rendered = $template -replace '\{\{AGENT_LAYOUT\}\}', ($layoutLines -join "`n")
    # UTF8 w/o BOM keeps the file byte-identical with what Linux-side tools write
    [System.IO.File]::WriteAllText($ReadmeTarget, $rendered, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "  Created mail/README.md from template" -ForegroundColor Green
}

# --- Agent instruction files --------------------------------------------------
# Each agent's CLI auto-loads an instruction file from the project root; wire
# the mail convention into it. Create the file if the project doesn't have one
# yet; append at the bottom if it does. A file that already references
# mail/README.md is assumed wired and left alone.
$InstructionFiles = @{
    claude = "CLAUDE.md"
    codex  = "AGENTS.md"
    gemini = "GEMINI.md"
}
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$ProjectName = Split-Path $ProjectRoot -Leaf

Write-Host ""
foreach ($agent in $Agents) {
    if (-not $InstructionFiles.ContainsKey($agent)) {
        Write-Host "  WARN: no instruction file known for agent '$agent'; wire its docs manually." -ForegroundColor Yellow
        continue
    }
    $fileName = $InstructionFiles[$agent]
    $filePath = Join-Path $ProjectRoot $fileName

    $blurb = @"
## AI mail

- Check ``mail/$agent/`` for messages; protocol in ``mail/README.md``.
  Archive messages after acting on them. Send by writing into the
  recipient's folder under ``mail/``.
"@

    $existing = $null
    if (Test-Path $filePath) {
        $existing = Get-Content $filePath -Raw -Encoding UTF8
    }

    if ($existing -and ($existing -match 'mail/README\.md')) {
        Write-Host "  [OK] $fileName already references mail/README.md -- left untouched" -ForegroundColor Green
    } elseif ($existing) {
        $sep = if ($existing.EndsWith("`n")) { "`n" } else { "`n`n" }
        [System.IO.File]::AppendAllText($filePath, "$sep$blurb`n", $Utf8NoBom)
        Write-Host "  Appended mail section to existing $fileName" -ForegroundColor Green
    } else {
        [System.IO.File]::WriteAllText($filePath, "# $ProjectName`n`n$blurb`n", $Utf8NoBom)
        Write-Host "  Created $fileName with mail section" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Write-Host "  (Claude Code also gets unread-inbox notification automatically at"
Write-Host "  session start via the session-start-mail hook, if bootstrapped.)"
Write-Host ""
