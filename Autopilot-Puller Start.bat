@echo off
title Windows Autopilot Collector (EN)
echo Starting English Autopilot script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AP_en.ps1"
echo.
echo Script completed. Press any key to exit.
pause >nul
