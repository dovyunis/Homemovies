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
echo  Starting Cloudflare Tunnel...
echo  (Look for your public URL in the new window)
echo.
start "Cloudflare Tunnel" cmd /k "cloudflared tunnel --url http://localhost:5000"

REM Wait a moment for the tunnel to start
timeout /t 3 >nul

echo  Starting Home Movies Server...
echo.
echo  ============================================
echo   Local:  http://localhost:5000
echo   Public: Check the Cloudflare Tunnel window
echo           for your https://....trycloudflare.com URL
echo  ============================================
echo.

python app.py
pause
