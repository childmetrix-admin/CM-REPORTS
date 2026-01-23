# ChildMetrix Reporting Platform

Web-based reporting platform for child welfare data visualization and analysis across multiple states.

**Last Updated**: January 2026

## Overview

This repository is a consolidated monorepo containing the ChildMetrix reporting platform - a multi-state web application that provides interactive Shiny dashboards, data visualizations, and reports for child welfare agencies. The CFSR data extraction pipeline (formerly `cfsr-profile` repository) has been integrated into this monorepo.

## Directory Structure

```
cm-reports/
├── _assets/
│   ├── css/               # Platform CSS
│   └── logo.png           # Platform branding
├── cfsr/                   # CFSR domain (self-contained)
│   ├── apps/              # 4 Shiny dashboards
│   │   ├── app_national/  # National comparison (port 3838)
│   │   ├── app_rsp/       # Risk-Standardized Performance (port 3839)
│   │   ├── app_summary/   # Performance summary (port 3840)
│   │   └── app_observed/  # Observed Performance (port 3841)
│   ├── data/
│   │   ├── csv/           # CSV archives
│   │   └── rds/           # RDS files for Shiny apps
│   ├── extraction/        # Data extraction scripts
│   │   ├── run_profile.R  # Main orchestrator
│   │   ├── config.R       # Discovery + validation
│   │   ├── paths.R        # Centralized path configuration
│   │   ├── profile_pdf_rsp.R        # RSP PDF extraction
│   │   ├── profile_pdf_observed.R   # Observed PDF extraction
│   │   ├── profile_excel_national.R # National Excel extraction
│   │   ├── profile_excel_state.R    # State Excel extraction
│   │   └── cfsr_round4_indicators_dictionary.csv
│   ├── functions/         # CFSR-specific R functions
│   │   ├── functions_cfsr_profile_shared.R      # Shared utilities
│   │   ├── functions_cfsr_profile_pdf_rsp.R     # RSP parsing
│   │   ├── functions_cfsr_profile_pdf_observed.R # Observed parsing
│   │   ├── functions_cfsr_profile_excel.R       # Excel parsing
│   │   ├── period_utils.R # Period format validation
│   │   ├── utils.R        # Shiny app data loading
│   │   ├── chart_builder.R # Chart generation
│   │   └── data_prep.R    # Data transformation
│   ├── modules/           # Shiny modules
│   │   ├── indicator_detail.R  # Indicator detail module
│   │   └── indicator_page.R    # Indicator page module
│   └── scripts/           # Utilities
│       ├── launch_cfsr_dashboard.R  # Multi-app launcher
│       └── move_period_selector.py  # HTML manipulation utility
├── shared/
│   └── utils/             # Cross-domain utilities
│       ├── file_discovery.R
│       ├── file_utils.R
│       └── state_utils.R
├── states/                # State-specific sites
│   ├── md/               # Maryland (primary development)
│   └── ky/               # Kentucky
├── docs/                  # Documentation
│   └── PRD.md            # Product Requirements Document
├── index.html            # Landing page (state selector)
├── app.html              # Main app shell
├── README.md             # This file
└── CLAUDE.md             # AI assistant guide
```

## Features

### Multi-State Support
- Each state has its own folder under `states/`
- Shared infrastructure and assets at platform level
- State-specific branding and customization

### CFSR Data Profile Dashboard
- Interactive Shiny applications for CFSR statewide data indicators
- 8 indicators across Safety, Permanency, and Well-Being domains
- State-by-state rankings and comparisons
- Risk-Standardized Performance (RSP) analysis

### Domain-Specific Reports
Each state site includes:
- **CFSR**: Child and Family Services Review data profiles
- **CPS**: Child Protective Services reports (planned)
- **In-Home**: In-home services tracking (planned)
- **OOH**: Out-of-home care (foster care) reports (planned)

## Data Integration

### CFSR Data Pipeline

The CFSR extraction pipeline is now integrated into this monorepo:

1. **Source**: CFSR 4 Data Profile PDFs from ShareFile (`S:/Shared Folders/{state}/cfsr/uploads/`)
2. **Extraction**: Run `cfsr/extraction/run_profile.R` to process PDFs and Excel files
3. **Output**: RDS files saved to `cfsr/data/rds/`
4. **Consumption**: Shiny apps load data from `cfsr/data/rds/`
5. **Archive**: CSV copies saved to `cfsr/data/csv/`

## Running the Platform

### Local Development

**Static HTML (no Shiny):**
```bash
# Open in browser
file:///D:/repo_childmetrix/cm-reports/index.html
```

**With Shiny Apps:**
```r
# Launch all CFSR apps simultaneously
source("D:/repo_childmetrix/cm-reports/cfsr/scripts/launch_cfsr_dashboard.R")
```

This starts:
- **National comparison**: http://localhost:3838
- **RSP app**: http://localhost:3839
- **Summary app**: http://localhost:3840
- **Observed Performance**: http://localhost:3841

### Staging Deployment

```powershell
# Full site deploy
.\deploy-stage.ps1

# Maryland only (faster iteration)
.\deploy-stage.ps1 -MdOnly
```

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
- **Storage**: Local RDS files, ShareFile cloud storage

## Documentation

- **[Product Requirements Document](docs/PRD.md)** - Strategic roadmap and architecture
- **[AI Assistant Guide](CLAUDE.md)** - Technical implementation details
- **[Maryland State](states/md/README.md)** - State-specific notes

## Recent Changes

**January 2026**
- Consolidated cfsr-profile repository into monorepo
- Moved Shiny apps to `cfsr/apps/`
- Moved data to `cfsr/data/rds/` and `cfsr/data/csv/`
- Extracted shared utilities to `shared/utils/`
- Removed dependency on external utilities-core repository

**November 2025**
- Reorganized into `states/` folder structure for scalability
- Integrated CFSR interactive Shiny dashboard

---

**Organization**: [ChildMetrix](https://github.com/childmetrix)
