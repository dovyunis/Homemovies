# ============================================
#  Home Movies - Background Launcher
#  Starts Flask + Cloudflare Tunnel silently
#  URL is saved to internet_url.txt
# ============================================

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $appDir

$logFile = "$appDir\homemovies.log"
$urlFile = "$appDir\internet_url.txt"
$pidFile = "$appDir\homemovies.pid"

# Log function
function Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp  $msg" | Out-File -Append -FilePath $logFile
}

Log "====== Starting Home Movies ======"

# Kill any existing processes from previous run
if (Test-Path $pidFile) {
    $oldPids = Get-Content $pidFile
    foreach ($oldPid in $oldPids) {
        try { Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue } catch {}
    }
    Remove-Item $pidFile -Force
}

# Setup venv if needed
if (-not (Test-Path "$appDir\venv")) {
    Log "Creating virtual environment..."
    python -m venv "$appDir\venv"
}

# Install dependencies
Log "Installing dependencies..."
& "$appDir\venv\Scripts\pip.exe" install -r "$appDir\requirements.txt" --quiet 2>&1 | Out-Null

# Set environment
$env:APP_USERNAME = "dov"
$env:APP_PASSWORD = "yunis2026"
$env:SECRET_KEY = "home-movies-service-key-2026"
$env:PORT = "5000"

# --- Step 1: Start Flask ---
Log "Starting Flask on port 5000..."
$flaskProcess = Start-Process -FilePath "$appDir\venv\Scripts\python.exe" `
    -ArgumentList "$appDir\app.py" `
    -WorkingDirectory $appDir `
    -WindowStyle Hidden `
    -PassThru

Log "Flask PID: $($flaskProcess.Id)"

# Wait for Flask to be ready
Start-Sleep -Seconds 6

# Check if Flask is running
if ($flaskProcess.HasExited) {
    Log "ERROR: Flask failed to start!"
    exit 1
}

# --- Step 2: Start Cloudflare Tunnel ---
$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
    Log "Starting Cloudflare tunnel..."

    # Start cloudflared and redirect stderr to a temp file to capture URL
    $tunnelStderrFile = "$appDir\tunnel_output.tmp"
    $tunnelProcess = Start-Process -FilePath "cloudflared" `
        -ArgumentList "tunnel", "--url", "http://localhost:5000" `
        -WindowStyle Hidden `
        -RedirectStandardError $tunnelStderrFile `
        -PassThru

    Log "Tunnel PID: $($tunnelProcess.Id)"

    # Save PIDs for cleanup
    @($flaskProcess.Id, $tunnelProcess.Id) | Set-Content $pidFile

    # Wait for URL to appear in output
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
        @"
==========================================
  Home Movies - Internet URL
==========================================

  $publicUrl

  Login: dov / yunis2026

  This URL changes when the app restarts.
  Check this file again after a reboot.
==========================================
"@ | Set-Content $urlFile
    } else {
        Log "WARNING: Could not detect tunnel URL after ${maxWait}s"
        @"
==========================================
  Home Movies
==========================================

  Local: http://localhost:5000
  Internet URL: Could not be detected.

  The tunnel may still be starting.
  Try again in a minute, or check the log:
  $logFile
==========================================
"@ | Set-Content $urlFile
    }
} else {
    Log "WARNING: cloudflared not installed, local only"
    # Save only Flask PID
    @($flaskProcess.Id) | Set-Content $pidFile
    @"
==========================================
  Home Movies - LOCAL ONLY
==========================================

  http://localhost:5000
  Login: dov / yunis2026

  cloudflared is not installed.
  Install it for internet access:
    winget install Cloudflare.cloudflared
==========================================
"@ | Set-Content $urlFile
}

Log "Home Movies is running."

# Keep this script alive (so Task Scheduler sees it as running)
# Check every 60 seconds if Flask is still alive, restart if needed
while ($true) {
    Start-Sleep -Seconds 60

    # Check Flask
    if ($flaskProcess.HasExited) {
        Log "Flask crashed, restarting..."
        $flaskProcess = Start-Process -FilePath "$appDir\venv\Scripts\python.exe" `
            -ArgumentList "$appDir\app.py" `
            -WorkingDirectory $appDir `
            -WindowStyle Hidden `
            -PassThru
        Log "Flask restarted, PID: $($flaskProcess.Id)"
    }

    # Check tunnel
    if ($cloudflared -and $tunnelProcess -and $tunnelProcess.HasExited) {
        Log "Tunnel crashed, restarting..."
        $tunnelProcess = Start-Process -FilePath "cloudflared" `
            -ArgumentList "tunnel", "--url", "http://localhost:5000" `
            -WindowStyle Hidden `
            -PassThru
        Log "Tunnel restarted, PID: $($tunnelProcess.Id)"
    }
}
