@echo off
title Windows Autopilot Collector (EN)

:: Run PowerShell script with Bypass policy
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AP_en.ps1"

if %ERRORLEVEL% neq 0 (
    echo.
    echo  [!] Execution failed.
    pause
)
