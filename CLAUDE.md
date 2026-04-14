# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ChildMetrix Reports** is a multi-state child welfare reporting platform deployed as a static website with embedded R Shiny dashboards. State agencies access standardized reports (CFSR, CPS, In-Home Services, Out-of-Home) through state-specific hubs.

This is a **consolidated monorepo** that includes:
- Static HTML frontend
- CFSR data extraction pipeline (formerly cfsr-profile repository)
- 4 interactive Shiny dashboards
- Shared utilities (no external dependencies on utilities-core)

## Architecture

### Site Structure

```
/                    -> Landing page with state selector + login preview
/{state}/            -> State hub (e.g., /md/, /ky/)
/{state}/{category}/ -> Report category (cfsr, cps, in_home, ooh)
/{state}/{category}/{period}/ -> Specific report period
```

### Technology Stack

- **Pure static HTML/CSS/JavaScript** - No build system, no bundler, no package.json
- **Tailwind CSS via CDN** - Loaded from `https://cdn.tailwindcss.com`
- **Client-side routing** - JavaScript state selector in `index.html` routes to state hubs
- **Shared assets** - `/_assets/` contains logo and shared resources
- **R Shiny** - Interactive dashboards embedded via iframes

### State Routing

The landing page (`index.html`) uses a `STATE_ROUTES` object to map state codes to their hub directories:

```javascript
const STATE_ROUTES = {
  MD: '/md/',
  KY: '/ky/',
  // Add new states here
};
```

Unknown states fallback to `/{state-lowercase}/` pattern.

### Report Organization Pattern

Each state follows this hierarchical structure:

```
{state}/
├── index.html              # State hub with category navigation
├── _assets/                # State-specific assets (if any)
├── cfsr/
│   ├── index.html         # Redirects to /current/ via meta refresh
│   ├── current/           # Symlink or latest period reports
│   ├── archive/           # Historical reports index
│   └── {YYYY_MM}/         # Dated report folders (e.g., 2025_08/)
├── cps/
├── in_home/
└── ooh/
```

Each category's `index.html` auto-redirects to `current/` using:
```html
<meta http-equiv="refresh" content="0; url=/md/cfsr/current/">
```

### Styling & Branding

**Color Palette** (defined in `index.html` and `style.css`):
- Primary: `#0f4c75` (deep blue)
- Accent: `#0e9ba4` (teal)
- Background: `#f9fafb` (light gray)
- Card surface: `#ffffff`
- Muted text: `#64748b` / `#6b7280`

**Responsive Sidebar** (Maryland hub):
- Desktop: Expands/collapses between 160px (w-40) and 64px (w-16)
- Mobile: Fixed overlay drawer that slides in/out
- JavaScript toggles `.expanded` / `.collapsed` classes

## Deployment

Deployment target TBD (AWS or Azure). Previous DigitalOcean staging setup has been removed.

## Development Workflow

### Adding a New State

1. **Create state directory**: `/{state-code}/`
2. **Add to STATE_ROUTES** in `index.html`:
   ```javascript
   const STATE_ROUTES = {
     MD: '/md/',
     KY: '/ky/',
     TX: '/tx/',  // Add here
   };
   ```
3. **Create state hub** `/{state}/index.html` with navigation to report categories
4. **Create report category structure**: `cfsr/`, `cps/`, `in_home/`, `ooh/`
5. **Update deploy script** if state needs special handling

### Adding a New Report Period

1. Create dated folder: `/{state}/{category}/{YYYY_MM}/`
2. Add report content as `index.html` in that folder
3. Update `current/` to point to the new period (symlink or copy)
4. Optionally add old period to `archive/index.html`

### File Naming Conventions

- **Backup files**: `.bak`, `.save`, `.backup.{timestamp}` (gitignored)
- **Active files**: `index.html`, `style.css`
- **Period folders**: `YYYY_MM` format (e.g., `2025_08`)
- **Special folders**: `current/`, `archive/`

### Git Settings

