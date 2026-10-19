@echo off
chcp 65001 >nul
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "DshFishBuddy" /f >nul 2>&1
echo 已关闭开机自启
pause
