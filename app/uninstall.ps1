# ============================================
#  Home Movies - Uninstall
#  Removes the scheduled task and stops processes
#  Run AS ADMINISTRATOR
# ============================================

$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$taskName = "HomeMoviesAutoStart"

Write-Host ""
Write-Host "  Uninstalling Home Movies..." -ForegroundColor Yellow

# Stop processes
& "$appDir\stop_homemovies.ps1"

# Remove scheduled task
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  Scheduled task removed." -ForegroundColor Green
} else {
    Write-Host "  No scheduled task found." -ForegroundColor Gray
}

# Remove old pywin32 service if it exists
$oldService = Get-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
if ($oldService) {
    Stop-Service -Name "HomeMoviesService" -ErrorAction SilentlyContinue
    sc.exe delete HomeMoviesService 2>$null
    Write-Host "  Old Windows Service removed." -ForegroundColor Green
}

# Remove startup VBS if exists
$startupFolder = [System.Environment]::GetFolderPath("Startup")
$vbsPath = "$startupFolder\HomeMovies.vbs"
if (Test-Path $vbsPath) {
    Remove-Item $vbsPath -Force
    Write-Host "  Startup script removed." -ForegroundColor Green
}

# Clean up temp files
Remove-Item "$appDir\internet_url.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$appDir\homemovies.log" -Force -ErrorAction SilentlyContinue
Remove-Item "$appDir\homemovies.pid" -Force -ErrorAction SilentlyContinue
Remove-Item "$appDir\tunnel_output.tmp" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "  Home Movies uninstalled." -ForegroundColor Green
Write-Host "  (Your movies and app files are still here)" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"
