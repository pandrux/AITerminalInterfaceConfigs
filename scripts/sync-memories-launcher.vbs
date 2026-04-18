' sync-memories-launcher.vbs
' Silent launcher for sync-memories.ps1. Invoked by the
' AIPartnerMemorySync scheduled task via wscript.exe, which (unlike
' powershell.exe) is a GUI-subsystem process, so no console window
' ever appears even momentarily.
'
' The script is self-locating: it runs sync-memories.ps1 from its
' own directory, so no hardcoded paths.

Set objShell = CreateObject("WScript.Shell")
Set fso      = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript  = scriptDir & "\sync-memories.ps1"

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """"

' Run window style 0 = hidden; wait = False (fire and forget)
objShell.Run cmd, 0, False
