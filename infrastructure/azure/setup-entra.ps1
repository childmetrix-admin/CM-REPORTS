# ChildMetrix - Azure Entra External ID Setup
# Configures authentication, user flows, roles, and app registrations
#
# Prerequisites:
#   - Azure CLI installed and logged in
#   - Microsoft Graph PowerShell module (Install-Module Microsoft.Graph)
#   - Entra External ID tenant created

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,

    [Parameter(Mandatory=$true)]
    [string]$Environment,

    [string]$RedirectUri = "https://childmetrix.com"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ChildMetrix Entra External ID Setup" -ForegroundColor Cyan
Write-Host "Tenant: $TenantId" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Register the ChildMetrix web application
Write-Host "`n[1/5] Registering application..." -ForegroundColor Yellow

$appRegistration = az ad app create `
    --display-name "ChildMetrix Reports ($Environment)" `
    --sign-in-audience "AzureADandPersonalMicrosoftAccount" `
    --web-redirect-uris "$RedirectUri/auth/callback" "$RedirectUri/auth/silent" `
    --enable-id-token-issuance true `
    --enable-access-token-issuance true `
    --query "{appId: appId, objectId: id}" -o json | ConvertFrom-Json

Write-Host "  App ID: $($appRegistration.appId)" -ForegroundColor Gray

# Step 2: Define application roles
Write-Host "`n[2/5] Defining application roles..." -ForegroundColor Yellow

$roles = @(
    @{ displayName = "Super Admin"; value = "super_admin"; description = "Full platform access, all states, user management" }
    @{ displayName = "State Admin"; value = "admin"; description = "Manage users and upload data for assigned states" }
    @{ displayName = "State Manager"; value = "manager"; description = "View reports and upload data for assigned states" }
    @{ displayName = "State Viewer"; value = "viewer"; description = "View reports for assigned states" }
)

foreach ($role in $roles) {
    $roleId = [guid]::NewGuid().ToString()
    az ad app update --id $appRegistration.appId `
        --app-roles "[{
            \`"allowedMemberTypes\`": [\`"User\`"],
            \`"displayName\`": \`"$($role.displayName)\`",
            \`"id\`": \`"$roleId\`",
            \`"isEnabled\`": true,
            \`"description\`": \`"$($role.description)\`",
            \`"value\`": \`"$($role.value)\`"
        }]"
    Write-Host "  Created role: $($role.displayName) ($($role.value))" -ForegroundColor Gray
}

# Step 3: Configure optional claims for state access
Write-Host "`n[3/5] Configuring optional claims..." -ForegroundColor Yellow
Write-Host "  Custom claims (assigned_states) will be added via claims mapping policy" -ForegroundColor Gray

# Step 4: Create service principal
Write-Host "`n[4/5] Creating service principal..." -ForegroundColor Yellow

az ad sp create --id $appRegistration.appId
Write-Host "  Service principal created" -ForegroundColor Gray

# Step 5: Output configuration
Write-Host "`n[5/5] Configuration summary" -ForegroundColor Yellow

$config = @{
    tenantId = $TenantId
    clientId = $appRegistration.appId
    authority = "https://login.microsoftonline.com/$TenantId"
    redirectUri = "$RedirectUri/auth/callback"
    scopes = @("openid", "profile", "email")
    roles = @("super_admin", "admin", "manager", "viewer")
}

Write-Host "`nAdd this to your .env file:" -ForegroundColor Green
Write-Host "AZURE_TENANT_ID=$TenantId"
Write-Host "AZURE_CLIENT_ID=$($appRegistration.appId)"
Write-Host "AZURE_AUTHORITY=https://login.microsoftonline.com/$TenantId"
Write-Host "AZURE_REDIRECT_URI=$RedirectUri/auth/callback"

$config | ConvertTo-Json | Out-File "$PSScriptRoot\entra-config-$Environment.json"
Write-Host "`nConfig saved to entra-config-$Environment.json" -ForegroundColor Green
