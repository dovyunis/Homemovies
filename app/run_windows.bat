@echo off
echo ============================================
echo    Home Movies - Windows Setup ^& Launch
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

REM ============================================
REM    EDIT YOUR SETTINGS BELOW
REM ============================================

REM --- Login credentials ---
set APP_USERNAME=admin
set APP_PASSWORD=changeme

REM --- Secret key (change to any random text) ---
set SECRET_KEY=my-super-secret-key-change-me

REM --- Optionally restrict which drives are shown (comma-separated) ---
REM set ALLOWED_DRIVES=C,D,E

REM ============================================
echo.
echo  Username: %APP_USERNAME%
echo  Password: %APP_PASSWORD%
echo.
echo  Starting server on http://localhost:5000
echo.
echo  To enable public access, open another terminal and run:
echo    cloudflared tunnel run homemovies
echo ============================================
echo.

python app.py
pause
