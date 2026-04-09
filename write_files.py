#!/usr/bin/env python3
"""Write the PowerShell scripts that keep ending up empty."""
import os

app_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app")

# ---- start_homemovies.ps1 ----
start_content = r'''# ============================================
#  Home Movies - Background Launcher
#  Starts Flask + Cloudflare Tunnel silently
#  URL is saved to internet_url.txt
# ============================================

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $appDir

$logFile = Join-Path $appDir "homemovies.log"
$urlFile = Join-Path $appDir "internet_url.txt"
$pidFile = Join-Path $appDir "homemovies.pid"
$configFile = Join-Path $appDir "paths.conf"

function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp  $msg" | Out-File -Append -FilePath $logFile -Encoding utf8
}

Log "====== Starting Home Movies ======"

# Load saved paths from install
$pythonExe = $null
$cloudflaredExe = $null
if (Test-Path $configFile) {
    $config = Get-Content $configFile
    foreach ($line in $config) {
        if ($line -match "^PYTHON=(.+)$") { $pythonExe = $matches[1] }
        if ($line -match "^CLOUDFLARED=(.+)$") { $cloudflaredExe = $matches[1] }
    }
}

# Fallback: try PATH
if (-not $pythonExe -or -not (Test-Path $pythonExe)) {
    $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
}
if (-not $cloudflaredExe -or -not (Test-Path $cloudflaredExe)) {
    $cloudflaredExe = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
}

# Use venv python if available
$venvPython = Join-Path $appDir "venv\Scripts\python.exe"
if (Test-Path $venvPython) { $pythonExe = $venvPython }

if (-not $pythonExe) {
    Log "ERROR: Python not found!"
    exit 1
}
Log "Python: $pythonExe"

# Kill old processes
if (Test-Path $pidFile) {
    $oldPids = Get-Content $pidFile
    foreach ($oldPid in $oldPids) {
        try { Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue } catch {}
    }
    Remove-Item $pidFile -Force
}

# Setup venv if needed
if (-not (Test-Path (Join-Path $appDir "venv"))) {
    Log "Creating venv..."
    & $pythonExe -m venv (Join-Path $appDir "venv")
    $pythonExe = $venvPython
}

# Install deps
Log "Installing dependencies..."
$pipExe = Join-Path $appDir "venv\Scripts\pip.exe"
& $pipExe install -r (Join-Path $appDir "requirements.txt") --quiet 2>&1 | Out-Null

# Environment
$env:APP_USERNAME = "dov"
$env:APP_PASSWORD = "yunis2026"
$env:SECRET_KEY = "home-movies-service-key-2026"
$env:PORT = "5000"

# Start Flask
Log "Starting Flask on port 5000..."
$appPy = Join-Path $appDir "app.py"
$flaskProcess = Start-Process -FilePath $pythonExe -ArgumentList $appPy -WorkingDirectory $appDir -WindowStyle Hidden -PassThru
Log "Flask PID: $($flaskProcess.Id)"

Start-Sleep -Seconds 8

if ($flaskProcess.HasExited) {
    Log "ERROR: Flask failed to start!"
    exit 1
}
Log "Flask is running."

# Start Cloudflare Tunnel
if ($cloudflaredExe -and (Test-Path $cloudflaredExe)) {
    Log "Starting Cloudflare tunnel..."
    $tunnelStderrFile = Join-Path $appDir "tunnel_output.tmp"
    if (Test-Path $tunnelStderrFile) { Remove-Item $tunnelStderrFile -Force }

    $tunnelProcess = Start-Process -FilePath $cloudflaredExe -ArgumentList "tunnel","--url","http://localhost:5000" -WindowStyle Hidden -RedirectStandardError $tunnelStderrFile -PassThru
    Log "Tunnel PID: $($tunnelProcess.Id)"

    @($flaskProcess.Id, $tunnelProcess.Id) | Set-Content $pidFile

    $maxWait = 30
    $waited = 0
    $publicUrl = $null
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 2
        $waited += 2
        if (Test-Path $tunnelStderrFile) {
            $output = Get-Content $tunnelStderrFile -Raw -ErrorAction SilentlyContinue
            if ($output -match "(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)") {
                $publicUrl = $matches[1]
                break
            }
        }
    }

    if ($publicUrl) {
        Log "Internet URL: $publicUrl"
        "Your Home Movies URL: $publicUrl`r`nLogin: dov / yunis2026`r`nURL changes on restart - check this file again." | Set-Content $urlFile -Encoding utf8
    } else {
        Log "WARNING: Could not detect tunnel URL"
        "Local: http://localhost:5000`r`nLogin: dov / yunis2026`r`nTunnel URL not detected - check homemovies.log" | Set-Content $urlFile -Encoding utf8
    }
} else {
    Log "cloudflared not found, local only"
    @($flaskProcess.Id) | Set-Content $pidFile
    "Local only: http://localhost:5000`r`nLogin: dov / yunis2026`r`nInstall cloudflared for internet access" | Set-Content $urlFile -Encoding utf8
}

Log "Home Movies is running."

# Keep alive loop - restart crashed processes
while ($true) {
    Start-Sleep -Seconds 60
    if ($flaskProcess.HasExited) {
        Log "Flask crashed, restarting..."
        $flaskProcess = Start-Process -FilePath $pythonExe -ArgumentList $appPy -WorkingDirectory $appDir -WindowStyle Hidden -PassThru
        Log "Flask restarted PID: $($flaskProcess.Id)"
    }
    if ($cloudflaredExe -and $tunnelProcess -and $tunnelProcess.HasExited) {
        Log "Tunnel crashed, restarting..."
        $tunnelProcess = Start-Process -FilePath $cloudflaredExe -ArgumentList "tunnel","--url","http://localhost:5000" -WindowStyle Hidden -PassThru
        Log "Tunnel restarted PID: $($tunnelProcess.Id)"
    }
}
'''

