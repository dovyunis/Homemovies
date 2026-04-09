# ============================================
#  Home Movies + Internet Access (Free)
# ============================================

# --- EDIT YOUR SETTINGS ---
$env:APP_USERNAME = "dov"
$env:APP_PASSWORD = "yunis2026"
$env:SECRET_KEY = "my-super-secret-key-change-me"
# $env:ALLOWED_DRIVES = "C,D,E"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Home Movies + Internet Access" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check Python
try {
    $pyVersion = python --version 2>&1
    Write-Host "  Found: $pyVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Python not found!" -ForegroundColor Red
    Write-Host "  Install from https://www.python.org/downloads/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check cloudflared
try {
    $cfVersion = cloudflared --version 2>&1
    Write-Host "  Found: cloudflared" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: cloudflared not found!" -ForegroundColor Red
    Write-Host "  Install: winget install Cloudflare.cloudflared" -ForegroundColor Yellow
    Write-Host "  Or download from:" -ForegroundColor Yellow
    Write-Host "  https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Setup virtual environment
if (-not (Test-Path "venv")) {
    Write-Host "  Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

Write-Host "  Activating virtual environment..." -ForegroundColor Yellow
& .\venv\Scripts\Activate.ps1

Write-Host "  Installing dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt --quiet

Write-Host ""
Write-Host "  Step 1: Starting Home Movies Server..." -ForegroundColor Yellow

# Start Flask in background
$flaskJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    & .\venv\Scripts\Activate.ps1
    $env:APP_USERNAME = $using:env:APP_USERNAME
    $env:APP_PASSWORD = $using:env:APP_PASSWORD
    $env:SECRET_KEY = $using:env:SECRET_KEY
    python app.py
}

# Wait for Flask to start
Write-Host "  Waiting for server to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 6

# Test if server is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000/login" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  Server is running!" -ForegroundColor Green
} catch {
    Write-Host "  WARNING: Server may not be ready yet." -ForegroundColor Yellow
    Write-Host "  Check for errors:" -ForegroundColor Yellow
    Receive-Job $flaskJob
}

Write-Host ""
Write-Host "  Step 2: Starting Cloudflare Tunnel..." -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Local:  http://localhost:5000" -ForegroundColor White
Write-Host "  Public: Look below for your" -ForegroundColor White
Write-Host "          https://....trycloudflare.com URL" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Start tunnel and capture URL to file
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $appDir) { $appDir = $PWD.Path }
$urlFile = "$appDir\internet_url.txt"

$tunnelJob = Start-Job -ScriptBlock {
    param($urlFilePath)
    $process = Start-Process -FilePath "cloudflared" -ArgumentList "tunnel", "--url", "http://localhost:5000" -NoNewWindow -RedirectStandardError "$env:TEMP\cloudflared_output.txt" -PassThru
    Start-Sleep -Seconds 10
    # Read the output to find the URL
    if (Test-Path "$env:TEMP\cloudflared_output.txt") {
        $output = Get-Content "$env:TEMP\cloudflared_output.txt" -Raw
        if ($output -match "(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)") {
            $publicUrl = $matches[1]
            @"
Your Home Movies internet URL:
$publicUrl

Login: dov / yunis2026

NOTE: This URL changes when the app restarts.
Check this file again after a reboot.
"@ | Set-Content -Path $urlFilePath
        }
    }
    $process.WaitForExit()
} -ArgumentList $urlFile

# Also run in foreground so user sees output
try {
    cloudflared tunnel --url http://localhost:5000
} finally {
    # Cleanup: stop Flask and tunnel when closed
    Stop-Job $flaskJob -ErrorAction SilentlyContinue
    Remove-Job $flaskJob -ErrorAction SilentlyContinue
    Stop-Job $tunnelJob -ErrorAction SilentlyContinue
    Remove-Job $tunnelJob -ErrorAction SilentlyContinue
    Write-Host "  Server stopped." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
}
