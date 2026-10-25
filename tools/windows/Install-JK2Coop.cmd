@echo off
rem Double-click to install the Jedi Outcast co-op test build on this PC.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-JK2Coop.ps1" %*
echo.
pause
