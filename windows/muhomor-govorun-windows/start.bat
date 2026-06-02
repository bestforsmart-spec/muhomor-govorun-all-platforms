@echo off
setlocal
cd /d "%~dp0"
py -3 muhomor_govorun_windows.py
if errorlevel 1 (
  python muhomor_govorun_windows.py
)
