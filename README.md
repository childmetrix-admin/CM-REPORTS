# CFSR Profile Data Processing Project

## Overview

This R project processes **CFSR (Child and Family Services Review)** data from three complementary sources:

1. **National Data** - National Supplemental Context Data showing state-by-state performance on all CFSR statewide data indicators
2. **Risk-Standardized Performance (RSP)** - State-specific PDFs showing risk-adjusted performance metrics
3. **State-Level Data** - Geographic breakdowns (county/regional) within the state

The data files are provided to states approximately every 6 months (typically February and August) by the Children's Bureau, Administration for Children and Families.

## Quick Start

### Processing National Data

```r
# 1. Upload National Excel file to ShareFile:
#    S:/Shared Folders/{state}/cfsr/uploads/{PERIOD}/
#    Example: S:/Shared Folders/md/cfsr/uploads/2025_02/National - Supplemental Context Data - February 2025.xlsx

# 2. Set state and period in profile_national.R:
state_code <- "md"          # Lowercase state code
profile_period <- "2025_02"

# 3. Run the processing script:
source("D:/repo_childmetrix/cfsr-profile/code/profile_national.R")

# Output: data/processed/{state}/{period}/{date}/national/
```

### Processing RSP Data

```r
# 1. Export state PDF to text using Adobe Acrobat (File > Export To > Text)
#    Save as: S:/Shared Folders/{state}/cfsr/uploads/{PERIOD}/adobe_to_accessible_text.txt

# 2. Set state and period in profile_rsp.R:
state_code <- "md"
profile_period <- "2025_02"

# 3. Run the processing script:
source("D:/repo_childmetrix/cfsr-profile/code/profile_rsp.R")

# Output: data/processed/{state}/{period}/{date}/rsp/
```

### Processing State-Level Data

```r
# (Under development - template available in profile_state.R)
```

## Project Structure

```
cfsr-profile/
├── code/
│   ├── profile_national.R          # National Excel data processing
│   ├── profile_rsp.R               # Risk-Standardized Performance (PDF) processing
│   ├── profile_state.R             # State-level (county/regional) processing (planned)
│   ├── organize_cfsr_uploads.R     # File organization utilities
│   └── process_cfsr_batch.R        # Batch processing
│
├── data/
│   ├── processed/                  # Generated CSV outputs
│   │   └── {state}/{period}/{date}/
│   │       ├── national/           # National data CSVs
│   │       ├── rsp/                # RSP data CSVs
│   │       └── state/              # State-level data CSVs (planned)
│   └── app_data/                   # State-specific RDS files for Shiny apps
│       └── {state}/                # e.g., app_data/md/
│
├── shiny_app/                      # Interactive dashboards
│   ├── national/                   # National data dashboard (current)
│   │   ├── app.R                   # Shiny application
│   │   ├── global.R                # Global data loading
│   │   ├── prepare_app_data.R      # Data preparation
│   │   ├── modules/                # Reusable UI modules
│   │   └── functions/              # Helper functions
│   ├── rsp/                        # RSP dashboard (planned)
│   │   ├── app/                    # Future Shiny app
│   │   └── README.md               # RSP dashboard documentation
│   └── state/                      # State-level dashboard (planned)
│       ├── app/                    # Future Shiny app
│       └── README.md               # State dashboard documentation
│
├── docs/                           # Documentation
│   ├── WORKFLOW.md                 # Detailed workflow guide
│   ├── FUNCTIONS.md                # Function reference
│   ├── CHANGELOG.md                # Project history
│   └── archive/                    # Historical dev notes
│
└── cfsr-profile.Rproj              # RStudio project file
```

## Dependencies

### External Utilities

This project depends on centralized R utilities:

- **utilities-core** - Core R utilities (packages, generic functions)
  - Location: `D:/repo_childmetrix/utilities-core/`
  - Loaded via: `source("D:/repo_childmetrix/utilities-core/loader.R")`

- **utilities-cfsr** - CFSR-specific functions
  - Location: `D:/repo_childmetrix/utilities-cfsr/`
  - Key functions: `process_standard_indicator()`, `process_entry_rate_indicator()`, `setup_cfsr_folders()`

### R Packages

Automatically loaded via utilities-core (40+ tidyverse and data science packages)


## Data Sources

This project processes three complementary CFSR data sources:

### 1. National Data (profile_national.R)
- **Source**: National Supplemental Context Data Excel file
- **Content**: State-by-state performance on all 8 CFSR indicators
- **Format**: Multi-sheet Excel workbook with state rankings
- **Status**: Fully implemented with Shiny dashboard

### 2. Risk-Standardized Performance - RSP (profile_rsp.R)
- **Source**: State-specific CFSR Data Profile PDFs (Adobe text export)
- **Content**: Risk-adjusted performance metrics accounting for state-specific factors
- **Format**: PDF exported to accessible text file
- **Status**: Data extraction implemented, dashboard planned

