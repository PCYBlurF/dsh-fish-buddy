@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bin\stop-fish.ps1"
exit /b %ERRORLEVEL%
