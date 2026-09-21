# ai-sync — git reconciliation across machines

One script, three triggers, one shape of behavior: keep every machine's
local repos under the AI root aligned with `origin/main` so switching
machines doesn't surprise you with out-of-cycle work.

The AI root is the grandparent of this repo (`C:\AI` on the laptop, `D:\AI`
on the desktops). The script derives it from its own location, so nothing is
hardcoded to a drive; pass `-BaseDir` to scan somewhere else.

## What it does

For each git repository found under the AI root that's on `main`:

1. Auto-commits uncommitted work as `auto-sync: <hostname> <timestamp>`
2. Fetches origin
3. Pushes if local is ahead
4. Fast-forwards if local is behind and clean
5. Logs and skips if branches have diverged (no auto-resolution)

Never force-pushes, never touches non-main branches, never rebases.

## Install

From an elevated PowerShell on each machine:

```powershell
cd <AI root>\Projects\AITerminalInterfaceConfigs\scripts   # e.g. C:\AI\Projects\...
.\register-ai-sync-tasks.ps1
```

This registers two scheduled tasks running as your user:

- **AI Sync - End of Day** — daily at 22:00
- **AI Sync - Logon** — at logon (+ 2 min delay for network)

Output lands in `%LOCALAPPDATA%\ai-sync.log`.

## On-demand (before starting a Claude Code session)

Type `ai-sync` before a new session. Both bootstraps wire it up for you:

- **PowerShell**: `ai-sync` is defined in `shell/windows-additions.ps1`,
  which `bootstrap-windows.ps1` dot-sources from your profile.
- **Bash (inside WSL)**: `ai-sync` is defined in `shell/wsl-additions.sh`,
  which `bootstrap-wsl.sh` sources from `.bashrc`. It runs the Windows-side
  script through `powershell.exe`.

Both locate the script relative to the repo, so nothing depends on which
drive the repo lives on.

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
