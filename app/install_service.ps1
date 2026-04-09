# ============================================
#  Home Movies - Install as Windows Service
#  Includes Cloudflare Tunnel for internet access
#  Run this script AS ADMINISTRATOR in PowerShell
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Home Movies - Service Installer" -ForegroundColor Cyan
Write-Host "  (with Internet Access)" -ForegroundColor Cyan
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

# Check cloudflared
$cfInstalled = $false
try {
    $cfCheck = cloudflared --version 2>&1
    Write-Host "  Found: cloudflared" -ForegroundColor Green
    $cfInstalled = $true
} catch {
    Write-Host ""
    Write-Host "  WARNING: cloudflared not found!" -ForegroundColor Yellow
    Write-Host "  Without it, the app will only be on localhost." -ForegroundColor Yellow
    Write-Host ""
    $install = Read-Host "  Install cloudflared now? (Y/n)"
    if ($install -ne "n") {
        Write-Host "  Installing cloudflared via winget..." -ForegroundColor Yellow
        winget install Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        try {
            cloudflared --version 2>&1 | Out-Null
            Write-Host "  cloudflared installed!" -ForegroundColor Green
            $cfInstalled = $true
        } catch {
            Write-Host "  cloudflared install may need a restart." -ForegroundColor Yellow
            Write-Host "  Restart your PC and run this script again." -ForegroundColor Yellow
        }
    }
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

# Remove old service if exists
$existingService = Get-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Stopping existing service..." -ForegroundColor Yellow
    Stop-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    sc.exe delete HomeMoviesService 2>$null
    Start-Sleep -Seconds 2
}

# Install the service using pywin32
Write-Host ""
Write-Host "  Installing Home Movies service..." -ForegroundColor Yellow
$installOutput = & "$appDir\venv\Scripts\python.exe" "$appDir\service.py" install 2>&1
Write-Host $installOutput

# Verify service was created
Start-Sleep -Seconds 2
$svc = Get-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Host ""
    Write-Host "  pywin32 service install failed. Trying sc.exe fallback..." -ForegroundColor Yellow
    
    $pythonExe = "$appDir\venv\Scripts\python.exe"
    $serviceCmd = "`"$pythonExe`" `"$appDir\service.py`""
    
    # Use sc.exe to create service directly
    sc.exe create HomeMoviesService binPath= "$pythonExe $appDir\service.py" start= auto DisplayName= "Home Movies Web App"
    Start-Sleep -Seconds 2
    $svc = Get-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
}

if (-not $svc) {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Red
    Write-Host "  Service install FAILED with both methods." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Using STARTUP TASK instead (works just as well!)" -ForegroundColor Yellow
    Write-Host "  ============================================" -ForegroundColor Red
    Write-Host ""
    
    # Create a startup VBS script (runs hidden, no console window)
    $startupFolder = [System.Environment]::GetFolderPath("Startup")
    $vbsPath = "$startupFolder\HomeMovies.vbs"
    $ps1Path = "$appDir\run_with_internet.ps1"
    
    $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$ps1Path""", 0, False
"@
    Set-Content -Path $vbsPath -Value $vbsContent
    
    Write-Host "  Created startup task: $vbsPath" -ForegroundColor Green
    Write-Host "  The app will auto-start (hidden) on login." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Starting now..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$ps1Path`"" -WindowStyle Hidden
    Start-Sleep -Seconds 15
    
    # Check for URL file
    $urlFile = "$appDir\internet_url.txt"
    if (Test-Path $urlFile) {
        $urlContent = Get-Content $urlFile
        $publicUrl = ($urlContent | Select-String -Pattern "https://.*trycloudflare\.com").Matches.Value
        if ($publicUrl) {
            Write-Host "  Internet: $publicUrl" -ForegroundColor Green
        }
    }
    Write-Host "  Local: http://localhost:5000" -ForegroundColor Green
    Write-Host "  Login: dov / yunis2026" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

# Set service to start automatically
Write-Host "  Setting service to start automatically..." -ForegroundColor Yellow
Set-Service -Name "HomeMoviesService" -StartupType Automatic

# Start the service
Write-Host "  Starting service..." -ForegroundColor Yellow
Start-Service -Name "HomeMoviesService"

# Wait for URL file to be created
$urlFile = "$appDir\internet_url.txt"
if ($cfInstalled) {
    Write-Host ""
    Write-Host "  Waiting for internet URL..." -ForegroundColor Yellow
    $waited = 0
    while ((-not (Test-Path $urlFile)) -and ($waited -lt 30)) {
        Start-Sleep -Seconds 2
        $waited += 2
        Write-Host "  ..." -ForegroundColor Gray
    }
}

$status = (Get-Service -Name "HomeMoviesService").Status

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Service Status: $status" -ForegroundColor $(if ($status -eq "Running") { "Green" } else { "Red" })
Write-Host ""
Write-Host "  Local:  http://localhost:5000" -ForegroundColor Green

if ((Test-Path $urlFile) -and $cfInstalled) {
    $urlContent = Get-Content $urlFile
    $publicUrl = ($urlContent | Select-String -Pattern "https://.*trycloudflare\.com").Matches.Value
    if ($publicUrl) {
        Write-Host "  Internet: $publicUrl" -ForegroundColor Green
    }
}
elseif (-not $cfInstalled) {
    Write-Host "  Internet: NOT AVAILABLE (install cloudflared)" -ForegroundColor Yellow
}
else {
    Write-Host "  Internet: Check app\internet_url.txt in a moment" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Login: dov / yunis2026" -ForegroundColor White
Write-Host ""
Write-Host "  The service starts automatically on boot." -ForegroundColor White
Write-Host "  The internet URL changes on each restart." -ForegroundColor White
Write-Host "  Check app\internet_url.txt for the current URL." -ForegroundColor White
Write-Host ""
Write-Host "  To manage the service:" -ForegroundColor Yellow
Write-Host "    Stop:    Stop-Service HomeMoviesService" -ForegroundColor Gray
Write-Host "    Start:   Start-Service HomeMoviesService" -ForegroundColor Gray
Write-Host "    Restart: Restart-Service HomeMoviesService" -ForegroundColor Gray
Write-Host "    Remove:  python service.py remove" -ForegroundColor Gray
Write-Host "    Status:  Get-Service HomeMoviesService" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
Read-Host "Press Enter to exit"
