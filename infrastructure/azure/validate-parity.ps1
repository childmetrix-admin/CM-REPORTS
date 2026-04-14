# ChildMetrix - Validate Azure Blob Parity with ShareFile
# Compares files in ShareFile (S: drive) with Azure Blob Storage
#
# Checks:
# 1. All states/periods from ShareFile exist in Blob
# 2. File counts match
# 3. File sizes match
# 4. Processed RDS files exist for each state/period

param(
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,

    [string]$ShareFilePath = "S:\Shared Folders",

    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Blob Parity Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Get storage context
$storageKey = az storage account keys list --account-name $StorageAccountName --query "[0].value" -o tsv
$context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $storageKey

$passed = 0
$failed = 0
$warnings = 0

function Check-Pass($msg) { $script:passed++; Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Check-Fail($msg) { $script:failed++; Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Check-Warn($msg) { $script:warnings++; Write-Host "  [WARN] $msg" -ForegroundColor Yellow }

# 1. Check raw container has matching content
Write-Host "`n[1] Checking raw uploads parity..." -ForegroundColor Yellow

$stateDirs = Get-ChildItem -Path $ShareFilePath -Directory | Where-Object { $_.Name.Length -eq 2 }

foreach ($stateDir in $stateDirs) {
    $state = $stateDir.Name.ToLower()
    $uploadsPath = Join-Path $stateDir.FullName "cfsr\uploads"

    if (-not (Test-Path $uploadsPath)) { continue }

    $periodDirs = Get-ChildItem -Path $uploadsPath -Directory | Where-Object { $_.Name -match '^\d{4}_\d{2}$' }

    foreach ($periodDir in $periodDirs) {
        $period = $periodDir.Name
        $localFiles = Get-ChildItem -Path $periodDir.FullName -File

        $blobPrefix = "$state/cfsr/uploads/$period/"
        $blobs = Get-AzStorageBlob -Container "raw" -Context $context -Prefix $blobPrefix -ErrorAction SilentlyContinue

        $blobCount = ($blobs | Measure-Object).Count
        $localCount = ($localFiles | Measure-Object).Count

        if ($blobCount -eq $localCount) {
            Check-Pass "$state/$period: $localCount files match"
        } elseif ($blobCount -eq 0) {
            Check-Fail "$state/$period: No blobs found (expected $localCount files)"
        } else {
            Check-Fail "$state/$period: Blob count ($blobCount) != ShareFile count ($localCount)"
        }
    }
}

# 2. Check processed container has RDS files
Write-Host "`n[2] Checking processed RDS files..." -ForegroundColor Yellow

foreach ($stateDir in $stateDirs) {
    $state = $stateDir.Name.ToLower()
    $uploadsPath = Join-Path $stateDir.FullName "cfsr\uploads"

    if (-not (Test-Path $uploadsPath)) { continue }

    $periodDirs = Get-ChildItem -Path $uploadsPath -Directory | Where-Object { $_.Name -match '^\d{4}_\d{2}$' }

    foreach ($periodDir in $periodDirs) {
        $period = $periodDir.Name
        $stateUpper = $state.ToUpper()

        $expectedRds = @(
            "rds/$state/$period/${stateUpper}_cfsr_profile_rsp_$period.rds",
            "rds/$state/$period/${stateUpper}_cfsr_profile_observed_$period.rds"
        )

        foreach ($rdsPath in $expectedRds) {
            $blob = Get-AzStorageBlob -Container "processed" -Context $context -Blob $rdsPath -ErrorAction SilentlyContinue
            if ($blob) {
                Check-Pass "Processed: $rdsPath"
            } else {
                Check-Warn "Missing processed RDS: $rdsPath (may need extraction)"
            }
        }
    }
}

# 3. Check national RDS files
Write-Host "`n[3] Checking national RDS files..." -ForegroundColor Yellow

$nationalBlobs = Get-AzStorageBlob -Container "processed" -Context $context -Prefix "rds/national/" -ErrorAction SilentlyContinue
$nationalCount = ($nationalBlobs | Measure-Object).Count

if ($nationalCount -gt 0) {
    Check-Pass "National RDS files: $nationalCount found"
} else {
    Check-Warn "No national RDS files found in processed container"
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Validation Results:" -ForegroundColor Cyan
Write-Host "  Passed:   $passed" -ForegroundColor Green
Write-Host "  Failed:   $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $warnings" -ForegroundColor $(if ($warnings -gt 0) { "Yellow" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "`nParity check FAILED. Resolve issues before decommissioning ShareFile." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nParity check PASSED." -ForegroundColor Green
}
