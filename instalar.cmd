@echo off
rem Doble clic para preparar el panel en este PC (solo la primera vez).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1" %*
pause
