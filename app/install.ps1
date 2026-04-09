# ============================================
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
