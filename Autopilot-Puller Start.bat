@echo off
:: Set code page to UTF-8 for fancy characters
chcp 65001 >nul
title Windows Autopilot Collector (EN)
echo.
echo  [*] Initializing Autopilot Collector...
echo.

:: Run PowerShell with Bypass and UTF8 output
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; & '%~dp0AP_en.ps1' }"

if %ERRORLEVEL% neq 0 (
    echo.
    echo  [!] Something went wrong during execution.
    pause
)
