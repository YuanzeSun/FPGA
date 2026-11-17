@echo off
powershell.exe -NoLogo -NoProfile -File "%~dp0scripts\start_hd.ps1" -Mode 1080p45
if errorlevel 1 pause
