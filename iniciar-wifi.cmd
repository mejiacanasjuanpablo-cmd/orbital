@echo off
rem Doble clic para abrir el panel por Wi-Fi (sin cable), en su propia ventana.
rem Para ver los mensajes del servidor en una consola: powershell -ExecutionPolicy Bypass -File iniciar.ps1 -Wifi
if exist "%~dp0Panel del PC.exe" start "" "%~dp0Panel del PC.exe" -Wifi %* & exit /b
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0ventana.ps1" -Wifi %*
