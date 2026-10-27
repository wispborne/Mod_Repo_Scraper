@echo off
rem Runs pull-prod-data.ps1. Any options are passed on, e.g. pull-prod-data.bat -DryRun
where pwsh >nul 2>nul || (
  echo Error: this needs PowerShell 7 ^(pwsh^). Install it with: winget install Microsoft.PowerShell
  pause
  exit /b 1
)
pwsh -NoProfile -File "%~dp0pull-prod-data.ps1" %*
set code=%errorlevel%
rem Keep the window open when started by double-click.
echo %cmdcmdline% | find /i "/c" >nul && pause
exit /b %code%
