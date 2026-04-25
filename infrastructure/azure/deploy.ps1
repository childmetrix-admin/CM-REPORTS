# ChildMetrix Azure Deployment Script
# Usage: .\deploy.ps1 -Environment dev -ResourceGroup rg-childmetrix-dev

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [string]$Location = "eastus",

    [switch]$SkipInfra,
    [switch]$SkipContainers,
    [switch]$SkipStaticSite
)

$ErrorActionPreference = "Stop"
$baseName = "childmetrix"
$acrName = "acr${baseName}${Environment}" -replace '-', ''
$suffix = "${baseName}-${Environment}"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ChildMetrix Azure Deployment" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Deploy infrastructure
if (-not $SkipInfra) {
    Write-Host "`n[1/4] Deploying Azure infrastructure..." -ForegroundColor Yellow

    az group create --name $ResourceGroup --location $Location

    $sqlUser = Read-Host "SQL Admin Username"
    $sqlPass = Read-Host "SQL Admin Password" -AsSecureString
    $sqlPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPass)
    )

    az deployment group create `
        --resource-group $ResourceGroup `
        --template-file "$PSScriptRoot\main.bicep" `
        --parameters environment=$Environment `
                     sqlAdminUser=$sqlUser `
                     sqlAdminPassword=$sqlPassPlain

    Write-Host "[1/4] Infrastructure deployed." -ForegroundColor Green
}

# Step 2: Build and push container images
if (-not $SkipContainers) {
    Write-Host "`n[2/4] Building container images..." -ForegroundColor Yellow

    $loginServer = az acr show --name $acrName --query loginServer -o tsv
    az acr login --name $acrName

    $repoRoot = (Get-Item "$PSScriptRoot\..\..").FullName

    Write-Host "Building extraction image..."
    docker build -t "${loginServer}/cm-extraction:latest" `
        -f "$repoRoot\infrastructure\docker\extraction\Dockerfile" $repoRoot

    Write-Host "Building app_measures image..."
    docker build -t "${loginServer}/cm-app-measures:latest" `
        -f "$repoRoot\infrastructure\docker\shiny\app_measures\Dockerfile" $repoRoot

    Write-Host "Building app_summary image..."
    docker build -t "${loginServer}/cm-app-summary:latest" `
        -f "$repoRoot\infrastructure\docker\shiny\app_summary\Dockerfile" $repoRoot

    Write-Host "Building shinyproxy image..."
    docker build -t "${loginServer}/cm-shinyproxy:latest" `
        -f "$repoRoot\infrastructure\docker\shinyproxy\Dockerfile" `
        "$repoRoot\infrastructure\docker\shinyproxy"

    Write-Host "Pushing images to ACR..."
    docker push "${loginServer}/cm-extraction:latest"
    docker push "${loginServer}/cm-app-measures:latest"
    docker push "${loginServer}/cm-app-summary:latest"
    docker push "${loginServer}/cm-shinyproxy:latest"

    Write-Host "[2/4] Container images pushed." -ForegroundColor Green
}

# Step 3: Deploy Container Apps
Write-Host "`n[3/4] Deploying Container Apps..." -ForegroundColor Yellow

$caEnvName = "cae-${suffix}"
$storageName = "st${baseName}${Environment}" -replace '-', ''
$loginServer = az acr show --name $acrName --query loginServer -o tsv
$acrPassword = az acr credential show --name $acrName --query "passwords[0].value" -o tsv
$storageKey = az storage account keys list --account-name $storageName --query "[0].value" -o tsv
$blobEndpoint = "https://${storageName}.blob.core.windows.net"

# Deploy ShinyProxy (main entry point for Shiny apps)
az containerapp create `
    --name "ca-shinyproxy-${Environment}" `
    --resource-group $ResourceGroup `
    --environment $caEnvName `
    --image "${loginServer}/cm-shinyproxy:latest" `
    --registry-server $loginServer `
    --registry-username $acrName `
    --registry-password $acrPassword `
    --target-port 8080 `
    --ingress external `
    --min-replicas 1 `
    --max-replicas 3 `
    --cpu 1.0 `
    --memory 2.0Gi

# Deploy Measures Shiny app
az containerapp create `
    --name "ca-app-measures-${Environment}" `
    --resource-group $ResourceGroup `
    --environment $caEnvName `
    --image "${loginServer}/cm-app-measures:latest" `
    --registry-server $loginServer `
    --registry-username $acrName `
    --registry-password $acrPassword `
    --target-port 3838 `
    --ingress external `
    --min-replicas 1 `
    --max-replicas 3 `
    --cpu 0.5 `
    --memory 1.0Gi `
    --env-vars "AZURE_BLOB_ENDPOINT=$blobEndpoint" "AZURE_STORAGE_KEY=$storageKey"

# Deploy Summary Shiny app
az containerapp create `
    --name "ca-app-summary-${Environment}" `
    --resource-group $ResourceGroup `
    --environment $caEnvName `
    --image "${loginServer}/cm-app-summary:latest" `
    --registry-server $loginServer `
    --registry-username $acrName `
    --registry-password $acrPassword `
    --target-port 3840 `
    --ingress external `
    --min-replicas 1 `
    --max-replicas 3 `
    --cpu 0.5 `
    --memory 1.0Gi `
    --env-vars "AZURE_BLOB_ENDPOINT=$blobEndpoint" "AZURE_STORAGE_KEY=$storageKey"

# Get Shiny app URLs for extraction container
$measuresUrl = az containerapp show --name "ca-app-measures-${Environment}" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv
$summaryUrl = az containerapp show --name "ca-app-summary-${Environment}" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv

Write-Host "Shiny Apps deployed:"
Write-Host "  Measures: https://$measuresUrl"
Write-Host "  Summary: https://$summaryUrl"

Write-Host "[3/4] Container Apps deployed." -ForegroundColor Green

# Step 4: Deploy static site
if (-not $SkipStaticSite) {
    Write-Host "`n[4/4] Deploying static site..." -ForegroundColor Yellow

    $swaName = "swa-${suffix}"
    $repoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
    $deployToken = az staticwebapp secrets list --name $swaName --query "properties.apiKey" -o tsv

    # Install SWA CLI if needed
    if (-not (Get-Command swa -ErrorAction SilentlyContinue)) {
        npm install -g @azure/static-web-apps-cli
    }

    swa deploy $repoRoot `
        --deployment-token $deployToken `
        --env $Environment

    Write-Host "[4/4] Static site deployed." -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