# ---- install.ps1 ----
install_content = r'''# ============================================
#  Home Movies - Install (Auto-start on Boot)
#  Uses Windows Task Scheduler
#  Run this script AS ADMINISTRATOR in PowerShell
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Home Movies - Installer" -ForegroundColor Cyan
Write-Host "  (auto-start + internet access)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  ERROR: Run as Administrator!" -ForegroundColor Red
    Write-Host "  Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$taskName = "HomeMoviesAutoStart"

# Check Python
Write-Host "  Checking requirements..." -ForegroundColor Yellow
$pythonPath = $null
try {
    $pythonPath = (Get-Command python -ErrorAction Stop).Source
    $pyVersion = python --version 2>&1
    Write-Host "    Python: $pyVersion ($pythonPath)" -ForegroundColor Green
} catch {
    Write-Host "    ERROR: Python not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check cloudflared
$cfPath = $null
$cfInstalled = $false
try {
    $cfPath = (Get-Command cloudflared -ErrorAction Stop).Source
    Write-Host "    cloudflared: found ($cfPath)" -ForegroundColor Green
    $cfInstalled = $true
} catch {
    Write-Host "    cloudflared: NOT FOUND" -ForegroundColor Yellow
    $install = Read-Host "    Install cloudflared for internet access? (Y/n)"
    if ($install -ne "n") {
        Write-Host "    Installing cloudflared..." -ForegroundColor Yellow
        winget install Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
        try {
            $cfPath = (Get-Command cloudflared -ErrorAction Stop).Source
            Write-Host "    cloudflared installed!" -ForegroundColor Green
            $cfInstalled = $true
        } catch {
            Write-Host "    May need PC restart. Run installer again after." -ForegroundColor Yellow
        }
    }
}

# Save paths so the launcher can find them even as SYSTEM
$configFile = Join-Path $appDir "paths.conf"
$configLines = @("PYTHON=$pythonPath")
if ($cfPath) { $configLines += "CLOUDFLARED=$cfPath" }
$configLines | Set-Content $configFile -Encoding utf8
Write-Host "    Saved paths to paths.conf" -ForegroundColor Green

# Setup venv
Write-Host ""
Write-Host "  Setting up Python environment..." -ForegroundColor Yellow
if (-not (Test-Path (Join-Path $appDir "venv"))) {
    python -m venv (Join-Path $appDir "venv")
}
$pipExe = Join-Path $appDir "venv\Scripts\pip.exe"
& $pipExe install -r (Join-Path $appDir "requirements.txt") --quiet 2>&1 | Out-Null
Write-Host "    Dependencies installed." -ForegroundColor Green

# Remove old task
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "  Removing old task..." -ForegroundColor Yellow
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Start-Sleep -Seconds 2
}

# Stop old processes
$stopScript = Join-Path $appDir "stop_homemovies.ps1"
if (Test-Path $stopScript) { & $stopScript }

# Clean up old pywin32 service
$oldSvc = Get-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
if ($oldSvc) {
    Stop-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
    sc.exe delete HomeMoviesService 2>$null
}

# Create Scheduled Task
Write-Host ""
Write-Host "  Creating auto-start task..." -ForegroundColor Yellow

$launcherScript = Join-Path $appDir "start_homemovies.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherScript`"" -WorkingDirectory $appDir

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -DontStopOnIdleEnd -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit (New-TimeSpan -Days 365)

# Run as current user (so PATH works properly)
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType S4U -RunLevel Highest

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Home Movies web app with internet access" -Force | Out-Null

Write-Host "    Task created!" -ForegroundColor Green

# Start it now
Write-Host ""
Write-Host "  Starting Home Movies..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName $taskName

# Wait for URL file
$urlFile = Join-Path $appDir "internet_url.txt"
if (Test-Path $urlFile) { Remove-Item $urlFile -Force }

$waited = 0
$maxWait = 45
while ($waited -lt $maxWait) {
    Start-Sleep -Seconds 3
    $waited += 3
    if (Test-Path $urlFile) { break }
    Write-Host "    waiting... ($waited sec)" -ForegroundColor Gray
}

# Show results
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan

$taskInfo = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($taskInfo) {
    Write-Host "  Task: $($taskInfo.State)" -ForegroundColor Green
}

Write-Host "  Local:    http://localhost:5000" -ForegroundColor Green

if (Test-Path $urlFile) {
    $urlContent = Get-Content $urlFile -Raw
    if ($urlContent -match "(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)") {
        Write-Host "  Internet: $($matches[1])" -ForegroundColor Green
    } else {
        Write-Host "  Internet: check internet_url.txt" -ForegroundColor Yellow
    }
} elseif ($cfInstalled) {
    Write-Host "  Internet: starting... check internet_url.txt" -ForegroundColor Yellow
} else {
    Write-Host "  Internet: not available (no cloudflared)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Login: dov / yunis2026" -ForegroundColor White
Write-Host ""
Write-Host "  Auto-starts on boot." -ForegroundColor White
Write-Host "  URL changes on restart - check internet_url.txt" -ForegroundColor White
Write-Host ""
Write-Host "  Commands:" -ForegroundColor Yellow
Write-Host "    Stop:      .\stop_homemovies.ps1" -ForegroundColor Gray
Write-Host "    Start:     Start-ScheduledTask $taskName" -ForegroundColor Gray
Write-Host "    Uninstall: .\uninstall.ps1" -ForegroundColor Gray
Write-Host "    Logs:      type homemovies.log" -ForegroundColor Gray
Write-Host "    URL:       type internet_url.txt" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
'''

# Write files
for filename, content in [("start_homemovies.ps1", start_content), ("install.ps1", install_content)]:
    filepath = os.path.join(app_dir, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    size = os.path.getsize(filepath)
    lines = content.strip().count("\n") + 1
    print(f"OK: {filename} = {lines} lines, {size} bytes")
