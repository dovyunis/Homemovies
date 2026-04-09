# ============================================
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

        # Send email notification
        $notifyConf = Join-Path $appDir "notify.conf"
        if (Test-Path $notifyConf) {
            try {
                $gmailUser = $null; $gmailPass = $null; $emailTo = $null
                Get-Content $notifyConf | ForEach-Object {
                    if ($_ -match "^GMAIL_USER=(.+)$") { $gmailUser = $matches[1] }
                    if ($_ -match "^GMAIL_PASS=(.+)$") { $gmailPass = $matches[1] }
                    if ($_ -match "^EMAIL_TO=(.+)$") { $emailTo = $matches[1] }
                }
                if ($gmailUser -and $gmailPass -and $emailTo) {
                    $secPass = ConvertTo-SecureString $gmailPass -AsPlainText -Force
                    $cred = New-Object System.Management.Automation.PSCredential($gmailUser, $secPass)
                    $body = "Home Movies started.`n`nURL: $publicUrl`n`nLogin: dov / yunis2026"
                    Send-MailMessage -From $gmailUser -To $emailTo -Subject "Home Movies - New URL" -Body $body -SmtpServer "smtp.gmail.com" -Port 587 -UseSsl -Credential $cred
                    Log "Email notification sent to $emailTo"
                }
            } catch {
                Log "Email notification failed: $($_.Exception.Message)"
            }
        }
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
