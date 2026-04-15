# ChildMetrix Reporting Platform

Web-based reporting platform for child welfare data visualization and analysis across multiple states.

**Last Updated**: April 2026

## Overview

This repository is a consolidated monorepo containing the ChildMetrix reporting platform - a multi-state web application that provides interactive Shiny dashboards, data visualizations, and reports for child welfare agencies. The CFSR data extraction pipeline (formerly `cfsr-profile` repository) has been integrated into this monorepo.

## Directory Structure

```
cm-reports/
├── _assets/
│   ├── css/               # Platform CSS
│   └── logo.png           # Platform branding
├── domains/               # Self-contained domain modules
│   ├── cfsr/              # CFSR domain (fully implemented)
│   │   ├── apps/          # 2 consolidated Shiny apps
│   │   │   ├── app_measures/   # Measures + indicators (port 3838)
│   │   │   └── app_summary/    # Performance summary (port 3840)
│   │   ├── data/
│   │   │   ├── csv/       # CSV archives
│   │   │   └── rds/       # RDS files for Shiny apps
│   │   ├── extraction/    # Data extraction pipeline
│   │   │   ├── run_profile.R   # Main orchestrator
│   │   │   ├── config.R        # Discovery + validation
│   │   │   ├── paths.R         # Path configuration
│   │   │   ├── profile_pdf_rsp.R        # RSP PDF extraction
│   │   │   ├── profile_pdf_observed.R   # Observed PDF extraction
│   │   │   ├── profile_excel_national.R # National Excel
│   │   │   └── profile_excel_state.R    # State Excel
│   │   ├── functions/     # CFSR-specific R functions
│   │   │   ├── utils.R         # Data loading
│   │   │   ├── chart_builder.R # Chart generation
│   │   │   ├── viz_container.R # Viz wrapper
│   │   │   └── data_prep.R     # Data transformation
│   │   └── modules/       # Shiny modules
│   │       └── indicator_detail.R  # Indicator detail module
│   ├── cps/               # CPS domain (planned)
│   ├── in_home/           # In-Home Services (planned)
│   ├── ooh/               # Out-of-Home Care (planned)
│   └── community/         # Community Services (planned)
├── shared/
│   ├── css/               # Design system
│   │   ├── design-tokens.css  # CSS variables
│   │   ├── components.css     # Reusable components
│   │   └── README.md          # Design system guide
│   └── utils/             # Cross-domain R utilities
│       ├── file_discovery.R
│       ├── file_utils.R
│       └── state_utils.R
├── states/                # State-specific sites
│   ├── md/               # Maryland (primary development)
│   └── ky/               # Kentucky
├── docs/                  # Documentation
│   └── PRD.md            # Product Requirements Document
├── index.html            # Landing page (state selector)
├── README.md             # This file
└── CLAUDE.md             # AI assistant guide
```

## Features

### Multi-State Support
- Each state has its own folder under `states/`
- Shared infrastructure and assets at platform level
- State-specific branding and customization

### CFSR Data Profile Dashboard
- 2 consolidated Shiny applications for CFSR statewide data indicators
- 8 indicators across Safety, Permanency, and Well-Being domains
- State-by-state rankings and comparisons
- Risk-Standardized Performance (RSP) analysis
- Interactive visualizations with PNG export capability

### Design System
- Centralized CSS with design tokens and reusable components
- Consistent spacing, typography, and colors across all pages
- Standardized UI patterns for rapid development
- Comprehensive documentation in `shared/css/README.md`

### Domain-Specific Reports
Each state site includes:
- **CFSR**: Child and Family Services Review data profiles (implemented)
- **CPS**: Child Protective Services reports (planned)
- **In-Home**: In-home services tracking (planned)
- **OOH**: Out-of-home care (foster care) reports (planned)
- **Community**: Community services tracking (planned)

## Data Integration

### CFSR Data Pipeline

The CFSR extraction pipeline is integrated into the monorepo and uses **Azure Blob Storage** only:

