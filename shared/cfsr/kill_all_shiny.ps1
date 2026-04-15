# Kill all R processes to restart Shiny apps with fresh code

Write-Host "Killing all R processes..." -ForegroundColor Yellow

# Kill all Rterm.exe processes (background Shiny apps)
Get-Process -Name "Rterm" -ErrorAction SilentlyContinue | Stop-Process -Force

# Kill all Rgui.exe processes (if any)
Get-Process -Name "Rgui" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "All R processes killed." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Open RStudio or R console"
Write-Host "2. From the cm-reports repo root in R, run: source('domains/cfsr/launch_cfsr_apps.R')"
Write-Host "3. Wait for both apps to start (see console messages)"
Write-Host "4. Open app.html with ?state= and test CFSR tabs; hard-refresh after code changes"
Write-Host ""
