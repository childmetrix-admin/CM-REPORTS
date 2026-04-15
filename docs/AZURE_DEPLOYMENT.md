# GitHub (ChildMetrix) and Azure deployment

End-to-end commands to fetch the repo, push to GitHub under the ChildMetrix org, deploy Azure resources, and open the production site.

---

## 1. Security: Git remotes

- **Never** use a GitHub personal access token inside a remote URL (e.g. `https://user:TOKEN@github.com/...`). Use **Git Credential Manager**, **`gh auth login`**, or **SSH**.
- If a token was ever embedded in `git remote`, **revoke it** on GitHub and set a clean URL:

```bash
git remote set-url childmetrix https://github.com/childmetrix-admin/CM-REPORTS.git
```

Replace the org/repo if your canonical repo is different (e.g. `github.com/childmetrix/cm-reports`).

---

## 2. Clone and remotes

```bash
git clone https://github.com/childmetrix-admin/CM-REPORTS.git cm-reports
cd cm-reports
```

Typical layout when you also have a personal fork:

| Remote    | Purpose |
|-----------|---------|
| `origin`  | Your fork (optional) |
| `childmetrix` | Team org repo — **push here for production CI / shared history** |

Add the org remote if missing:

```bash
git remote add childmetrix https://github.com/childmetrix-admin/CM-REPORTS.git
git fetch childmetrix
```

Push your branch (example: `main`):

```bash
git push childmetrix main
```

Use SSH instead (recommended for automation):

```bash
git remote set-url childmetrix git@github.com:childmetrix-admin/CM-REPORTS.git
git push childmetrix main
```

---

## 3. Prerequisites on your machine

- **Azure CLI**: [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Docker** (for `deploy.ps1` image build/push)
- **Node.js + npm** (for `swa deploy` in step 6)
- Access to the Azure **subscription** and **resource group** you deploy into

Login and select subscription:

```powershell
az login
az account list -o table
az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"
```

---

## 4. One-time: GitHub Actions → Azure Container Registry

The workflow `.github/workflows/build-containers.yml` pushes images to ACR when run manually (**Actions** → **Build and Push Docker Images to ACR** → **Run workflow**).

In the GitHub repo (**Settings** → **Secrets and variables** → **Actions**), add:

| Secret | Value |
|--------|--------|
| `ACR_USERNAME` | ACR name (short name, e.g. `acrchildmetrixprod`) or admin user from `az acr credential show` |
| `ACR_PASSWORD` | Admin password from `az acr credential show` |

Edit the workflow file env `ACR_LOGIN_SERVER` so it matches your registry login server, for example:

```yaml
env:
  ACR_LOGIN_SERVER: <your-registry>.azurecr.io
```

Get the login server after infra exists:

```powershell
az acr list -g rg-childmetrix-prod --query "[].loginServer" -o tsv
```

(Replace `rg-childmetrix-prod` with your resource group.)

---

## 5. Deploy infrastructure, images, Container App, and static site

From the repo root, run the script (PowerShell). Adjust names to match your environment.

```powershell
cd infrastructure\azure
.\deploy.ps1 -Environment prod -ResourceGroup rg-childmetrix-prod -Location southcentralus
```

What it does (see `deploy.ps1`):

1. **Bicep** (`main.bicep`): storage (blob containers `raw` / `processed`), SQL, Key Vault, ACR, Container Apps environment, Static Web App, etc.
2. **Docker build + push** to ACR: extraction, `app_measures`, `app_summary`, ShinyProxy.
3. **Container App** `ca-shinyproxy-<env>` with the ShinyProxy image.
4. **`swa deploy`** of the repo root to the Static Web App.

Flags if you repeat runs:

- `-SkipInfra` — skip Bicep (only rebuild/push images and redeploy app + site)
- `-SkipContainers` — skip Docker build/push
- `-SkipStaticSite` — skip SWA deploy

---

## 6. Required: Container App environment variables (blob + Shiny)

The deploy script creates the Container App but **does not** wire blob settings. Set them so ShinyProxy and child containers can read Azure Blob (see `infrastructure/docker/shinyproxy/application.yml`).

Get storage account name and keys (replace resource group and adjust name filter if needed):

```powershell
$rg = "rg-childmetrix-prod"
$st = az storage account list -g $rg --query "[?contains(name, 'stchildmetrix')].name | [0]" -o tsv
$blobEndpoint = az storage account show -n $st -g $rg --query "primaryEndpoints.blob" -o tsv
$key = az storage account keys list -g $rg -n $st --query "[0].value" -o tsv
$acr = az acr list -g $rg --query "[0].loginServer" -o tsv
```

Update the ShinyProxy Container App (replace app name if different):

```powershell
az containerapp update `
  --name ca-shinyproxy-prod `
  --resource-group $rg `
  --set-env-vars `
    "AZURE_BLOB_ENDPOINT=$blobEndpoint" `
    "AZURE_STORAGE_KEY=$key" `
    "AZURE_BLOB_CONTAINER_RAW=raw" `
    "AZURE_BLOB_CONTAINER_PROCESSED=processed" `
    "ACR_LOGIN_SERVER=$acr" `
    "CM_REPORTS_ROOT=/app"
```

**Entra (OIDC) for ShinyProxy** — add when ready (values from your app registration):

```text
AZURE_AUTHORITY=https://login.microsoftonline.com/<TENANT_ID>
AZURE_CLIENT_ID=<app-id>
AZURE_CLIENT_SECRET=<secret>
```

Also configure **Static Web App** application settings for Entra-backed routes (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET` per `staticwebapp.config.json`).

For production, prefer **Key Vault references** or **managed identity** instead of plain storage keys; the commands above are the minimal path to a working stack.

---

## 7. Get URLs: website and dashboards

**Static Web App (main HTML site):**

```powershell
az staticwebapp list -g $rg --query "[].{name:name,url:defaultHostname}" -o table
```

Open `https://<defaultHostname>` in a browser (after DNS/SSL propagate).

**Container App (ShinyProxy):**

```powershell
az containerapp show -n ca-shinyproxy-prod -g $rg --query "properties.configuration.ingress.fqdn" -o tsv
```

Use `https://<fqdn>` for embedded Shiny URLs or `?shiny_base=` on static wrapper pages.

---

## 8. Smoke checklist

- [ ] `git push childmetrix main` succeeds (HTTPS/SSH/credential helper, no token in URL).
- [ ] Bicep deployment completed without errors.
- [ ] Images exist in ACR (`az acr repository list -n <acrName>`).
- [ ] Container App has `AZURE_BLOB_*` and storage key (or equivalent) set.
- [ ] Static Web App URL loads; auth settings match Entra if using login.
- [ ] CFSR iframe pages use the correct Shiny base (Container Apps FQDN or `CM_SHINY_CONFIG` / `?shiny_base=`).

---

## 9. Naming reference (default pattern)

| Resource | Example name |
|----------|----------------|
| Resource group | `rg-childmetrix-prod` |
| Storage | `stchildmetrixprod` (no hyphens; from Bicep) |
| Container Apps env | `cae-childmetrix-prod` |
| Static Web App | `swa-childmetrix-prod` |
| ACR | `acrchildmetrixprod` |
| ShinyProxy app | `ca-shinyproxy-prod` |

Names derive from `baseName` + `environment` in `infrastructure/azure/main.bicep` and `deploy.ps1`.
