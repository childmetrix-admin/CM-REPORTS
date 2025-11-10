# CFSR Profile Data Processing Project

## Overview

This R project processes **National Supplemental Context Data** files from the Children's Bureau that track state-by-state performance on **Child and Family Services Review (CFSR)** statewide data indicators. The data files are provided to states approximately every 6 months (typically February and August).

## Quick Start

```r
# 1. Place raw data file in appropriate folder:
#    D:/repo_childmetrix/cfsr-profile/data/{STATE}/{PERIOD}/raw/
#    Example: data/MD/2025_02/raw/National - Supplemental Context Data - February 2025.xlsx

# 2. Set state and period in cfsr_profile.R:
state_code <- "MD"
profile_period <- "2025_02"

# 3. Run the processing script:
source("D:/repo_childmetrix/cfsr-profile/code/cfsr_profile.R")

# 4. Script automatically chains to prepare_app_data.R
#    - Saves processed CSV to: data/{STATE}/{PERIOD}/processed/{date}/
#    - Generates RDS files for Shiny app (dev and prod locations)
```

## Project Structure

```
cfsr-profile/
├── code/
│   ├── cfsr_profile.R              # Main processing script
│   ├── organize_cfsr_uploads.R     # File organization utilities
│   └── process_cfsr_batch.R        # Batch processing
│
├── data/
│   └── {STATE}/                    # State-specific data (e.g., MD/, KY/)
│       └── {PERIOD}/               # Period folders (e.g., 2025_02/)
│           ├── raw/                # Raw Excel files from Children's Bureau
│           └── processed/          # Generated CSV outputs
│               └── {date}/         # Date-stamped run folders
│
├── shiny_app/                      # Interactive dashboard
│   ├── app.R                       # Shiny application
│   ├── global.R                    # Global data loading
│   ├── prepare_app_data.R          # Data preparation for app
│   ├── modules/                    # Reusable UI modules
│   └── functions/                  # Helper functions
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

## Integration with ChildMetrix Platform

Processed data feeds into the **cm-reports** platform:

1. **Data Pipeline**:
   - Dev: `cfsr-profile/shiny_app/data/cfsr_indicators_latest.rds`
   - Prod: `cm-reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds`

2. **Shiny Dashboard**:
   - Interactive state-by-state comparisons
   - Small multiples overview
   - Detailed indicator pages
   - Integrated into ChildMetrix reporting platform

See [cm-reports/md/cfsr/performance/README.md](../cm-reports/md/cfsr/performance/README.md) for deployment details.

## Documentation

- **[docs/WORKFLOW.md](docs/WORKFLOW.md)** - Detailed workflow and usage
- **[docs/FUNCTIONS.md](docs/FUNCTIONS.md)** - Function reference guide
- **[docs/CHANGELOG.md](docs/CHANGELOG.md)** - Project history and changes
- **[shiny_app/README.md](shiny_app/README.md)** - Shiny app documentation
- **[shiny_app/QUICK_START.md](shiny_app/QUICK_START.md)** - Quick start for dashboard

## Recent Changes

**November 2025**
- Renamed repository from `r_cfsr_profile` to `cfsr-profile` (kebab-case)
- Updated all path references to new naming convention
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
