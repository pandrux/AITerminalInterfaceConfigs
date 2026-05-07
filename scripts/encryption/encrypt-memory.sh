#!/usr/bin/env bash
# encrypt-memory.sh - WSL SessionEnd hook wrapper.
#
# Delegates to the Windows-side encrypt-memory.ps1 via powershell.exe interop.
# See decrypt-memory.sh for rationale.

WIN_SCRIPT='D:\AI\Projects\AITerminalInterfaceConfigs\scripts\encryption\encrypt-memory.ps1'

exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT"
