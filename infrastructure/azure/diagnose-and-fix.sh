#!/usr/bin/env bash
# ChildMetrix — Complete Diagnosis and Fix Script for Azure Production
# Run in Azure Cloud Shell (bash): bash infrastructure/azure/diagnose-and-fix.sh
# This script diagnoses issues and fixes them step by step
set -euo pipefail

# ============================================================
# CONFIGURATION
# ============================================================
SUBSCRIPTION="${SUBSCRIPTION:-Azure subscription 1}"
RG="rg-childmetrix-prod"
STORAGE_ACCOUNT="stchildmetrixprod"
ACR_NAME="acrchildmetrixprod"
SWA_NAME="swa-childmetrix-prod"
CA_MEASURES="ca-app-measures"
CA_SUMMARY="ca-app-summary"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
echo_ok() { echo -e "${GREEN}✓ $1${NC}"; }
echo_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
echo_error() { echo -e "${RED}✗ $1${NC}"; }
echo_info() { echo -e "  $1"; }

# ============================================================
# PHASE 0: LOGIN AND SETUP
# ============================================================
echo_header "Phase 0: Login and Setup"

az account show -o table 2>/dev/null || az login -o table
az account set --subscription "$SUBSCRIPTION"
echo_ok "Subscription set: $(az account show --query name -o tsv)"

# Install containerapp extension if needed
az extension add --name containerapp --upgrade --yes 2>/dev/null || true
echo_ok "Container Apps extension ready"

# ============================================================
# PHASE 1: DIAGNOSIS
# ============================================================
echo_header "Phase 1: Diagnosis"

# 1.1 Check if Docker images exist in ACR
echo -e "\n${YELLOW}1.1 Checking ACR for Docker images...${NC}"
ACR_IMAGES=$(az acr repository list --name "$ACR_NAME" -o tsv 2>/dev/null || echo "")
if [[ -z "$ACR_IMAGES" ]]; then
  echo_error "ACR is empty - no images found"
  NEED_BUILD_IMAGES=true
else
  echo_info "Images in ACR:"
  echo "$ACR_IMAGES" | while read img; do echo_info "  - $img"; done
  
  if echo "$ACR_IMAGES" | grep -q "cm-app-measures"; then
    echo_ok "cm-app-measures image exists"
    NEED_BUILD_MEASURES=false
  else
    echo_warn "cm-app-measures image MISSING"
    NEED_BUILD_MEASURES=true
  fi
  
  if echo "$ACR_IMAGES" | grep -q "cm-app-summary"; then
    echo_ok "cm-app-summary image exists"
    NEED_BUILD_SUMMARY=false
  else
    echo_warn "cm-app-summary image MISSING"
    NEED_BUILD_SUMMARY=true
  fi
  
  NEED_BUILD_IMAGES=${NEED_BUILD_MEASURES:-false}
fi

# 1.2 Check Container Apps status
echo -e "\n${YELLOW}1.2 Checking Container Apps status...${NC}"
for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  STATUS=$(az containerapp show -g "$RG" -n "$CA" --query "properties.runningStatus" -o tsv 2>/dev/null || echo "NOT_FOUND")
  if [[ "$STATUS" == "NOT_FOUND" ]]; then
    echo_error "$CA: Container App does not exist"
  else
    echo_info "$CA status: $STATUS"
  fi
done

# 1.3 Check Container Apps environment variables
echo -e "\n${YELLOW}1.3 Checking Container Apps environment variables...${NC}"
NEED_ENV_VARS=false
for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  ENV_VARS=$(az containerapp show -g "$RG" -n "$CA" --query "properties.template.containers[0].env[].name" -o tsv 2>/dev/null || echo "")
  if [[ -z "$ENV_VARS" ]]; then
    echo_warn "$CA: No environment variables set"
    NEED_ENV_VARS=true
  else
    if echo "$ENV_VARS" | grep -q "AZURE_BLOB_ENDPOINT"; then
      echo_ok "$CA: AZURE_BLOB_ENDPOINT is set"
    else
      echo_warn "$CA: AZURE_BLOB_ENDPOINT is MISSING"
      NEED_ENV_VARS=true
    fi
    if echo "$ENV_VARS" | grep -q "AZURE_STORAGE_KEY"; then
      echo_ok "$CA: AZURE_STORAGE_KEY is set"
    else
      echo_warn "$CA: AZURE_STORAGE_KEY is MISSING"
      NEED_ENV_VARS=true
    fi
  fi
