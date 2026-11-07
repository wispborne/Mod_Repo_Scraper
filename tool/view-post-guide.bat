@echo off
rem Shows the Post guide checks page from a fresh checkout of this repo.
rem Needs only the Dart SDK (3.12 or newer): no config file, no data and no LLM.
rem With no results of its own, the page reads the copy the scraper publishes
rem to github.com/wispborne/StarsectorModRepo.
rem The viewer runs read-only (--no-manager), so it cannot start jobs.
cd /d "%~dp0.."
rem A free port, picked by Windows, so another program on the same port
rem cannot stop the viewer starting.
for /f %%p in ('powershell -NoProfile -Command "$l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0); $l.Start(); $l.LocalEndpoint.Port; $l.Stop()"') do set PORT=%%p
if not defined PORT set PORT=8090
where dart >nul 2>nul || (
  echo Error: this needs the Dart SDK on the PATH.
  echo Get it from https://dart.dev/get-dart
  pause
  exit /b 1
)
echo Installing packages...
call dart pub get || (
  echo Error: "dart pub get" failed. This needs Dart 3.12 or newer.
  pause
  exit /b 1
)
rem Opens the page once the server has had time to start.
start "" /b powershell -NoProfile -Command "Start-Sleep -Seconds 8; Start-Process 'http://127.0.0.1:%PORT%/#/post-guide'"
echo Starting the viewer at http://127.0.0.1:%PORT%/#/post-guide
echo Close this window to stop it.
dart run bin/viewer_server.dart --port %PORT% --no-manager
set code=%errorlevel%
rem Keep the window open when started by double-click.
echo %cmdcmdline% | find /i "/c" >nul && pause
exit /b %code%
