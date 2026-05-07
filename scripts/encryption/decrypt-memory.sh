#!/usr/bin/env bash
# decrypt-memory.sh - WSL SessionStart hook wrapper.
#
# Delegates to the Windows-side decrypt-memory.ps1 via powershell.exe interop.
# DPAPI is Windows-only and the encrypted blob lives on NTFS, so there's no
# value in duplicating crypto on the Linux side. The hook payload arrives via
# stdin as JSON; exec preserves stdin to powershell.exe, which reads it
# normally.
#
# The Windows script's project-memory logic only fires when the cwd encodes
# to a known Windows-side memory directory (e.g. D--AI). When Claude Code is
# running in WSL with a /mnt/d/... cwd, the project-memory branch is a no-op
# -- only the ai-partner-memories private/ envelope is touched.

WIN_SCRIPT='D:\AI\Projects\AITerminalInterfaceConfigs\scripts\encryption\decrypt-memory.ps1'

exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SCRIPT"
