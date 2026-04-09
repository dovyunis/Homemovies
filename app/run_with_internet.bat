@echo off
echo ============================================
echo  Home Movies + Internet Access (Free)
echo ============================================
echo.

REM --- EDIT YOUR SETTINGS ---
set APP_USERNAME=admin
set APP_PASSWORD=changeme
set SECRET_KEY=my-super-secret-key-change-me
REM set ALLOWED_DRIVES=C,D,E

REM Check cloudflared
cloudflared --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo cloudflared not found! Install it:
    echo   winget install Cloudflare.cloudflared
    echo.
    echo Or download from:
    echo   https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
    echo.
    pause
    exit /b 1
)

REM Check Python
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Python not found! Install from https://www.python.org/downloads/
    pause
    exit /b 1
)

REM Setup venv
if not exist "venv" python -m venv venv
call venv\Scripts\activate.bat
pip install -r requirements.txt --quiet

echo.
echo  Step 1: Starting Home Movies Server...
start "Home Movies Server" cmd /k "call venv\Scripts\activate.bat && set APP_USERNAME=%APP_USERNAME% && set APP_PASSWORD=%APP_PASSWORD% && set SECRET_KEY=%SECRET_KEY% && python app.py"

REM Wait for Flask to start
echo  Waiting for server to start...
timeout /t 5 >nul

echo  Step 2: Starting Cloudflare Tunnel...
echo.
echo  ============================================
echo   Local:  http://localhost:5000
echo   Public: Look below for your public URL
echo           (https://....trycloudflare.com)
echo  ============================================
echo.

cloudflared tunnel --url http://localhost:5000
pause
