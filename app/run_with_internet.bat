@echo off
echo ============================================
echo  Home Movies + Internet Access (Free)
echo ============================================
echo.

REM --- EDIT YOUR SETTINGS ---
set APP_USERNAME=dov
set APP_PASSWORD=yunis2026
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
echo  Step 1: Starting Home Movies Server in background...

REM Start Flask in background using pythonw or start /b
start /b python app.py

echo  Waiting for server to be ready...
timeout /t 8 >nul

REM Verify server is running
curl -s -o nul http://localhost:5000/login
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ERROR: Flask server failed to start!
    echo  Try running "python app.py" manually to see the error.
    pause
    exit /b 1
)

echo  Server is running!
echo.
echo  Step 2: Starting Cloudflare Tunnel...
echo.
echo  ============================================
echo   Local:  http://localhost:5000
echo   Public: Look below for your
echo           https://....trycloudflare.com URL
echo  ============================================
echo.

cloudflared tunnel --url http://localhost:5000
pause