Line endings normalized to LF in repository via `.gitattributes`:
- Text files (HTML, CSS, JS, MD): `eol=lf`
- Windows checkouts may convert to CRLF if `core.autocrlf=true`

## Key Files

- **`index.html`** - Landing page with state selector and routing logic
- **`style.css`** - Shared stylesheet (lightweight ChildMetrix theme)
- **`states/md/index.html`** - Maryland hub (reference implementation with advanced UI)
- **`states/ky/index.html`** - Kentucky hub (simpler tile-based navigation)

## CFSR Shiny Apps

The `domains/cfsr/apps/` directory contains interactive R Shiny dashboards that are embedded into state CFSR pages via iframes.

### App Structure

```
domains/cfsr/
├── apps/                              # Shiny applications
│   ├── app_national/                  # National comparison app (port 3838)
│   ├── app_rsp/                       # Risk-Standardized Performance (port 3839)
│   │   ├── app.R                      # Main app logic
│   │   └── global.R                   # Data loading and global variables
│   ├── app_summary/                   # Performance summary app (port 3840)
│   └── app_observed/                  # Observed Performance (port 3841)
│       ├── app.R
│       └── global.R
├── data/
│   ├── rds/                           # RDS data files for Shiny apps
│   │   ├── {STATE}_cfsr_profile_rsp_{YYYY_MM}.rds
│   │   └── {STATE}_cfsr_profile_observed_{YYYY_MM}.rds
│   └── csv/                           # CSV archives
├── extraction/                        # Data extraction scripts
│   ├── run_profile.R                  # Orchestrator
│   ├── config.R                       # Discovery + validation
│   ├── paths.R                        # Centralized path configuration
│   ├── profile_pdf_rsp.R              # RSP extraction from PDFs
│   ├── profile_pdf_observed.R         # Observed extraction from PDFs
│   ├── profile_excel_national.R       # National data from Excel
│   └── profile_excel_state.R          # State data from Excel
├── functions/                         # CFSR-specific utilities
│   ├── functions_cfsr_profile_shared.R
│   ├── functions_cfsr_profile_pdf_rsp.R
│   ├── functions_cfsr_profile_excel.R
│   ├── period_utils.R                 # Period format conversion
│   └── utils.R                        # Shiny data loading utilities
├── modules/                           # Shiny modules
└── scripts/
    └── launch_cfsr_dashboard.R        # Multi-app launcher script
```

### Data Pipeline

**Source**: Data is extracted from CFSR 4 Data Profile PDFs (biannual: February, August)
**Input Location**: ShareFile at `S:/Shared Folders/{state}/cfsr/uploads/{period}/`
**Output Location**: RDS files saved to `domains/cfsr/data/rds/`
**Archive Location**: CSV copies saved to `domains/cfsr/data/csv/`
**Format**: Each RDS contains state-specific indicator data with period, performance metrics, and metadata

### Running CFSR Apps Locally

```r
# Launch all CFSR apps simultaneously on different ports
source("D:/repo_childmetrix/cm-reports/domains/cfsr/scripts/launch_cfsr_dashboard.R")
```

This starts:
- **National comparison**: http://localhost:3838
- **RSP app**: http://localhost:3839
- **Summary app**: http://localhost:3840
- **Observed Performance**: http://localhost:3841

Apps run in background R processes and can be stopped via the launcher script.

### Running Data Extraction

```r
# Extract CFSR data for all available states and periods
source("D:/repo_childmetrix/cm-reports/domains/cfsr/extraction/run_profile.R")
```

The extraction pipeline:
1. Discovers available states and periods from ShareFile
2. Parses PDFs using coordinate-based extraction (pdftools)
3. Reads Excel files for supplemental context data
4. Validates extracted data
5. Saves RDS files to `domains/cfsr/data/rds/`
6. Saves CSV archives to `domains/cfsr/data/csv/`

### App Integration

