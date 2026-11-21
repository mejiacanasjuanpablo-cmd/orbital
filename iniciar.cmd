@echo off
rem Doble clic para abrir el panel (por cable USB; en la edicion solo Wi-Fi, por Wi-Fi), en su propia ventana.
rem Para ver los mensajes del servidor en una consola: powershell -ExecutionPolicy Bypass -File iniciar.ps1
if exist "%~dp0Panel del PC.exe" start "" "%~dp0Panel del PC.exe" %* & exit /b
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0ventana.ps1" %*
