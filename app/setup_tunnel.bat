@echo off
echo ============================================
echo  Cloudflare Tunnel Setup for Home Movies
echo ============================================
echo.
echo  This script helps you set up a permanent
echo  public URL for your Home Movies app.
echo.
echo  PREREQUISITES:
echo  1. A Cloudflare account (free): https://dash.cloudflare.com/sign-up
echo  2. A domain name added to Cloudflare (e.g. yourdomain.com)
echo     - Buy one at Cloudflare for ~$10/year
echo     - Or transfer an existing domain to Cloudflare
echo.
echo ============================================
echo  STEP 1: Install Cloudflared
echo ============================================
echo.

REM Check if cloudflared is installed
cloudflared --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Downloading cloudflared...
    echo.
    echo Option A: Download from https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
    echo Option B: Run: winget install Cloudflare.cloudflared
    echo.
    echo After installing, run this script again.
    pause
    exit /b 1
)

echo cloudflared is installed!
echo.

echo ============================================
echo  STEP 2: Login to Cloudflare
echo ============================================
echo.
echo This will open your browser to authenticate.
echo.
cloudflared tunnel login

echo.
echo ============================================
echo  STEP 3: Create the tunnel
echo ============================================
echo.
cloudflared tunnel create homemovies

echo.
echo ============================================
echo  STEP 4: Route your domain to the tunnel
echo ============================================
echo.
echo Enter your subdomain (e.g., movies.yourdomain.com):
set /p DOMAIN="> "
cloudflared tunnel route dns homemovies %DOMAIN%

echo.
echo ============================================
echo  STEP 5: Create tunnel config
echo ============================================
echo.

REM Get the tunnel ID
for /f "tokens=1" %%i in ('cloudflared tunnel list -o json 2^>nul ^| findstr /r "homemovies"') do set TUNNEL_ID=%%i

REM Create config file
set CONFIG_DIR=%USERPROFILE%\.cloudflared
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"

(
echo tunnel: homemovies
echo credentials-file: %CONFIG_DIR%\cert.pem
echo.
echo ingress:
echo   - hostname: %DOMAIN%
echo     service: http://localhost:5000
echo   - service: http_status:404
) > "%CONFIG_DIR%\config.yml"

echo Config saved to %CONFIG_DIR%\config.yml
echo.
echo ============================================
echo  SETUP COMPLETE!
echo ============================================
echo.
echo  Your permanent URL will be: https://%DOMAIN%
echo.
echo  To start the tunnel, run:
echo    cloudflared tunnel run homemovies
echo.
echo  Or use run_with_tunnel.bat to start
echo  both the app and tunnel together!
echo.
pause
