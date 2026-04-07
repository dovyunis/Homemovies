@echo off
echo ============================================
echo  Home Movies + Cloudflare Tunnel
echo ============================================
echo.

REM ============================================
REM    EDIT YOUR SETTINGS BELOW
REM ============================================
set APP_USERNAME=admin
set APP_PASSWORD=changeme
set SECRET_KEY=my-super-secret-key-change-me
REM set ALLOWED_DRIVES=C,D,E
REM ============================================

REM Check if Python is installed
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python is not installed.
    pause
    exit /b 1
)

REM Check if cloudflared is installed
cloudflared --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: cloudflared is not installed.
    echo Run setup_tunnel.bat first.
    pause
    exit /b 1
)

REM Setup venv
if not exist "venv" python -m venv venv
call venv\Scripts\activate.bat
pip install -r requirements.txt --quiet

echo.
echo Starting Cloudflare Tunnel in background...
start "Cloudflare Tunnel" cmd /c "cloudflared tunnel run homemovies"

echo Starting Home Movies Server...
echo.
echo ============================================
echo  Your app is available at your domain!
echo  (e.g., https://movies.yourdomain.com)
echo.
echo  Local: http://localhost:5000
echo ============================================
echo.

python app.py
pause
