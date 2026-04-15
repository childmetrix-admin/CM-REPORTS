# Azure next steps after Container Apps env (prod)

Use this after your **`ca-app-measures`** / **`ca-app-summary`** blob env vars are set (see `infrastructure/azure/cloud-shell-all-in-one.sh`).

---

## 1. Why Static Web App URL was blank

`az staticwebapp show` sometimes exposes the hostname as **`defaultHostname`** (top level), not only under **`properties`**. Use one of these:

```bash
RG="rg-childmetrix-prod"
SWA_NAME="swa-childmetrix-prod"

az staticwebapp show -g "$RG" -n "$SWA_NAME" --query "defaultHostname" -o tsv
# fallback:
az staticwebapp show -g "$RG" -n "$SWA_NAME" --query "properties.defaultHostname" -o tsv
# fallback:
az resource show -g "$RG" --resource-type "Microsoft.Web/staticSites" -n "$SWA_NAME" \
  --query "properties.defaultHostname" -o tsv
```

Open `https://<hostname>` — that is the **static HTML** site (landing + state hubs).

---

## 2. Paste safety (your `for` loop broke)

If you pasted the `az containerapp update` by hand, a line can merge and **drop** the `AZURE_BLOB_CONTAINER_*` / `CM_REPORTS_ROOT` lines (you had a malformed `done ... PROCESSED` fragment). **Always run the script from the file** or paste the **entire** `for` loop without breaking lines:

```bash
bash infrastructure/azure/cloud-shell-all-in-one.sh
```

If the API still shows env entries **without `value`** in JSON, values may be **secret** (hidden). Confirm in the portal: **Container App → Application → Containers → Environment variables**, or run:

```bash
az containerapp show -g rg-childmetrix-prod -n ca-app-measures \
  --query "properties.template.containers[0].env" -o jsonc
```

---

## 3. Deploy static HTML to the Static Web App (not in the first script)

The repo root (`index.html`, `states/`, `shared/`, …) must be uploaded to **SWA**. Typical options:

### Option A — From your laptop (PowerShell or bash), with SWA CLI

```bash
npm install -g @azure/static-web-apps-cli
export RG="rg-childmetrix-prod"
export SWA_NAME="swa-childmetrix-prod"
# Deployment token (API key) — copy from Azure Portal: Static Web App → Manage deployment token
# OR:
DEPLOY_TOKEN="$(az staticwebapp secrets list --name "$SWA_NAME" --resource-group "$RG" --query "properties.apiKey" -o tsv)"
cd /path/to/CM-REPORTS
swa deploy . --deployment-token "$DEPLOY_TOKEN" --env production
```

If `az staticwebapp secrets list` fails on your CLI version, use the **Portal**: **Static Web App → Overview → Manage deployment token** and pass it to `swa deploy`.

### Option B — GitHub Actions

Connect the repo to the Static Web App in the **Azure Portal** (GitHub Actions workflow auto-generated), or use your existing pipeline to run `swa deploy` with a stored secret.

---

## 4. Rebuild and push Docker images (ACR)

Images are **`acrchildmetrixprod.azurecr.io/cm-app-measures:latest`** and **`.../cm-app-summary:latest`**.

### From your machine (Docker Desktop + `az acr login`)

```bash
cd /path/to/CM-REPORTS
az acr login --name acrchildmetrixprod
docker build -t acrchildmetrixprod.azurecr.io/cm-app-measures:latest \
  -f infrastructure/docker/shiny/app_measures/Dockerfile .
docker push acrchildmetrixprod.azurecr.io/cm-app-measures:latest
docker build -t acrchildmetrixprod.azurecr.io/cm-app-summary:latest \
  -f infrastructure/docker/shiny/app_summary/Dockerfile .
docker push acrchildmetrixprod.azurecr.io/cm-app-summary:latest
```

Then restart revisions or pull new revisions on the Container Apps (often automatic when `:latest` is used and **Continuous deployment** is enabled; otherwise create a new revision or use `az containerapp update` with `--image`).

### From GitHub

Use **Actions** → **Build and Push Docker Images to ACR** (set `ACR_USERNAME`, `ACR_PASSWORD`, and `ACR_LOGIN_SERVER` in repo secrets).

### In Azure Cloud Shell (no local Docker)

```bash
cd ~/CM-REPORTS   # if repo is cloned there
az acr build --registry acrchildmetrixprod \
  --image cm-app-measures:latest \
  -f infrastructure/docker/shiny/app_measures/Dockerfile .
az acr build --registry acrchildmetrixprod \
  --image cm-app-summary:latest \
  -f infrastructure/docker/shiny/app_summary/Dockerfile .
```

Cloud Shell can time out on large builds; CI or a dev machine is often more reliable.

---

## 5. Entra (Azure AD) for Static Web App routes

`staticwebapp.config.json` expects **Application settings** on the SWA:

| Setting | Purpose |
|---------|---------|
| `AZURE_CLIENT_ID` | App registration client ID |
| `AZURE_CLIENT_SECRET` | App registration secret |

**Portal:** Static Web App → **Configuration** → **Application settings** → Add.

Also set **`openIdIssuer`** in `staticwebapp.config.json` to your tenant (`https://login.microsoftonline.com/<TENANT_ID>/v2.0`) if you use a single-tenant app.

---

## 6. Match CFSR iframe URLs to your real Container App hostnames

Your Shiny apps are:

- `https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io`
- `https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io`

Ensure `shared/cfsr/measures/cfsr_profile_measures.html` and `shared/cfsr/summary/index.html` default URLs (or `window.CM_SHINY_CONFIG`) match these, or pass **`?shiny_base=`** on the embed URL.

---

## 7. Smoke checklist

- [ ] SWA hostname resolves (section 1) and `swa deploy` completed (section 3).
- [ ] Opening the SWA URL shows the landing page (auth may redirect to login).
- [ ] Both Container App URLs load Shiny (after blob data exists in `processed`).
- [ ] Entra app settings set if you use protected routes (section 5).