**Embedding pattern**: Static HTML pages embed Shiny apps via iframes
```html
<iframe src="http://localhost:3839/?state=MD&profile=2025_02"
        style="width: 100%; height: calc(100vh - 100px); border: none;">
</iframe>
```

**URL parameters**:
- `state`: State code (e.g., MD, KY)
- `profile`: Profile period in YYYY_MM format (e.g., 2025_02)

### Color Palette (Shiny Apps)

Apps use a consistent blue/teal palette matching the static site:
- **Primary blue**: `#1C7ED6`
- **Teal accent**: `#0e9ba4`
- **Warning (DQ)**: `#f59e0b` (amber)
- **Better than national**: `#16a34a` (green)
- **Worse than national**: `#dc2626` (red)

## Shared Utilities

The `shared/utils/` directory contains cross-domain R utilities that are used by both extraction scripts and Shiny apps. These utilities are internalized (no external dependencies on utilities-core).

### Available Utilities

**`shared/utils/state_utils.R`**:
- `STATE_CODES` - Full list of 52 CFSR jurisdictions
- `state_code_to_name(code)` - Convert "MD" to "Maryland"
- `state_name_to_code(name)` - Convert "Maryland" to "MD"
- `validate_state(code)` - Check if state code is valid

**`shared/utils/file_discovery.R`**:
- `discover_states()` - Scan ShareFile for available states
- `discover_periods(state)` - Find available periods for a state
- `discover_sources(state, period)` - Find available source files

**`shared/utils/file_utils.R`**:
- File handling utilities for extraction scripts

**`domains/cfsr/functions/period_utils.R`** (CFSR-specific):
- `validate_period(period)` - Check period format (YYYY_MM)
- Period format conversion utilities

## R Script Structure Standards

**When editing R scripts, check if they follow the standardized structure documented in `docs/R_STYLE_GUIDE.md`.**

### Applies to:
- Data extraction scripts (`domains/*/extraction/*.R`)
- Analysis scripts (`states/*/scripts/*.R`)
- Orchestrator scripts (`launch_*.R`, `run_*.R`)

### Does NOT apply to:
- Shiny app.R files (different structure needs)
- Function libraries (`domains/*/functions/*.R`) - these use roxygen2 docs
- Test files
- Scripts <50 lines

### Quick Check:
When editing an eligible script, verify it has:
1. **Four-line title banner** with Purpose/Inputs/Outputs
2. **Proper section headings** (NOTES, LIBRARIES & CONFIGURATION, MAIN PROCESSING)
3. **snake_case** naming for variables and functions

### If Missing Structure:
- Copy template from `templates/r_script_template.R`
- Add title banner and purpose statement at top
- Organize code into logical sections with proper headings
- Reference examples: `domains/cfsr/extraction/profile_pdf_observed.R`

### For New Scripts:
- **ALWAYS** start from `templates/r_script_template.R`
- Fill in title, purpose, inputs/outputs before adding code

See full guide at `docs/R_STYLE_GUIDE.md` for complete standards.

## Monorepo Consolidation

This repository was consolidated in January 2026 to merge the formerly separate `cfsr-profile` repository. Key changes:

**Before (two repos):**
- `cfsr-profile/` - Extraction scripts, wrote to cm-reports/shared/cfsr/data/
- `cm-reports/` - Frontend + Shiny apps, read from shared/cfsr/data/

**After (single monorepo with domains structure):**
- All CFSR code is self-contained in `domains/cfsr/` directory
- Data lives at `domains/cfsr/data/rds/` (organized by state/period)
- Other report domains will live in `domains/{domain}/` (cps, in_home, ooh, onehome, community)
- Shared utilities internalized to `shared/utils/`
- No dependency on external utilities-core repository

**Benefits:**
- Single deployment (one repo to staging/production)
- Unified versioning
- Simplified path management
- Self-contained domains

## Azure Cloud Infrastructure

The platform is designed for Azure deployment with the following architecture:

### Infrastructure-as-Code

All Azure resources are defined in Bicep templates under `infrastructure/azure/`:

