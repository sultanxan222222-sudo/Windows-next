@echo off
setlocal
title Windows Next

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SCRIPT=%~dp0src\WindowsNext.ps1"

if not exist "%PS%" (
  echo ERROR: Windows PowerShell 5.1 was not found.
  pause
  exit /b 1
)
if not exist "%SCRIPT%" (
  echo ERROR: Windows Next application files are missing.
  pause
  exit /b 1
)

start "" "%PS%" -NoLogo -NoProfile -STA -WindowStyle Hidden -File "%SCRIPT%"
exit /b 0
