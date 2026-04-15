#!/usr/bin/env bash
# ChildMetrix — Azure CLI (bash) flow for rg-childmetrix-prod
# Run in Azure Cloud Shell (bash) or Git Bash after: az login
# Usage: bash infrastructure/azure/cloud-shell-all-in-one.sh
set -euo pipefail

# --- 0) Your subscription (change if needed) ---
# Set subscription by name OR id: export SUBSCRIPTION="<id-or-exact-name>"
SUBSCRIPTION="${SUBSCRIPTION:-Azure subscription 1}"
RG="rg-childmetrix-prod"
STORAGE_ACCOUNT="stchildmetrixprod"
ACR_NAME="acrchildmetrixprod"
SWA_NAME="swa-childmetrix-prod"
CA_MEASURES="ca-app-measures"
CA_SUMMARY="ca-app-summary"

echo "=== 1) Login & subscription ==="
az account show -o table 2>/dev/null || az login -o table
az account set --subscription "$SUBSCRIPTION"
az account show --query "{name:name,id:id}" -o table

echo "=== 2) Ensure Container Apps extension ==="
az extension add --name containerapp --upgrade --yes 2>/dev/null || true

echo "=== 3) Read storage blob endpoint + key (same account Bicep created) ==="
BLOB_ENDPOINT="$(az storage account show -g "$RG" -n "$STORAGE_ACCOUNT" --query primaryEndpoints.blob -o tsv)"
STORAGE_KEY="$(az storage account keys list -g "$RG" -n "$STORAGE_ACCOUNT" --query '[0].value' -o tsv)"
ACR_LOGIN_SERVER="$(az acr show -g "$RG" -n "$ACR_NAME" --query loginServer -o tsv)"

echo "Blob endpoint: $BLOB_ENDPOINT"
echo "ACR login:     $ACR_LOGIN_SERVER  (use this in GitHub Actions ACR_LOGIN_SERVER)"

echo "=== 4) Push env vars to BOTH Shiny Container Apps (processed RDS in Blob) ==="
for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  echo "-- Updating $CA --"
  az containerapp update \
    --name "$CA" \
    --resource-group "$RG" \
    --set-env-vars \
      "AZURE_BLOB_ENDPOINT=$BLOB_ENDPOINT" \
      "AZURE_STORAGE_KEY=$STORAGE_KEY" \
      "AZURE_BLOB_CONTAINER_RAW=raw" \
      "AZURE_BLOB_CONTAINER_PROCESSED=processed" \
      "CM_REPORTS_ROOT=/app"
done

echo "=== 5) URLs to open in browser ==="
echo "Static Web App (main HTML site):"
# CLI versions differ: hostname may be defaultHostname (root) or under properties
SWA_HOST="$(az staticwebapp show -g "$RG" -n "$SWA_NAME" --query "defaultHostname" -o tsv 2>/dev/null || true)"
if [[ -z "${SWA_HOST:-}" ]]; then
  SWA_HOST="$(az staticwebapp show -g "$RG" -n "$SWA_NAME" --query "properties.defaultHostname" -o tsv 2>/dev/null || true)"
fi
if [[ -z "${SWA_HOST:-}" ]]; then
  SWA_HOST="$(az staticwebapp list -g "$RG" --query "[?name=='$SWA_NAME'].defaultHostname | [0]" -o tsv 2>/dev/null || true)"
fi
if [[ -z "${SWA_HOST:-}" ]]; then
  SWA_HOST="$(az resource show -g "$RG" --resource-type "Microsoft.Web/staticSites" -n "$SWA_NAME" \
    --query "properties.defaultHostname" -o tsv 2>/dev/null || true)"
fi
if [[ -n "${SWA_HOST:-}" ]]; then
  echo "  https://${SWA_HOST}"
else
  echo "  (could not resolve — run: az staticwebapp show -g $RG -n $SWA_NAME -o json)"
  echo "  See docs/AZURE_NEXT_STEPS.md section 1"
fi

echo "Container App FQDNs (Shiny):"
for CA in "$CA_MEASURES" "$CA_SUMMARY"; do
  FQDN="$(az containerapp show -g "$RG" -n "$CA" --query "properties.configuration.ingress.fqdn" -o tsv)"
  echo "  https://${FQDN}"
done

echo "=== Done ==="
echo "Next: deploy static files to SWA, ACR builds, Entra — see docs/AZURE_NEXT_STEPS.md"
echo "Tip: If you use Entra login on SWA, set app settings AZURE_CLIENT_ID / AZURE_CLIENT_SECRET on the Static Web App to match staticwebapp.config.json."
