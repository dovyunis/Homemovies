# ============================================
#  Home Movies - Restart and Open in Chrome
# ============================================

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$urlFile = Join-Path $appDir "internet_url.txt"
$taskName = "HomeMoviesAutoStart"

Write-Host ""
Write-Host "  Restarting Home Movies..." -ForegroundColor Cyan

# Stop
Write-Host "  Stopping..." -ForegroundColor Yellow
taskkill /F /IM python.exe 2>$null | Out-Null
taskkill /F /IM python3.12.exe 2>$null | Out-Null
taskkill /F /IM cloudflared.exe 2>$null | Out-Null
schtasks /End /TN $taskName 2>$null | Out-Null
Start-Sleep -Seconds 3

# Remove old URL file
if (Test-Path $urlFile) { Remove-Item $urlFile -Force }

# Start
Write-Host "  Starting..." -ForegroundColor Yellow
schtasks /Run /TN $taskName

# Wait for URL file
Write-Host "  Waiting for internet URL..." -ForegroundColor Yellow
$maxWait = 45
$waited = 0
while ($waited -lt $maxWait) {
    Start-Sleep -Seconds 3
    $waited += 3
    if (Test-Path $urlFile) {
        $content = Get-Content $urlFile -Raw
        if ($content -match "(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)") {
            $url = $matches[1]
            Write-Host ""
            Write-Host "  URL: $url" -ForegroundColor Green
            Write-Host "  Opening in Chrome..." -ForegroundColor Cyan
            Start-Process "chrome.exe" $url
            Write-Host ""
            Write-Host "  Done!" -ForegroundColor Green
            Write-Host ""
            exit 0
        }
    }
    Write-Host "    ($waited sec)..." -ForegroundColor Gray
}

# Fallback: open localhost
Write-Host ""
Write-Host "  Could not get internet URL." -ForegroundColor Yellow
Write-Host "  Opening localhost instead..." -ForegroundColor Yellow
Start-Process "chrome.exe" "http://localhost:5000"
Write-Host ""
