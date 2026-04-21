#!/bin/bash
# Build PPT generator container in ACR and run as Container Instance
#
# Usage: ./build-and-run-ppt.sh [state] [period1] [period2] ...
# Example: ./build-and-run-ppt.sh md 2025_02 2025_08 2026_02

set -e

# Configuration
ACR_NAME="acrchildmetrixprod"
RESOURCE_GROUP="rg-childmetrix-prod"
IMAGE_NAME="cm-ppt-generator"
STORAGE_ACCOUNT="stchildmetrixprod"

STATE="${1:-md}"
shift
PERIODS="${@:-2025_02 2025_08 2026_02}"

echo "=============================================="
echo "ChildMetrix PPT Generator - Build & Run"
echo "=============================================="
echo "ACR: $ACR_NAME"
echo "State: $STATE"
echo "Periods: $PERIODS"
echo ""

# Get storage key
echo "Getting storage account key..."
STORAGE_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT \
  --query "[0].value" -o tsv)

# Build image using ACR Tasks
echo "Building container image in ACR..."
cd ~/cm-reports

az acr build \
  --registry $ACR_NAME \
  --image $IMAGE_NAME:latest \
  --file infrastructure/docker/ppt-generator/Dockerfile \
  .

echo ""
echo "Image built: $ACR_NAME.azurecr.io/$IMAGE_NAME:latest"
echo ""

# Get ACR credentials
ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

# Run as Container Instance
CONTAINER_NAME="ppt-generator-$(date +%Y%m%d-%H%M%S)"

echo "Running container instance: $CONTAINER_NAME"
echo ""

az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image "$ACR_LOGIN_SERVER/$IMAGE_NAME:latest" \
  --registry-login-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --os-type Linux \
  --cpu 2 \
  --memory 4 \
  --restart-policy Never \
  --environment-variables \
    AZURE_BLOB_ENDPOINT="https://$STORAGE_ACCOUNT.blob.core.windows.net" \
    AZURE_STORAGE_KEY="$STORAGE_KEY" \
    AZURE_BLOB_CONTAINER_PROCESSED="processed" \
    CM_PUBLIC_MEASURES_URL="https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io" \
    CM_PUBLIC_SUMMARY_URL="https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io" \
  --command-line "Rscript /app/generate_all.R $STATE $PERIODS"

echo ""
echo "Container started. Streaming logs..."
echo ""

# Wait and show logs
az container logs \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --follow

# Check exit status
STATUS=$(az container show \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --query "containers[0].instanceView.currentState.exitCode" -o tsv)

echo ""
if [ "$STATUS" == "0" ]; then
  echo "SUCCESS! PPT files generated and uploaded to blob storage."
  echo ""
  echo "Files are at: https://$STORAGE_ACCOUNT.blob.core.windows.net/processed/$STATE/cfsr/presentations/"
else
  echo "FAILED with exit code: $STATUS"
  exit 1
fi

# Cleanup container
echo "Cleaning up container instance..."
az container delete --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --yes

echo "Done!"
