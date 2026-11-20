@echo off
rem Doble clic para arrancar el panel en el celular.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0iniciar.ps1" %*
pause
