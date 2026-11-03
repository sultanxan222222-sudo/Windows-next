@echo off
setlocal
title Windows Next - Hardware Inventory

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SCRIPT=%~dp0src\WindowsNext.ps1"

echo.
echo ==========================================
echo          WINDOWS NEXT - INVENTORY
echo ==========================================
echo This first-stage tool is READ ONLY.
echo It does not install drivers or change Windows.
echo.

if not exist "%PS%" (
    echo ERROR: Windows PowerShell 5.1 was not found.
    echo No system changes were made.
    pause
    exit /b 1
)

if not exist "%SCRIPT%" (
    echo ERROR: src\WindowsNext.ps1 is missing.
    echo Make sure the ZIP archive was fully extracted.
    pause
    exit /b 1
)

"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RESULT=%ERRORLEVEL%"

echo.
if not "%RESULT%"=="0" (
    echo Windows Next stopped with an error.
    echo Error details may already be copied. Return to ChatGPT and press Ctrl+V.
    echo Log folder: %%LOCALAPPDATA%%\WindowsNext\Logs
) else (
    echo Inventory finished successfully.
    echo The readable report is copied to the clipboard.
    echo Return to ChatGPT, click the message box, press Ctrl+V, then Enter.
)
echo.
pause
exit /b %RESULT%
