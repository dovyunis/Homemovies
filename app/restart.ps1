# ============================================
#  Home Movies - Restart and Open in Chrome
#  Sends new URL via email notification
# ============================================

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$urlFile = Join-Path $appDir "internet_url.txt"
$taskName = "HomeMoviesAutoStart"
$configFile = Join-Path $appDir "notify.conf"

# --- Email notification function ---
function Send-UrlNotification($url) {
    # Load email config
    if (-not (Test-Path $configFile)) {
        Write-Host "  No notify.conf - skipping email" -ForegroundColor Gray
        return
    }
    $gmailUser = $null
    $gmailPass = $null
    $emailTo = $null
    Get-Content $configFile | ForEach-Object {
        if ($_ -match "^GMAIL_USER=(.+)$") { $gmailUser = $matches[1] }
        if ($_ -match "^GMAIL_PASS=(.+)$") { $gmailPass = $matches[1] }
        if ($_ -match "^EMAIL_TO=(.+)$") { $emailTo = $matches[1] }
    }
    if (-not $gmailUser -or -not $gmailPass -or -not $emailTo) {
        Write-Host "  notify.conf incomplete - skipping email" -ForegroundColor Gray
        return
    }

    try {
        $secPass = ConvertTo-SecureString $gmailPass -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($gmailUser, $secPass)
        $body = "Your Home Movies app has restarted.`n`nNew URL: $url`n`nLogin: dov / yunis2026`n`nThis URL changes on each restart."
        Send-MailMessage `
            -From $gmailUser `
            -To $emailTo `
            -Subject "Home Movies - New URL" `
            -Body $body `
            -SmtpServer "smtp.gmail.com" `
            -Port 587 `
            -UseSsl `
            -Credential $cred
        Write-Host "  Email sent to $emailTo" -ForegroundColor Green
    } catch {
        Write-Host "  Email failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

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
            Write-Host "  Sending email notification..." -ForegroundColor Yellow
            Send-UrlNotification $url
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