- **`main.bicep`** - Provisions: Storage Account, SQL Database, Key Vault, Container Registry, Container Apps Environment, Static Web App, Log Analytics
- **`parameters.json`** - Environment-specific parameters
- **`deploy.ps1`** - End-to-end deployment script
- **`setup-entra.ps1`** - Azure Entra External ID configuration (roles, user flows)
- **`migrate-sharefile.ps1`** - Mirror ShareFile content to Azure Blob Storage
- **`validate-parity.ps1`** - Verify Azure Blob matches ShareFile before decommission

### Database Schema

`infrastructure/sql/schema.sql` defines tables for:
- `cm_users` - User accounts (synced with Entra External ID)
- `cm_user_states` - State access assignments per user
- `cm_uploads` - Upload tracking with processing status
- `cm_extractions` - Extraction pipeline run logs
- `cm_reports` - Report catalog (state/domain/period)
- `cm_audit_log` - All significant actions logged
- `cm_config` - Feature flags and platform configuration

### Docker Containers

Under `infrastructure/docker/`:
- **`extraction/Dockerfile`** - R extraction pipeline container
- **`shiny/app_measures/Dockerfile`** - CFSR Measures Shiny app
- **`shiny/app_summary/Dockerfile`** - CFSR Summary Shiny app
- **`shinyproxy/Dockerfile`** + **`application.yml`** - ShinyProxy for managing Shiny containers

### Dual-Mode Data Source

R code supports both ShareFile and Azure Blob via `CM_DATA_SOURCE` env var:

```r
# Set CM_DATA_SOURCE=azure to use Azure Blob, or =sharefile (default) for S: drive
CM_DATA_SOURCE <- Sys.getenv("CM_DATA_SOURCE", "sharefile")
```

Key files updated for dual-mode:
- `domains/cfsr/extraction/paths.R` - `save_rds_data()` / `load_rds_data()` / `build_rds_path()`
- `shared/utils/file_discovery.R` - `discover_states()` / `discover_periods()` / `discover_sources()`
- `domains/cfsr/apps/*/global.R` - Data loading functions

### Authentication

- **Azure Entra External ID** handles user auth (MFA, RBAC)
- **Roles**: `viewer`, `manager`, `admin`, `super_admin`
- **State isolation**: Users only access states assigned to them
- Landing page (`index.html`) auto-detects Azure vs local mode
- `staticwebapp.config.json` enforces route-level auth

### Admin Console

`admin/index.html` provides:
- User management (invite, edit roles, assign states)
- Upload history tracking
- Extraction run monitoring
- Platform configuration (states, domains, settings)
- Audit log viewer

### Upload Portal

`shared/upload/index.html` provides:
- State/domain/period-aware file upload
- Drag-and-drop with file validation
- Azure Blob upload via Azure Function API
- Auto-trigger extraction pipeline on upload

## Notes

- **Static + Dynamic Hybrid**: Static HTML site with embedded Shiny apps for interactive dashboards
- **No JavaScript framework** - Vanilla JS for navigation and UI interactions
- **Mobile-first responsive** - Tailwind utilities + custom media queries for sidebar
- **Accessibility**: Form inputs use proper labels, buttons have aria-labels
- **Azure auth integration**: Landing page supports both preview (local) and Azure Entra (production) login
- **Multi-app architecture**: Shiny apps run on separate ports and are embedded via iframes for modularity
- **Self-contained**: No external R utility dependencies (utilities-core functions internalized)
- **Configurable Shiny URLs**: Wrapper pages support `shiny_base` param for Azure-hosted Shiny endpoints

## Documentation

- **[README.md](README.md)** - Quick-start guide for humans
- **[docs/PRD.md](docs/PRD.md)** - Strategic planning document (vision, requirements, roadmap)
- **[.env.example](.env.example)** - All environment variables documented
- **[infrastructure/sql/schema.sql](infrastructure/sql/schema.sql)** - Database schema
- **[states/md/README.md](states/md/README.md)** - Maryland-specific notes
