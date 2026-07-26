@echo off
REM Manual trigger - opens the review page for whatever is in the media inbox.
powershell -ExecutionPolicy Bypass -File "%~dp0photo-intake.ps1"
if errorlevel 2 (
  echo.
  echo Nothing in the inbox right now.
  timeout /t 4 >nul
)