### 3. State-Level Data (profile_state.R)
- **Source**: State-provided Excel files with geographic breakdowns
- **Content**: County/regional performance within the state
- **Format**: Excel files with sub-state geographic data
- **Status**: Template created, implementation planned

## Data Processing

### Indicators Processed

The script processes 8 CFSR statewide data indicators:

**Safety (2)**
- Foster care entry rate (per 1,000 children)
- Maltreatment in foster care (per 100,000 days)

**Permanency (4)**
- Permanency in 12 months (entries)
- Permanency in 12 months (12-23 months in care)
- Permanency in 12 months (24+ months in care)
- Re-entry into foster care

**Well-Being (2)**
- Placement stability (moves per 1,000 days)
- Recurrence of maltreatment

### Output Data Structure

Final dataset columns:
- `state` - State name (52 total: 50 states + D.C. + Puerto Rico)
- `indicator` - Full indicator name
- `period` / `period_meaningful` - Period code and human-readable label
- `denominator` / `numerator` / `performance` - Metric components
- `state_rank` - State ranking (1-52, most recent period only)
- `as_of_date` - AFCARS/NCANDS data submission date
- `profile_version` - Profile publication (e.g., "February 2025")
- `source` - Full APA citation

## Data Sources and Storage

**Raw data uploads**: States upload files to ShareFile
- Location: `S:/Shared Folders/{state}/cfsr/uploads/{period}/`
- Files are read directly from ShareFile (not copied locally)
- Security: Only state users can upload to their specific folder

**Local processed data**: Generated outputs stored locally
- Processed CSVs: `data/processed/{state}/{period}/{date}/`
- App data (RDS): `data/app_data/{state}/`

## Integration with ChildMetrix Platform

Processed data feeds into the **cm-reports** platform:

1. **Data Pipeline**:
   - Dev: `cfsr-profile/data/app_data/{state}/cfsr_indicators_latest.rds`
   - Prod: `cm-reports/states/md/cfsr/performance/app/data/{state}_cfsr_indicators_latest.rds`

2. **Shiny Dashboard**:
   - Interactive state-by-state comparisons
   - Small multiples overview
   - Detailed indicator pages
   - Integrated into ChildMetrix reporting platform

See [cm-reports/states/md/cfsr/performance/README.md](../cm-reports/states/md/cfsr/performance/README.md) for deployment details.

## Next Step: Interactive Dashboard

After processing completes, the data is ready for the Shiny dashboard. See **[shiny_app/README.md](shiny_app/README.md)** for:
- Running the interactive dashboard
- Deploying to production
- Customizing the app

## Documentation

- **[shiny_app/README.md](shiny_app/README.md)** - Interactive dashboard setup and deployment
- **[docs/WORKFLOW.md](docs/WORKFLOW.md)** - Detailed workflow and usage
- **[docs/FUNCTIONS.md](docs/FUNCTIONS.md)** - Function reference guide
- **[docs/CHANGELOG.md](docs/CHANGELOG.md)** - Project history and changes

## Recent Changes

**November 2025 (Mid-month reorganization)**
- **Three-source architecture**: Reorganized to handle National, RSP, and State-level data
  - Renamed `cfsr_profile.R` → `profile_national.R`
  - Migrated `cfsr-profile-pdf` code → `profile_rsp.R`
  - Created `profile_state.R` template for future state-level processing
- **Data folder structure**: Added source-specific subdirectories (national/, rsp/, state/)
- **Shiny app structure**: Created separate dashboard folders for each data source
- **Documentation**: Updated README to reflect multi-source architecture

**November 2025 (Early month)**
- **ShareFile integration**: Raw data now read directly from `S:/Shared Folders/{state}/cfsr/uploads/`
- **Lowercase state codes**: All folder names use lowercase (md, ky, etc.) for consistency
- **Simplified data structure**: Removed local `uploads/` folder, removed legacy `shiny_app/data/`
- **Renamed repository** from `r_cfsr_profile` to `cfsr-profile` (kebab-case)
- Reorganized documentation into `docs/` structure

**October 2025**
- Added multi-state support (state_code parameter)
- Refactored main script from 604→139 lines (77% reduction)
- Added all 8 CFSR indicators (was 6)
- Created interactive Shiny dashboard with overview page
- Integrated with ChildMetrix platform

## Data Source

**Children's Bureau, Administration for Children and Families**
U.S. Department of Health & Human Services

Files provided biannually (February & August) containing AFCARS and NCANDS data.

## Repository

**GitHub**: [kurtheisler/cfsr-profile](https://github.com/kurtheisler/cfsr-profile)

## Naming Conventions

Following ChildMetrix standards:
- **Repository folders**: kebab-case (`cfsr-profile`)
- **R scripts**: snake_case (`cfsr_profile.R`)
- **Project files**: match folder name (`cfsr-profile.Rproj`)
- **State codes**: lowercase in folder names (`md`, `ky`) for consistency with ShareFile
