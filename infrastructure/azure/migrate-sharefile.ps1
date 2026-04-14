# ChildMetrix - ShareFile to Azure Blob Migration Script
# Mirrors the S:/Shared Folders directory structure to Azure Blob Storage
#
# Prerequisites:
#   - Azure CLI installed and logged in
#   - Az.Storage PowerShell module
#   - Access to S: drive (ShareFile mapped)

param(
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [string]$ContainerName = "raw",

    [string]$ShareFilePath = "S:\Shared Folders",

    [string[]]$States = @(),

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ShareFile -> Azure Blob Migration" -ForegroundColor Cyan
Write-Host "Source: $ShareFilePath" -ForegroundColor Cyan
Write-Host "Target: $StorageAccountName/$ContainerName" -ForegroundColor Cyan
if ($DryRun) { Write-Host "MODE: DRY RUN (no files will be uploaded)" -ForegroundColor Yellow }
Write-Host "========================================" -ForegroundColor Cyan

# Verify source path
if (-not (Test-Path $ShareFilePath)) {
    Write-Error "ShareFile path not accessible: $ShareFilePath"
    exit 1
}

# Get storage context
$storageKey = az storage account keys list --account-name $StorageAccountName --query "[0].value" -o tsv
$context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageKey

# Discover state directories
$stateDirs = Get-ChildItem -Path $ShareFilePath -Directory | Where-Object { $_.Name.Length -eq 2 }

if ($States.Count -gt 0) {
    $stateDirs = $stateDirs | Where-Object { $States -contains $_.Name }
}

Write-Host "`nDiscovered states: $($stateDirs.Name -join ', ')" -ForegroundColor Gray

$totalFiles = 0
$totalSize = 0

foreach ($stateDir in $stateDirs) {
    $state = $stateDir.Name.ToLower()
    $uploadsPath = Join-Path $stateDir.FullName "cfsr\uploads"

    if (-not (Test-Path $uploadsPath)) {
        Write-Host "  [$state] No cfsr/uploads directory, skipping" -ForegroundColor Yellow
        continue
    }

    Write-Host "`n[$state] Processing..." -ForegroundColor Green

    # Find all period directories
    $periodDirs = Get-ChildItem -Path $uploadsPath -Directory | Where-Object { $_.Name -match '^\d{4}_\d{2}$' }

    foreach ($periodDir in $periodDirs) {
        $period = $periodDir.Name
        Write-Host "  [$state/$period] Scanning files..." -ForegroundColor Gray

        $files = Get-ChildItem -Path $periodDir.FullName -File

        foreach ($file in $files) {
            $blobName = "$state/cfsr/uploads/$period/$($file.Name)"
            $totalFiles++
            $totalSize += $file.Length

            if ($DryRun) {
                Write-Host "    [DRY RUN] Would upload: $blobName ($([math]::Round($file.Length / 1KB, 1)) KB)" -ForegroundColor DarkGray
            } else {
                Write-Host "    Uploading: $blobName" -ForegroundColor Gray
                Set-AzStorageBlobContent `
                    -Container $ContainerName `
                    -File $file.FullName `
                    -Blob $blobName `
                    -Context $context `
                    -Force | Out-Null
            }
        }

        Write-Host "  [$state/$period] $($files.Count) files" -ForegroundColor Gray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Migration Summary:" -ForegroundColor Cyan
Write-Host "  Total files: $totalFiles" -ForegroundColor Cyan
Write-Host "  Total size: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  (DRY RUN - no files were uploaded)" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor Cyan