done

# 1.4 Check blob storage for processed data
echo -e "\n${YELLOW}1.4 Checking blob storage for processed RDS data...${NC}"
BLOB_COUNT=$(az storage blob list \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name processed \
  --query "length(@)" -o tsv --auth-mode login 2>/dev/null || echo "0")

if [[ "$BLOB_COUNT" == "0" ]]; then
  echo_warn "No processed data in blob storage - Shiny apps will fail to load data"
  NEED_DATA=true
else
  echo_ok "Found $BLOB_COUNT blobs in processed container"
  echo_info "Sample files:"
  az storage blob list \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name processed \
    --query "[0:5].name" -o tsv --auth-mode login 2>/dev/null | while read blob; do
    echo_info "  - $blob"
  done
  NEED_DATA=false
fi

# 1.5 Check Container Apps logs (brief)
echo -e "\n${YELLOW}1.5 Checking recent Container Apps logs for errors...${NC}"
for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  echo_info "$CA recent logs (last 10 lines):"
  az containerapp logs show -g "$RG" -n "$CA" --tail 10 2>/dev/null | head -20 || echo_warn "  Could not retrieve logs"
done

# ============================================================
# DIAGNOSIS SUMMARY
# ============================================================
echo_header "Diagnosis Summary"
echo_info "NEED_BUILD_IMAGES: ${NEED_BUILD_IMAGES:-false}"
echo_info "NEED_ENV_VARS: $NEED_ENV_VARS"
echo_info "NEED_DATA: ${NEED_DATA:-false}"

# ============================================================
# PHASE 2: FIX DOCKER IMAGES (if needed)
# ============================================================
if [[ "${NEED_BUILD_IMAGES:-false}" == "true" || "${NEED_BUILD_MEASURES:-false}" == "true" || "${NEED_BUILD_SUMMARY:-false}" == "true" ]]; then
  echo_header "Phase 2: Building Docker Images"
  
  # Check if repo is cloned
  if [[ ! -d ~/cm-reports ]]; then
    echo_info "Cloning repository..."
    git clone https://github.com/childmetrix-admin/CM-REPORTS.git ~/cm-reports
  fi
  cd ~/cm-reports
  git pull origin main 2>/dev/null || true
  
  if [[ "${NEED_BUILD_MEASURES:-true}" == "true" ]]; then
    echo_info "Building cm-app-measures..."
    az acr build --registry "$ACR_NAME" \
      --image cm-app-measures:latest \
      -f infrastructure/docker/shiny/app_measures/Dockerfile . \
      --no-logs || echo_warn "Build may have timed out - check ACR portal"
  fi
  
  if [[ "${NEED_BUILD_SUMMARY:-true}" == "true" ]]; then
    echo_info "Building cm-app-summary..."
    az acr build --registry "$ACR_NAME" \
      --image cm-app-summary:latest \
      -f infrastructure/docker/shiny/app_summary/Dockerfile . \
      --no-logs || echo_warn "Build may have timed out - check ACR portal"
  fi
  
  echo_ok "Docker images built and pushed to ACR"
else
  echo_header "Phase 2: Docker Images OK (skipping build)"
fi

# ============================================================
# PHASE 3: SET ENVIRONMENT VARIABLES
# ============================================================
if [[ "$NEED_ENV_VARS" == "true" ]]; then
  echo_header "Phase 3: Setting Environment Variables"
else
  echo_header "Phase 3: Refreshing Environment Variables"
fi

BLOB_ENDPOINT="$(az storage account show -g "$RG" -n "$STORAGE_ACCOUNT" --query primaryEndpoints.blob -o tsv)"
STORAGE_KEY="$(az storage account keys list -g "$RG" -n "$STORAGE_ACCOUNT" --query '[0].value' -o tsv)"

echo_info "Blob endpoint: $BLOB_ENDPOINT"

