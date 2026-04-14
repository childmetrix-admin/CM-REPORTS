#!/bin/bash
# ============================================================================
# ChildMetrix Azure Setup - Cloud Shell Edition
# Run this script from Azure Cloud Shell (Bash) at https://shell.azure.com
#
# Prerequisites:
#   1. Open https://shell.azure.com in your browser
#   2. Select "Bash" (not PowerShell)
#   3. Clone the repo: git clone https://github.com/childmetrix-admin/CM-REPORTS.git
#   4. cd CM-REPORTS
#   5. chmod +x infrastructure/azure/cloud-shell-setup.sh
#   6. Run phases one at a time (see usage below)
#
# Usage:
#   ./infrastructure/azure/cloud-shell-setup.sh phase1   # Register providers
#   ./infrastructure/azure/cloud-shell-setup.sh phase2   # Deploy infrastructure
#   ./infrastructure/azure/cloud-shell-setup.sh phase3   # Initialize database
#   ./infrastructure/azure/cloud-shell-setup.sh phase4   # Setup Entra auth
#   ./infrastructure/azure/cloud-shell-setup.sh phase5   # Build containers
#   ./infrastructure/azure/cloud-shell-setup.sh phase6   # Deploy Container App
#   ./infrastructure/azure/cloud-shell-setup.sh phase7   # Deploy static site
#   ./infrastructure/azure/cloud-shell-setup.sh status    # Show all outputs
# ============================================================================

set -euo pipefail

# --- Configuration ---
ENVIRONMENT="prod"
BASE_NAME="childmetrix"
LOCATION="eastus"
RESOURCE_GROUP="rg-${BASE_NAME}-${ENVIRONMENT}"

# Derived names (must match main.bicep naming)
SUFFIX="${BASE_NAME}-${ENVIRONMENT}"
STORAGE_NAME="st${BASE_NAME}${ENVIRONMENT}"
SQL_SERVER_NAME="sql-${SUFFIX}"
SQL_DB_NAME="sqldb-${SUFFIX}"
KV_NAME="kv-${SUFFIX}"
ACR_NAME="acr${BASE_NAME}${ENVIRONMENT}"
CAE_NAME="cae-${SUFFIX}"
SWA_NAME="swa-${SUFFIX}"
CA_SHINYPROXY="ca-shinyproxy-${ENVIRONMENT}"

CONFIG_FILE="${HOME}/.childmetrix-${ENVIRONMENT}.env"

save_config() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE"
    else
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# ============================================================================
# PHASE 1: Register Resource Providers
# ============================================================================
phase1() {
    echo "========================================"
    echo "Phase 1: Register Azure Resource Providers"
    echo "========================================"

    providers=(
        "Microsoft.App"
        "Microsoft.Web"
        "Microsoft.Sql"
        "Microsoft.KeyVault"
        "Microsoft.ContainerRegistry"
        "Microsoft.OperationalInsights"
        "Microsoft.Insights"
        "Microsoft.Storage"
    )

    for provider in "${providers[@]}"; do
        echo "Registering ${provider}..."
        az provider register --namespace "$provider" --wait 2>/dev/null || true
    done

    echo ""
    echo "Verifying registration status..."
    for provider in "${providers[@]}"; do
        state=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
        echo "  ${provider}: ${state}"
    done

    echo ""
    echo "Phase 1 complete. Run: ./infrastructure/azure/cloud-shell-setup.sh phase2"
}

