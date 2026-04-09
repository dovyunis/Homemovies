# ============================================
#  Home Movies - Stop
#  Stops Flask and Cloudflare Tunnel
# ============================================

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = "$appDir\homemovies.pid"

Write-Host ""
Write-Host "  Stopping Home Movies..." -ForegroundColor Yellow

# Kill processes by PID file
if (Test-Path $pidFile) {
    $pids = Get-Content $pidFile
    foreach ($p in $pids) {
        try {
            Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
            Write-Host "  Stopped process $p" -ForegroundColor Gray
        } catch {}
    }
    Remove-Item $pidFile -Force
}

# Also kill by process name as backup
Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*app.py*"
} -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "  Home Movies stopped." -ForegroundColor Green
Write-Host ""
