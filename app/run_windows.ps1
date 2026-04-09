# ============================================
#  Home Movies - Windows Setup & Launch
# ============================================

# --- EDIT YOUR SETTINGS ---
$env:APP_USERNAME = "admin"
$env:APP_PASSWORD = "changeme"
$env:SECRET_KEY = "my-super-secret-key-change-me"
# $env:ALLOWED_DRIVES = "C,D,E"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Home Movies - Setup & Launch" -ForegroundColor Cyan
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
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Username: $env:APP_USERNAME" -ForegroundColor White
Write-Host "  Password: $env:APP_PASSWORD" -ForegroundColor White
Write-Host "  URL:      http://localhost:5000" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

python app.py
Read-Host "Press Enter to exit"
