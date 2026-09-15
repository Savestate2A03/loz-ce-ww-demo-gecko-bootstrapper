@echo off
setlocal
:: moved to a powershell script because it was basically already
:: a powershell script in its previous form lol.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
pause
exit /b %errorlevel%
