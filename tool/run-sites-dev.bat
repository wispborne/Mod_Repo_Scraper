@echo off
rem Runs the public website (http://127.0.0.1:8099/) and the results viewer
rem (http://127.0.0.1:8085/) together. Open pages reload when site\ or web\
rem changes, and both servers restart when Dart code in lib\ or bin\ changes.
rem Options are passed on, e.g. run-sites-dev.bat --site-port 8098
cd /d "%~dp0.."
where dart >nul 2>nul || (
  echo Error: this needs the Dart SDK on the PATH.
  pause
  exit /b 1
)
dart run bin/dev_servers.dart %*
set code=%errorlevel%
rem Keep the window open when started by double-click.
echo %cmdcmdline% | find /i "/c" >nul && pause
exit /b %code%
