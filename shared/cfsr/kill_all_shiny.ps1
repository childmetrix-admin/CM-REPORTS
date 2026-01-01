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
Write-Host "2. Run: source('D:/repo_childmetrix/cm-reports/shared/cfsr/launch_cfsr_dashboard.R')"
Write-Host "3. Wait for all 4 apps to start (watch for messages)"
Write-Host "4. In browser, press Ctrl+Shift+R to hard refresh test_navigation.html"
Write-Host ""
