@echo off
rem PentagonSetup launcher - double-click, or run with switches: pentagon-setup.bat -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pentagon-setup.ps1" %*
echo.
pause
