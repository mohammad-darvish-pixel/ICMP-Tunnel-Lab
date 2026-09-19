@echo off
title ICMP Tunnel Lab — Blue Team Training
color 0A

echo.
echo  =========================================================
echo    ICMP Tunnel Lab — Blue Team Training
echo    Starting launcher.ps1 ...
echo  =========================================================
echo.

:: Run the PowerShell launcher with bypass policy
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  [ERROR] Launcher failed.
    echo  If UAC blocked it, right-click start_lab.bat and choose
    echo  "Run as administrator", then try again.
    echo.
    pause
)