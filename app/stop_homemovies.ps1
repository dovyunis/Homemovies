# ============================================
#  Home Movies - Stop
#  Stops Flask, Cloudflare Tunnel, and launcher
# ============================================

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = "$appDir\homemovies.pid"

Write-Host ""
Write-Host "  Stopping Home Movies..." -ForegroundColor Yellow

# Stop the scheduled task if running
try {
    $task = Get-ScheduledTask -TaskName "HomeMoviesAutoStart" -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq "Running") {
        Stop-ScheduledTask -TaskName "HomeMoviesAutoStart" -ErrorAction SilentlyContinue
        Write-Host "  Stopped scheduled task" -ForegroundColor Gray
    }
} catch {}

# Kill processes by PID file
if (Test-Path $pidFile) {
    $pids = Get-Content $pidFile
    foreach ($p in $pids) {
        try {
            $proc = Get-Process -Id $p -ErrorAction SilentlyContinue
            if ($proc) {
                Stop-Process -Id $p -Force
                Write-Host "  Killed process $p ($($proc.Name))" -ForegroundColor Gray
            }
        } catch {}
    }
    Remove-Item $pidFile -Force
}

# Kill ALL cloudflared processes
$cfProcs = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
if ($cfProcs) {
    $cfProcs | Stop-Process -Force
    Write-Host "  Killed cloudflared" -ForegroundColor Gray
}

# Kill python processes running app.py (check command line via WMI)
try {
    $pyProcs = Get-WmiObject Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue
    foreach ($proc in $pyProcs) {
        if ($proc.CommandLine -like "*app.py*") {
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed python $($proc.ProcessId)" -ForegroundColor Gray
        }
    }
} catch {}

# Kill any powershell running start_homemovies.ps1
try {
    $psProcs = Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue
    foreach ($proc in $psProcs) {
        if ($proc.CommandLine -like "*start_homemovies*") {
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "  Killed launcher $($proc.ProcessId)" -ForegroundColor Gray
        }
    }
} catch {}

# Clean up temp files
Remove-Item "$appDir\tunnel_output.tmp" -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

# Verify nothing is listening on port 5000
$listening = netstat -ano 2>$null | Select-String ":5000 " | Select-String "LISTENING"
if ($listening) {
    Write-Host "  WARNING: Port 5000 still in use. Force killing..." -ForegroundColor Yellow
    $listening | ForEach-Object {
        if ($_ -match '\s+(\d+)\s*$') {
            Stop-Process -Id $matches[1] -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "  Home Movies stopped." -ForegroundColor Green
Write-Host ""
