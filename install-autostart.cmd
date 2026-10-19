@echo off
chcp 65001 >nul
set "APP=%~dp0"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "DshFishBuddy" /t REG_SZ /d "\"C:\Windows\System32\wscript.exe\" \"%APP%bin\fish-widget.vbs\"" /f >nul
echo 已开启开机自启：DSH 大肥鱼
pause
