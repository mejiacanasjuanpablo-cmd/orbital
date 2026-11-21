@echo off
rem Doble clic para revisar los requisitos del panel e instalar lo que falte.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verificar.ps1" %*
pause