1. **Source**: CFSR 4 Data Profile PDFs and Excel files uploaded to the **raw** blob container (paths such as `{state}/cfsr/uploads/{period}/` — see `shared/utils/file_discovery.R`)
2. **Extraction**: Run `domains/cfsr/extraction/run_profile.R` with `AZURE_BLOB_ENDPOINT` and `AZURE_STORAGE_KEY` set (see `.env.example`)
3. **Output**: RDS objects written to the **processed** blob container (`build_rds_path()` in `domains/cfsr/extraction/paths.R`)
4. **Consumption**: Shiny apps (`domains/cfsr/apps/`) load processed RDS from the same Azure storage account
5. **Archive**: CSV outputs follow the extraction scripts (typically uploaded alongside RDS)

To extract CFSR data (after configuring Azure environment variables):
```r
source("domains/cfsr/extraction/run_profile.R")
run_profile(state = "md", period = "2025_02", source = "all")
```

## Getting Started (New Contributors)

### Prerequisites

- **R** (4.x+) with RStudio or VSCode (for extraction and app development)
- R packages auto-install on first run where applicable (tidyverse, shiny, pdftools, readxl, plotly, DT, AzureStor, etc.)
- **Azure credentials** for the storage account used by ChildMetrix (blob containers for raw uploads and processed outputs)

### 1. Configure environment

Copy `.env.example` to `.env` and set at minimum `AZURE_BLOB_ENDPOINT`, `AZURE_STORAGE_KEY`, and container names. The upload portal (`shared/upload/index.html`) sends files to the **raw** container via the deployed API (`/api`).

### 2. Open the Project

Open `cm-reports.Rproj` in RStudio (or open the folder in VSCode).

### 3. Run Data Extraction

```r
source("domains/cfsr/extraction/run_profile.R")
run_profile(source = "all")
```

This discovers available states/periods from the raw container, extracts data from PDFs and Excel files, and uploads RDS to the processed container.

### 4. Shiny dashboards

Interactive apps are deployed to **Azure Container Apps** (or run locally using the Dockerfiles under `infrastructure/docker/shiny/` with the same Azure variables). The repository does not start Shiny from R via `launch_cfsr_apps.R` (that file explains the Docker workflow).

### 5. View the Platform

- **Landing page**: Open `index.html` in a browser (state selector + login preview)
- **Direct access**: Open `app.html` (loads Maryland by default)
- Embedded CFSR pages resolve Shiny base URLs from `?shiny_base=`, optional `window.CM_SHINY_CONFIG`, or the configured Azure Container Apps hostnames

### Deployment

Azure infrastructure is defined under `infrastructure/azure/` (Bicep, `deploy.ps1`). Static site and Container Apps are the supported deployment path.

## Adding a New State

1. Create state folder: `mkdir states/{state_code}`
2. Copy template from existing state
3. Update branding in `states/{state_code}/_assets/`
4. Add state to dropdown in root `index.html`
5. Configure data pipeline for new state

## Technology Stack

- **Frontend**: HTML5, Tailwind CSS (CDN), JavaScript
- **Interactive Dashboards**: R Shiny, Plotly
- **Data Processing**: R, tidyverse, pdftools, readxl
- **Storage**: Azure Blob Storage (raw uploads + processed RDS)

## Documentation

- **[Azure deployment (GitHub + CLI)](docs/AZURE_DEPLOYMENT.md)** - Clone, push to ChildMetrix, deploy, open production URLs
- **[Product Requirements Document](docs/PRD.md)** - Strategic roadmap and architecture
- **[R Code Style Guide](docs/R_STYLE_GUIDE.md)** - R script structure and coding standards
- **[AI Assistant Guide](CLAUDE.md)** - Technical implementation details
- **[R Script Template](templates/r_script_template.R)** - Standard template for new R scripts

## Recent Changes

**February 2026**
- Completed design system implementation (`shared/css/`)
- Consolidated 4 CFSR apps into 2 (app_measures + app_summary)
- Standardized spacing and UI patterns across all pages
- Added download buttons to Overview tabs
- Updated PRD to reflect current architecture

**January 2026**
- Consolidated cfsr-profile repository into monorepo
- Reorganized into `domains/` structure for scalability
- Moved Shiny apps to `domains/cfsr/apps/`
- Moved data to `domains/cfsr/data/rds/` and `data/csv/`
- Extracted shared utilities to `shared/utils/`
- Removed dependency on external utilities-core repository

**November 2025**
- Reorganized into `states/` folder structure
- Integrated CFSR interactive Shiny dashboard

---

**Organization**: [ChildMetrix](https://github.com/childmetrix)
