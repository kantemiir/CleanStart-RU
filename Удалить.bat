@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0data\uninstall.ps1" -GameDir "%~1"
echo.
pause