# ============================================================================
# PHASE 2: Deploy Core Infrastructure (Bicep)
# ============================================================================
phase2() {
    echo "========================================"
    echo "Phase 2: Deploy Azure Infrastructure"
    echo "Resource Group: ${RESOURCE_GROUP}"
    echo "Location: ${LOCATION}"
    echo "========================================"

    read -p "SQL Admin Username: " SQL_USER
    read -sp "SQL Admin Password: " SQL_PASS
    echo ""

    echo ""
    echo "[1/2] Creating resource group..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o none

    echo "[2/2] Deploying Bicep template (this takes 3-5 minutes)..."
    az deployment group create \
        --resource-group "$RESOURCE_GROUP" \
        --template-file infrastructure/azure/main.bicep \
        --parameters environment="$ENVIRONMENT" \
                     sqlAdminUser="$SQL_USER" \
                     sqlAdminPassword="$SQL_PASS" \
        --name "main" \
        -o none

    echo ""
    echo "Capturing deployment outputs..."
    OUTPUTS=$(az deployment group show -g "$RESOURCE_GROUP" -n main \
        --query "properties.outputs" -o json)

    STORAGE_ACCOUNT=$(echo "$OUTPUTS" | jq -r '.storageAccountName.value')
    BLOB_ENDPOINT=$(echo "$OUTPUTS" | jq -r '.storageBlobEndpoint.value')
    SQL_FQDN=$(echo "$OUTPUTS" | jq -r '.sqlServerFqdn.value')
    SQL_DBNAME=$(echo "$OUTPUTS" | jq -r '.sqlDatabaseName.value')
    KV_URI=$(echo "$OUTPUTS" | jq -r '.keyVaultUri.value')
    ACR_LOGIN=$(echo "$OUTPUTS" | jq -r '.containerRegistryLoginServer.value')
    CAE_ID=$(echo "$OUTPUTS" | jq -r '.containerAppsEnvironmentId.value')
    SWA_URL=$(echo "$OUTPUTS" | jq -r '.staticWebAppUrl.value')
    AI_KEY=$(echo "$OUTPUTS" | jq -r '.appInsightsKey.value')

    save_config "STORAGE_ACCOUNT" "$STORAGE_ACCOUNT"
    save_config "BLOB_ENDPOINT" "$BLOB_ENDPOINT"
    save_config "SQL_FQDN" "$SQL_FQDN"
    save_config "SQL_DBNAME" "$SQL_DBNAME"
    save_config "SQL_USER" "$SQL_USER"
    save_config "SQL_PASS" "$SQL_PASS"
    save_config "KV_URI" "$KV_URI"
    save_config "ACR_LOGIN" "$ACR_LOGIN"
    save_config "CAE_ID" "$CAE_ID"
    save_config "SWA_URL" "$SWA_URL"
    save_config "AI_KEY" "$AI_KEY"

    echo ""
    echo "========================================"
    echo "Infrastructure deployed successfully!"
    echo "========================================"
    echo "Storage Account:    ${STORAGE_ACCOUNT}"
    echo "Blob Endpoint:      ${BLOB_ENDPOINT}"
    echo "SQL Server:         ${SQL_FQDN}"
    echo "SQL Database:       ${SQL_DBNAME}"
    echo "Key Vault:          ${KV_URI}"
    echo "ACR Login Server:   ${ACR_LOGIN}"
    echo "Static Web App URL: ${SWA_URL}"
    echo ""
    echo "Config saved to ${CONFIG_FILE}"
    echo "Run: ./infrastructure/azure/cloud-shell-setup.sh phase3"
}

# ============================================================================
# PHASE 3: Initialize Database
# ============================================================================
phase3() {
    echo "========================================"
    echo "Phase 3: Initialize SQL Database"
    echo "========================================"
    load_config

    if [ -z "${SQL_FQDN:-}" ]; then
        echo "ERROR: Run phase2 first. Config not found."
        exit 1
    fi

    echo "[1/3] Adding Cloud Shell IP to SQL firewall..."
    MY_IP=$(curl -s ifconfig.me)
    az sql server firewall-rule create \
        -g "$RESOURCE_GROUP" \
        -s "$SQL_SERVER_NAME" \
        -n "CloudShell-$(date +%s)" \
        --start-ip-address "$MY_IP" \
        --end-ip-address "$MY_IP" \
        -o none

    echo "[2/3] Running schema.sql..."
    sqlcmd -S "$SQL_FQDN" -d "$SQL_DBNAME" \
        -U "$SQL_USER" -P "$SQL_PASS" \
        -i infrastructure/sql/schema.sql \
        -C

    echo "[3/3] Running seed.sql..."
    sqlcmd -S "$SQL_FQDN" -d "$SQL_DBNAME" \
        -U "$SQL_USER" -P "$SQL_PASS" \
        -i infrastructure/sql/seed.sql \
        -C

    echo ""
    echo "Database initialized. Verifying tables..."
    sqlcmd -S "$SQL_FQDN" -d "$SQL_DBNAME" \
        -U "$SQL_USER" -P "$SQL_PASS" \
        -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES ORDER BY TABLE_NAME" \
        -C

    echo ""
    echo "Phase 3 complete. Run: ./infrastructure/azure/cloud-shell-setup.sh phase4"
}

