# ============================================
#  Home Movies - Install as Windows Service
#  Run this script AS ADMINISTRATOR in PowerShell
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Home Movies - Service Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host "  Then run this script again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check Python
try {
    $pyVersion = python --version 2>&1
    Write-Host "  Found: $pyVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Python not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Setup venv if needed
if (-not (Test-Path "$appDir\venv")) {
    Write-Host "  Creating virtual environment..." -ForegroundColor Yellow
    python -m venv "$appDir\venv"
}

Write-Host "  Installing dependencies..." -ForegroundColor Yellow
& "$appDir\venv\Scripts\pip.exe" install -r "$appDir\requirements.txt" --quiet
& "$appDir\venv\Scripts\pip.exe" install pywin32 --quiet

Write-Host "  Running pywin32 post-install..." -ForegroundColor Yellow
& "$appDir\venv\Scripts\python.exe" -m pywin32_postinstall -install 2>$null

# Install the service
Write-Host ""
Write-Host "  Installing Home Movies service..." -ForegroundColor Yellow
& "$appDir\venv\Scripts\python.exe" "$appDir\service.py" install

# Set service to start automatically
Write-Host "  Setting service to start automatically..." -ForegroundColor Yellow
Set-Service -Name "HomeMoviesService" -StartupType Automatic

# Start the service
Write-Host "  Starting service..." -ForegroundColor Yellow
Start-Service -Name "HomeMoviesService"

$status = (Get-Service -Name "HomeMoviesService").Status

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Service Status: $status" -ForegroundColor $(if ($status -eq "Running") { "Green" } else { "Red" })
Write-Host ""
Write-Host "  URL: http://localhost:5000" -ForegroundColor Green
Write-Host "  Login: dov / yunis2026" -ForegroundColor White
Write-Host ""
Write-Host "  The service will start automatically" -ForegroundColor White
Write-Host "  when Windows boots." -ForegroundColor White
Write-Host ""
Write-Host "  To manage the service:" -ForegroundColor Yellow
Write-Host "    Stop:    Stop-Service HomeMoviesService" -ForegroundColor Gray
Write-Host "    Start:   Start-Service HomeMoviesService" -ForegroundColor Gray
Write-Host "    Remove:  python service.py remove" -ForegroundColor Gray
Write-Host "    Status:  Get-Service HomeMoviesService" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
