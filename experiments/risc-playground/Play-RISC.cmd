@echo off
powershell.exe -NoLogo -NoProfile -File "%~dp0scripts\start.ps1"
if errorlevel 1 pause
