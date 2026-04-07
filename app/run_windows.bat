@echo off
echo ============================================
echo    Home Movies - Windows Setup & Launch
echo ============================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python is not installed or not in PATH.
    echo Please install Python from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt --quiet

REM Set environment variables (edit these!)
echo.
echo ============================================
echo    CONFIGURATION
echo ============================================
echo.

REM --- EDIT THESE VALUES ---
set APP_USERNAME=admin
set APP_PASSWORD=changeme
set SECRET_KEY=change-this-to-a-random-string
REM Optionally restrict to specific drives (comma-separated):
REM set ALLOWED_DRIVES=C,D,E

echo Username: %APP_USERNAME%
echo Password: %APP_PASSWORD%
echo Mode: Windows Drive Browsing
echo.
echo ============================================
echo    Starting Home Movies Server...
echo    Open http://localhost:5000 in your browser
echo ============================================
echo.

python app.py
pause
