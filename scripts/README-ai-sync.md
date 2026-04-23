# ai-sync — git reconciliation across machines

One script, three triggers, one shape of behavior: keep every machine's
local repos under `D:\AI` aligned with `origin/main` so switching machines
doesn't surprise you with out-of-cycle work.

## What it does

For each git repository found under `D:\AI` that's on `main`:

1. Auto-commits uncommitted work as `auto-sync: <hostname> <timestamp>`
2. Fetches origin
3. Pushes if local is ahead
4. Fast-forwards if local is behind and clean
5. Logs and skips if branches have diverged (no auto-resolution)

Never force-pushes, never touches non-main branches, never rebases.

## Install

From an elevated PowerShell on each machine:

```powershell
cd D:\AI\Projects\AITerminalInterfaceConfigs\scripts
.\register-ai-sync-tasks.ps1
```

This registers two scheduled tasks running as your user:

- **AI Sync - End of Day** — daily at 22:00
- **AI Sync - Logon** — at logon (+ 2 min delay for network)

Output lands in `%LOCALAPPDATA%\ai-sync.log`.

## On-demand (before starting a Claude Code session)

Add a shell function or alias so you can type `ai-sync` before a new
session:

**PowerShell profile** (`$PROFILE`):

```powershell
function ai-sync {
    & "D:\AI\Projects\AITerminalInterfaceConfigs\scripts\ai-sync.ps1" @args
}
```

**Bash/zsh** (inside WSL):

```bash
alias ai-sync='pwsh.exe -NoProfile -File "/mnt/d/AI/Projects/AITerminalInterfaceConfigs/scripts/ai-sync.ps1"'
```

## Uninstall

```powershell
Unregister-ScheduledTask -TaskName 'AI Sync - End of Day' -Confirm:$false
Unregister-ScheduledTask -TaskName 'AI Sync - Logon'      -Confirm:$false
```

## Log

Each run appends to `%LOCALAPPDATA%\ai-sync.log`. Check it periodically,
especially after the first week, to verify nothing is silently diverging.

## When it won't auto-resolve

- **Branch other than main** — skipped
- **No origin/main** — skipped (new repos need their first push by hand)
- **Local and origin have diverged** — logged, not touched; run `git log`
  and resolve manually

These are rare in single-user flows but the guardrails are there on purpose.
