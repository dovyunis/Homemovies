# ============================================
#  Home Movies - Stop
#  Stops Flask, Cloudflare Tunnel, and launcher
# ============================================

Write-Host ""
Write-Host "  Stopping Home Movies..." -ForegroundColor Yellow

# Stop the scheduled task
try {
    Stop-ScheduledTask -TaskName "HomeMoviesAutoStart" -ErrorAction SilentlyContinue
    Write-Host "  Stopped scheduled task" -ForegroundColor Gray
} catch {}

# Kill all python and cloudflared processes
taskkill /F /IM python.exe 2>$null
taskkill /F /IM python3.12.exe 2>$null
taskkill /F /IM cloudflared.exe 2>$null

Write-Host "  Killed python and cloudflared" -ForegroundColor Gray

# Kill any powershell running start_homemovies
try {
    $psProcs = Get-WmiObject Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue
    foreach ($proc in $psProcs) {
        if ($proc.CommandLine -like "*start_homemovies*") {
            taskkill /F /PID $proc.ProcessId 2>$null
            Write-Host "  Killed launcher $($proc.ProcessId)" -ForegroundColor Gray
        }
    }
} catch {}

Start-Sleep -Seconds 2

# Verify port 5000 is free
$still = netstat -ano 2>$null | findstr ":5000" | findstr "LISTENING"
if ($still) {
    Write-Host "  Port 5000 still in use, force killing..." -ForegroundColor Yellow
    $still | ForEach-Object {
        if ($_ -match '\s+(\d+)\s*$') {
            taskkill /F /PID $matches[1] 2>$null
        }
    }
}

# Clean up files
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-Item "$appDir\homemovies.pid" -Force -ErrorAction SilentlyContinue
Remove-Item "$appDir\tunnel_output.tmp" -Force -ErrorAction SilentlyContinue

Write-Host "  Home Movies stopped." -ForegroundColor Green
Write-Host ""
