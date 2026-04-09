# ============================================
#  Home Movies - Install (Auto-start on Boot)
#  Uses Windows Task Scheduler (no pywin32 needed!)
#  Run this script AS ADMINISTRATOR in PowerShell
# ============================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Home Movies - Installer" -ForegroundColor Cyan
Write-Host "  (auto-start + internet access)" -ForegroundColor Cyan
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
$taskName = "HomeMoviesAutoStart"

# ---- Check Python ----
Write-Host "  Checking requirements..." -ForegroundColor Yellow
try {
    $pyVersion = python --version 2>&1
    Write-Host "    Python: $pyVersion" -ForegroundColor Green
} catch {
    Write-Host "    ERROR: Python not found!" -ForegroundColor Red
    Write-Host "    Install from https://www.python.org/downloads/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# ---- Check cloudflared ----
$cfInstalled = $false
try {
    cloudflared --version 2>&1 | Out-Null
    Write-Host "    cloudflared: installed" -ForegroundColor Green
    $cfInstalled = $true
} catch {
    Write-Host "    cloudflared: NOT FOUND" -ForegroundColor Yellow
    Write-Host ""
    $install = Read-Host "    Install cloudflared for internet access? (Y/n)"
    if ($install -ne "n") {
        Write-Host "    Installing cloudflared..." -ForegroundColor Yellow
        winget install Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        try {
            cloudflared --version 2>&1 | Out-Null
            Write-Host "    cloudflared: installed!" -ForegroundColor Green
            $cfInstalled = $true
        } catch {
            Write-Host "    May need a PC restart. Run installer again after." -ForegroundColor Yellow
        }
    }
}

# ---- Setup venv ----
Write-Host ""
Write-Host "  Setting up Python environment..." -ForegroundColor Yellow
if (-not (Test-Path "$appDir\venv")) {
    python -m venv "$appDir\venv"
}
& "$appDir\venv\Scripts\pip.exe" install -r "$appDir\requirements.txt" --quiet 2>&1 | Out-Null
Write-Host "    Dependencies installed." -ForegroundColor Green

# ---- Remove old scheduled task if exists ----
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "  Removing old scheduled task..." -ForegroundColor Yellow
    # Stop any running instance
    & "$appDir\stop_homemovies.ps1"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Start-Sleep -Seconds 2
}

# Also clean up old pywin32 service if it exists
$oldService = Get-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
if ($oldService) {
    Write-Host "  Removing old Windows Service..." -ForegroundColor Yellow
    Stop-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
    sc.exe delete HomeMoviesService 2>$null
}

# ---- Create Scheduled Task ----
Write-Host ""
Write-Host "  Creating auto-start task..." -ForegroundColor Yellow

$launcherScript = "$appDir\start_homemovies.ps1"

# Create the scheduled task action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherScript`"" `
    -WorkingDirectory $appDir

# Trigger: at system startup
$trigger = New-ScheduledTaskTrigger -AtStartup

# Settings: run whether user is logged on or not, don't stop on idle
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 365)

# Run as SYSTEM so it works even before login
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Home Movies - Web app with internet access. Starts Flask + Cloudflare tunnel." `
    -Force | Out-Null

Write-Host "    Task '$taskName' created!" -ForegroundColor Green

# ---- Start it now ----
Write-Host ""
Write-Host "  Starting Home Movies now..." -ForegroundColor Yellow
Start-ScheduledTask -TaskName $taskName

# Wait for it to come up
$urlFile = "$appDir\internet_url.txt"
if (Test-Path $urlFile) { Remove-Item $urlFile -Force }

Write-Host "  Waiting for startup..." -ForegroundColor Yellow
$waited = 0
$maxWait = 40
while ($waited -lt $maxWait) {
    Start-Sleep -Seconds 2
    $waited += 2
    
    # Check if URL file exists (means tunnel is ready)
    if (Test-Path $urlFile) {
        break
    }
    Write-Host "    ($waited sec)..." -ForegroundColor Gray
}

# ---- Show results ----
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan

$taskInfo = Get-ScheduledTask -TaskName $taskName
$taskState = $taskInfo.State
Write-Host "  Task Status: $taskState" -ForegroundColor $(if ($taskState -eq "Running") { "Green" } else { "Yellow" })
Write-Host ""
Write-Host "  Local:    http://localhost:5000" -ForegroundColor Green

if (Test-Path $urlFile) {
    $urlContent = Get-Content $urlFile -Raw
    if ($urlContent -match "(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)") {
        Write-Host "  Internet: $($matches[1])" -ForegroundColor Green
    }
} elseif ($cfInstalled) {
    Write-Host "  Internet: Starting... check app\internet_url.txt" -ForegroundColor Yellow
} else {
    Write-Host "  Internet: Not available (no cloudflared)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Login: dov / yunis2026" -ForegroundColor White
Write-Host ""
Write-Host "  Auto-starts on boot (even before login!)" -ForegroundColor White
Write-Host "  The internet URL changes on each restart." -ForegroundColor White
Write-Host "  Check app\internet_url.txt for current URL." -ForegroundColor White
Write-Host ""
Write-Host "  To manage:" -ForegroundColor Yellow
Write-Host "    Stop:      .\stop_homemovies.ps1" -ForegroundColor Gray
Write-Host "    Start:     Start-ScheduledTask $taskName" -ForegroundColor Gray
Write-Host "    Uninstall: .\uninstall.ps1" -ForegroundColor Gray
Write-Host "    Logs:      app\homemovies.log" -ForegroundColor Gray
Write-Host "    URL:       app\internet_url.txt" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
