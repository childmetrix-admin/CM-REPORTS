# CFSR Shiny apps run in Azure Container Apps (see infrastructure/docker/shiny/).
# Restart a revision from the Azure portal or Azure CLI instead of killing local R processes.

Write-Host "CFSR Shiny apps are hosted on Azure — not launched as local R processes." -ForegroundColor Cyan
Write-Host "Use Container Apps > your app > Restart revision, or: az containerapp revision restart -h" -ForegroundColor Gray
