@echo off
setlocal
cd /d "%~dp0"

if not exist "resource" mkdir "resource"

where pythonw >nul 2>nul
if not errorlevel 1 (
    start "" pythonw "app\setup_gui.py" %*
    exit /b 0
)

where python >nul 2>nul
if not errorlevel 1 (
    python "app\setup_gui.py" %*
    if errorlevel 1 pause
    exit /b %errorlevel%
)

where py >nul 2>nul
if not errorlevel 1 (
    py -3 "app\setup_gui.py" %*
    if errorlevel 1 pause
    exit /b %errorlevel%
)

echo Python 3 was not found. Please install Python 3 (with tkinter).
pause
exit /b 1