for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  echo_info "Updating $CA environment variables..."
  az containerapp update \
    --name "$CA" \
    --resource-group "$RG" \
    --set-env-vars \
      "AZURE_BLOB_ENDPOINT=$BLOB_ENDPOINT" \
      "AZURE_STORAGE_KEY=$STORAGE_KEY" \
      "AZURE_BLOB_CONTAINER_RAW=raw" \
      "AZURE_BLOB_CONTAINER_PROCESSED=processed" \
      "CM_REPORTS_ROOT=/app" \
    --output none
  echo_ok "$CA environment variables set"
done

# ============================================================
# PHASE 4: VERIFY CONTAINER APPS USE CORRECT IMAGE
# ============================================================
echo_header "Phase 4: Verifying Container Apps Image References"

ACR_LOGIN_SERVER="$(az acr show -g "$RG" -n "$ACR_NAME" --query loginServer -o tsv)"
echo_info "ACR login server: $ACR_LOGIN_SERVER"

for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  CURRENT_IMAGE=$(az containerapp show -g "$RG" -n "$CA" --query "properties.template.containers[0].image" -o tsv 2>/dev/null || echo "")
  EXPECTED_IMAGE="${ACR_LOGIN_SERVER}/${CA/ca-/cm-}:latest"
  
  echo_info "$CA current image: $CURRENT_IMAGE"
  echo_info "$CA expected image: $EXPECTED_IMAGE"
  
  if [[ "$CURRENT_IMAGE" != "$EXPECTED_IMAGE" ]]; then
    echo_info "Updating $CA to use correct image..."
    az containerapp update -n "$CA" -g "$RG" \
      --image "$EXPECTED_IMAGE" \
      --output none
    echo_ok "$CA image updated"
  else
    echo_ok "$CA already using correct image"
  fi
done

# ============================================================
# PHASE 5: CHECK DATA (info only)
# ============================================================
echo_header "Phase 5: Data Status"

if [[ "${NEED_DATA:-false}" == "true" ]]; then
  echo_warn "No processed RDS data found in blob storage"
  echo_info "The Shiny apps will show errors until data is uploaded."
  echo_info ""
  echo_info "To upload data, you have several options:"
  echo_info "  Option A: Run extraction locally with R:"
  echo_info "    source('domains/cfsr/extraction/run_profile.R')"
  echo_info ""
  echo_info "  Option B: Upload existing RDS files:"
  echo_info "    az storage blob upload --account-name $STORAGE_ACCOUNT \\"
  echo_info "      --container-name processed \\"
  echo_info "      --name 'rds/md/2025_02/MD_cfsr_profile_rsp_2025_02.rds' \\"
  echo_info "      --file '/path/to/local/file.rds' --auth-mode login"
else
  echo_ok "Processed data exists in blob storage"
fi

# ============================================================
# PHASE 6: VERIFICATION
# ============================================================
echo_header "Phase 6: Verification URLs"

echo_info "Container App URLs:"
for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  FQDN="$(az containerapp show -g "$RG" -n "$CA" --query 'properties.configuration.ingress.fqdn' -o tsv 2>/dev/null || echo 'unknown')"
  echo_info "  https://${FQDN}/?state=MD&profile=latest"
done

SWA_HOST="$(az staticwebapp show -g "$RG" -n "$SWA_NAME" --query defaultHostname -o tsv 2>/dev/null || \
  az staticwebapp show -g "$RG" -n "$SWA_NAME" --query 'properties.defaultHostname' -o tsv 2>/dev/null || \
  echo 'unknown')"
echo_info ""
echo_info "Static Web App:"
echo_info "  https://${SWA_HOST}"
echo_info "  https://${SWA_HOST}/app.html?state=md#/cfsr"

# ============================================================
# FINAL STATUS
# ============================================================
echo_header "Done!"
echo_info "Container Apps have been configured with:"
echo_info "  - Environment variables (AZURE_BLOB_ENDPOINT, AZURE_STORAGE_KEY, etc.)"
echo_info "  - Correct ACR image references"
echo_info ""
echo_info "Next steps:"
echo_info "  1. Wait 1-2 minutes for containers to restart"
echo_info "  2. Open the Container App URLs above to verify Shiny apps load"
echo_info "  3. If you see 'No profiles available', upload RDS data (see Phase 5)"
echo_info "  4. Open the Static Web App URL to verify iframe embedding works"
