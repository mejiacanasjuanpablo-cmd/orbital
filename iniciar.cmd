@echo off
rem Doble clic para abrir el panel en su propia ventana. El celular entra por la red Wi-Fi de la casa.
rem Para ver los mensajes del servidor en una consola: powershell -ExecutionPolicy Bypass -File iniciar.ps1
if exist "%~dp0Orbital.exe" start "" "%~dp0Orbital.exe" %* & exit /b
rem El .exe de antes de llamarse Orbital (hasta que instalar.cmd cree el nuevo)
if exist "%~dp0Panel del PC.exe" start "" "%~dp0Panel del PC.exe" %* & exit /b
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0ventana.ps1" %*
