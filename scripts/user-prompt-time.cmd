@echo off
:: user-prompt-time.cmd - invoked by Claude Code UserPromptSubmit hook.
:: Emits the current wall-clock time so the model has fresh time-of-day
:: awareness on every prompt. Plain-text stdout is added to context as-is.
::
:: Batch rather than PowerShell on purpose: powershell.exe cold start on
:: AV-heavy work machines was hitting the 5s hook timeout on every prompt.
:: cmd.exe plus tzutil finish in well under 100ms. Bash/WSL twin:
:: user-prompt-time.sh.
for /f "delims=" %%z in ('tzutil /g') do set "TZNAME=%%z"
echo Current local time: %DATE% %TIME% (%TZNAME%)