# ============================================================================
# PHASE 4: Entra ID App Registration
# ============================================================================
phase4() {
    echo "========================================"
    echo "Phase 4: Entra ID App Registration"
    echo "========================================"
    load_config

    TENANT_ID=$(az account show --query tenantId -o tsv)
    SWA_HOSTNAME="${SWA_URL:-}"

    if [ -z "$SWA_HOSTNAME" ]; then
        echo "ERROR: Run phase2 first. SWA_URL not found."
        exit 1
    fi

    REDIRECT_BASE="https://${SWA_HOSTNAME}"
    echo "Tenant ID:    ${TENANT_ID}"
    echo "Redirect URL: ${REDIRECT_BASE}"

    echo ""
    echo "[1/4] Creating app registration..."
    APP_RESULT=$(az ad app create \
        --display-name "ChildMetrix Reports (${ENVIRONMENT})" \
        --sign-in-audience "AzureADMyOrg" \
        --web-redirect-uris "${REDIRECT_BASE}/.auth/login/aad/callback" \
        --enable-id-token-issuance true \
        --enable-access-token-issuance true \
        --query "{appId: appId, objectId: id}" -o json)

    APP_ID=$(echo "$APP_RESULT" | jq -r '.appId')
    APP_OBJ_ID=$(echo "$APP_RESULT" | jq -r '.objectId')
    echo "  App ID: ${APP_ID}"

    echo ""
    echo "[2/4] Adding app roles..."
    ROLE1_ID=$(uuidgen)
    ROLE2_ID=$(uuidgen)
    ROLE3_ID=$(uuidgen)
    ROLE4_ID=$(uuidgen)

    az ad app update --id "$APP_ID" \
        --app-roles "[
            {\"allowedMemberTypes\":[\"User\"],\"displayName\":\"Super Admin\",\"id\":\"${ROLE1_ID}\",\"isEnabled\":true,\"description\":\"Full platform access\",\"value\":\"super_admin\"},
            {\"allowedMemberTypes\":[\"User\"],\"displayName\":\"State Admin\",\"id\":\"${ROLE2_ID}\",\"isEnabled\":true,\"description\":\"Manage assigned states\",\"value\":\"admin\"},
            {\"allowedMemberTypes\":[\"User\"],\"displayName\":\"State Manager\",\"id\":\"${ROLE3_ID}\",\"isEnabled\":true,\"description\":\"View and upload for assigned states\",\"value\":\"manager\"},
            {\"allowedMemberTypes\":[\"User\"],\"displayName\":\"State Viewer\",\"id\":\"${ROLE4_ID}\",\"isEnabled\":true,\"description\":\"View reports for assigned states\",\"value\":\"viewer\"}
        ]"
    echo "  4 roles created"

    echo ""
    echo "[3/4] Creating service principal..."
    az ad sp create --id "$APP_ID" -o none 2>/dev/null || true
    echo "  Service principal created"

    echo ""
    echo "[4/4] Creating client secret..."
    SECRET_RESULT=$(az ad app credential reset \
        --id "$APP_ID" \
        --display-name "cloud-shell-setup" \
        --years 2 \
        --query "{password: password}" -o json)
    CLIENT_SECRET=$(echo "$SECRET_RESULT" | jq -r '.password')

    save_config "TENANT_ID" "$TENANT_ID"
    save_config "APP_ID" "$APP_ID"
    save_config "APP_OBJ_ID" "$APP_OBJ_ID"
    save_config "CLIENT_SECRET" "$CLIENT_SECRET"

    echo ""
    echo "========================================"
    echo "Entra ID Setup Complete"
    echo "========================================"
    echo "AZURE_TENANT_ID=${TENANT_ID}"
    echo "AZURE_CLIENT_ID=${APP_ID}"
    echo "AZURE_CLIENT_SECRET=${CLIENT_SECRET}"
    echo "AZURE_AUTHORITY=https://login.microsoftonline.com/${TENANT_ID}"
    echo ""
    echo "IMPORTANT: Save the client secret now! It won't be shown again."
    echo ""
    echo "Config saved to ${CONFIG_FILE}"
    echo "Run: ./infrastructure/azure/cloud-shell-setup.sh phase5"
}

# ============================================================================
# PHASE 5: Build & Push Docker Images (using ACR Build - no local Docker)
# ============================================================================
phase5() {
    echo "========================================"
    echo "Phase 5: Build Docker Images in ACR"
    echo "========================================"
    load_config

    ACR="${ACR_NAME}"
    echo "Building images in Azure Container Registry: ${ACR}"
    echo "This builds remotely - no local Docker needed."
    echo ""

    echo "[1/4] Building cm-extraction..."
    az acr build \
        --registry "$ACR" \
        --image cm-extraction:latest \
        --file infrastructure/docker/extraction/Dockerfile \
        . \
        --no-logs 2>/dev/null || \
    az acr build \
        --registry "$ACR" \
        --image cm-extraction:latest \
        --file infrastructure/docker/extraction/Dockerfile \
        .
    echo "  cm-extraction built."

    echo ""
    echo "[2/4] Building cm-app-measures..."
    az acr build \
        --registry "$ACR" \
        --image cm-app-measures:latest \
        --file infrastructure/docker/shiny/app_measures/Dockerfile \
        . \
        --no-logs 2>/dev/null || \
    az acr build \
        --registry "$ACR" \
        --image cm-app-measures:latest \
        --file infrastructure/docker/shiny/app_measures/Dockerfile \
        .
    echo "  cm-app-measures built."

    echo ""
    echo "[3/4] Building cm-app-summary..."
    az acr build \
        --registry "$ACR" \
        --image cm-app-summary:latest \
        --file infrastructure/docker/shiny/app_summary/Dockerfile \
        . \
        --no-logs 2>/dev/null || \
    az acr build \
        --registry "$ACR" \
        --image cm-app-summary:latest \
        --file infrastructure/docker/shiny/app_summary/Dockerfile \
        .
    echo "  cm-app-summary built."

    echo ""
    echo "[4/4] Building cm-shinyproxy..."
    az acr build \
        --registry "$ACR" \
        --image cm-shinyproxy:latest \
        --file infrastructure/docker/shinyproxy/Dockerfile \
        infrastructure/docker/shinyproxy/
    echo "  cm-shinyproxy built."

    echo ""
    echo "Verifying images in registry..."
    az acr repository list --name "$ACR" -o table

    echo ""
    echo "Phase 5 complete. Run: ./infrastructure/azure/cloud-shell-setup.sh phase6"
}

# ============================================================================
# PHASE 6: Deploy Container App (ShinyProxy)
# ============================================================================
phase6() {
    echo "========================================"
    echo "Phase 6: Deploy ShinyProxy Container App"
    echo "========================================"
    load_config

    ACR="${ACR_NAME}"
    ACR_SERVER="${ACR_LOGIN:-${ACR}.azurecr.io}"
    ACR_PASS=$(az acr credential show --name "$ACR" --query "passwords[0].value" -o tsv)

    STORAGE_KEY=$(az storage account keys list \
        --account-name "$STORAGE_ACCOUNT" \
        -g "$RESOURCE_GROUP" \
        --query "[0].value" -o tsv)

    echo "[1/2] Creating Container App..."
    az containerapp create \
        --name "$CA_SHINYPROXY" \
        --resource-group "$RESOURCE_GROUP" \
        --environment "$CAE_NAME" \
        --image "${ACR_SERVER}/cm-shinyproxy:latest" \
        --registry-server "$ACR_SERVER" \
        --registry-username "$ACR" \
        --registry-password "$ACR_PASS" \
        --target-port 8080 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 3 \
        --cpu 1.0 \
        --memory 2.0Gi \
        --env-vars \
            "AZURE_AUTHORITY=https://login.microsoftonline.com/${TENANT_ID:-}" \
            "AZURE_CLIENT_ID=${APP_ID:-}" \
            "AZURE_CLIENT_SECRET=${CLIENT_SECRET:-}" \
            "ACR_LOGIN_SERVER=${ACR_SERVER}" \
            "AZURE_BLOB_ENDPOINT=${BLOB_ENDPOINT:-}" \
            "AZURE_STORAGE_KEY=${STORAGE_KEY}" \
        -o none

    echo "[2/2] Getting Container App URL..."
    CA_FQDN=$(az containerapp show \
        -n "$CA_SHINYPROXY" \
        -g "$RESOURCE_GROUP" \
        --query "properties.configuration.ingress.fqdn" -o tsv)

    save_config "CA_FQDN" "$CA_FQDN"
    save_config "STORAGE_KEY" "$STORAGE_KEY"

    echo ""
    echo "========================================"
    echo "Container App deployed!"
    echo "URL: https://${CA_FQDN}"
    echo "========================================"
    echo ""
    echo "Run: ./infrastructure/azure/cloud-shell-setup.sh phase7"
}

# ============================================================================
# PHASE 7: Deploy Static Web App
# ============================================================================
phase7() {
    echo "========================================"
    echo "Phase 7: Deploy Static Web App"
    echo "========================================"
    load_config

    echo "[1/3] Getting SWA deployment token..."
    DEPLOY_TOKEN=$(az staticwebapp secrets list \
        --name "$SWA_NAME" \
        -g "$RESOURCE_GROUP" \
        --query "properties.apiKey" -o tsv 2>/dev/null || \
    az staticwebapp secrets list \
        --name "$SWA_NAME" \
        --query "properties.apiKey" -o tsv)

    echo "[2/3] Configuring SWA application settings..."
    az staticwebapp appsettings set \
        --name "$SWA_NAME" \
        -g "$RESOURCE_GROUP" \
        --setting-names \
            "AZURE_CLIENT_ID=${APP_ID:-}" \
            "AZURE_CLIENT_SECRET=${CLIENT_SECRET:-}" \
        -o none 2>/dev/null || true

    echo "[3/3] Deploying static site..."
    if command -v swa &>/dev/null; then
        swa deploy . --deployment-token "$DEPLOY_TOKEN" --env "$ENVIRONMENT"
    else
        npm install -g @azure/static-web-apps-cli
        swa deploy . --deployment-token "$DEPLOY_TOKEN" --env "$ENVIRONMENT"
    fi

    echo ""
    echo "========================================"
    echo "Static site deployed!"
    echo "URL: https://${SWA_URL}"
    echo "========================================"
}

# ============================================================================
# STATUS: Show all deployment outputs
# ============================================================================
show_status() {
    echo "========================================"
    echo "ChildMetrix Azure Deployment Status"
    echo "Environment: ${ENVIRONMENT}"
    echo "========================================"

    load_config

    echo ""
    echo "--- Resource Group ---"
    az group show --name "$RESOURCE_GROUP" --query "{name:name, location:location, state:properties.provisioningState}" -o table 2>/dev/null || echo "Not created yet"

    echo ""
    echo "--- All Resources ---"
    az resource list -g "$RESOURCE_GROUP" --query "[].{Name:name, Type:type, Location:location}" -o table 2>/dev/null || echo "No resources"

    echo ""
    echo "--- Saved Configuration ---"
    if [ -f "$CONFIG_FILE" ]; then
        echo "(from ${CONFIG_FILE})"
        grep -v "PASS\|SECRET" "$CONFIG_FILE" || true
        echo ""
        echo "(sensitive values hidden: SQL_PASS, CLIENT_SECRET)"
    else
        echo "No config file yet. Run phase2 first."
    fi

    echo ""
    echo "--- Container Images ---"
    az acr repository list --name "$ACR_NAME" -o table 2>/dev/null || echo "ACR not ready or no images"

    echo ""
    echo "--- Endpoints ---"
    echo "Static Web App: https://${SWA_URL:-not-deployed}"
    echo "Container App:  https://${CA_FQDN:-not-deployed}"
    echo "SQL Server:     ${SQL_FQDN:-not-deployed}"
    echo "Key Vault:      ${KV_URI:-not-deployed}"
}

# ============================================================================
# Main dispatcher
# ============================================================================
case "${1:-help}" in
    phase1) phase1 ;;
    phase2) phase2 ;;
    phase3) phase3 ;;
    phase4) phase4 ;;
    phase5) phase5 ;;
    phase6) phase6 ;;
    phase7) phase7 ;;
    status) show_status ;;
    *)
        echo "ChildMetrix Azure Setup - Cloud Shell Edition"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands (run in order):"
        echo "  phase1   Register Azure resource providers"
        echo "  phase2   Deploy infrastructure (Bicep: Storage, SQL, ACR, etc.)"
        echo "  phase3   Initialize SQL database (schema + seed)"
        echo "  phase4   Setup Entra ID authentication"
        echo "  phase5   Build Docker images in ACR (no local Docker needed)"
        echo "  phase6   Deploy ShinyProxy as Container App"
        echo "  phase7   Deploy static website"
        echo "  status   Show deployment status and all outputs"
        echo ""
        echo "Before starting:"
        echo "  1. Open https://shell.azure.com"
        echo "  2. Select Bash"
        echo "  3. git clone https://github.com/childmetrix-admin/CM-REPORTS.git"
        echo "  4. cd CM-REPORTS"
        echo "  5. chmod +x infrastructure/azure/cloud-shell-setup.sh"
        ;;
esac
