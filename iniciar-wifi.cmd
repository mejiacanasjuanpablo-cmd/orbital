@echo off
rem Doble clic para arrancar el panel por Wi-Fi (sin cable).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar.ps1" -Wifi %*
pause
