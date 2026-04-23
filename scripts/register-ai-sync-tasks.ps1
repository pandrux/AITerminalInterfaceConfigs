<#
.SYNOPSIS
    Registers Windows Scheduled Tasks that invoke ai-sync.ps1 on a nightly
    and at-logon cadence.

.DESCRIPTION
    Creates two scheduled tasks under the current user, both of which run the
    sibling ai-sync.ps1 script:

      - "AI Sync - End of Day"  : daily at 22:00
      - "AI Sync - Logon"       : at user logon

    Running this script again is safe — it will overwrite the existing tasks
    with the current configuration.

    Output from the scheduled tasks is written to %LOCALAPPDATA%\ai-sync.log.

.PARAMETER NightlyTime
    Time for the nightly task, HH:mm (24h). Default: 22:00.

.EXAMPLE
    .\register-ai-sync-tasks.ps1
    Register both tasks with defaults.

.EXAMPLE
    .\register-ai-sync-tasks.ps1 -NightlyTime 23:30
    Register with the nightly task at 11:30pm.

.NOTES
    Requires elevation (scheduled tasks registration).
    Uninstall:
        Unregister-ScheduledTask -TaskName 'AI Sync - End of Day' -Confirm:$false
        Unregister-ScheduledTask -TaskName 'AI Sync - Logon'      -Confirm:$false
#>
[CmdletBinding()]
param(
    [string]$NightlyTime = '22:00'
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$syncScript = Join-Path $scriptDir 'ai-sync.ps1'
if (-not (Test-Path $syncScript)) {
    throw "ai-sync.ps1 not found at $syncScript"
}

$logPath = Join-Path $env:LOCALAPPDATA 'ai-sync.log'

# Wrap the sync script with logging — the scheduled task runs this command
$arguments = @(
    '-NoProfile'
    '-ExecutionPolicy','Bypass'
    '-File',"`"$syncScript`""
) -join ' '

# Build action — pipe output to the log file with timestamp separator
$commandLine = "powershell.exe $arguments *>> `"$logPath`""
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c $commandLine"

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

# Nightly task
$nightlyTrigger = New-ScheduledTaskTrigger -Daily -At $NightlyTime
Register-ScheduledTask `
    -TaskName 'AI Sync - End of Day' `
    -Description 'Reconciles local AI repos with origin at end of day' `
    -Trigger $nightlyTrigger `
    -Action $action `
    -Principal $principal `
    -Settings $settings `
    -Force | Out-Null
Write-Host "Registered: 'AI Sync - End of Day' at $NightlyTime daily"

# Logon task
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logonTrigger.Delay = 'PT2M'   # 2-minute delay to let the network come up
Register-ScheduledTask `
    -TaskName 'AI Sync - Logon' `
    -Description 'Reconciles local AI repos with origin at user logon' `
    -Trigger $logonTrigger `
    -Action $action `
    -Principal $principal `
    -Settings $settings `
    -Force | Out-Null
Write-Host "Registered: 'AI Sync - Logon' at user logon (+2min delay)"

Write-Host "`nLog output: $logPath"
Write-Host "`nTo run manually: powershell $syncScript"
Write-Host "To suggest adding a shell alias, see scripts\README-ai-sync.md"
