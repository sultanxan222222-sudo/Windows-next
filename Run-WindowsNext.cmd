@echo off
setlocal
title Windows Next — Inventory

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo Windows PowerShell 5.1 was not found.
    echo No system changes were made.
    pause
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\WindowsNext.ps1"
set "RESULT=%ERRORLEVEL%"

echo.
if not "%RESULT%"=="0" (
    echo Inventory did not finish successfully. No driver installation was attempted.
) else (
    echo Inventory finished. No driver installation was attempted.
)
pause
exit /b %RESULT%
