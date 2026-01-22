# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CFSR Profile Data Extraction** extracts quantitative performance data from state-specific CFSR 4 Data Profile PDFs published by the Children's Bureau. The extracted data feeds interactive dashboards in the `cm-reports` repository.

## Architecture

### Data Flow

```
ShareFile PDFs → PDF Extraction Scripts → Processed CSV/RDS → cm-reports Shiny Apps
```

1. **Source**: State-specific CFSR 4 Data Profile PDFs (from Children's Bureau)
   - Location: `S:/Shared Folders/{state}/cfsr/uploads/{YYYY_MM}/`
   - Filename: `{STATE} - CFSR 4 Data Profile - {Month} {Year}.pdf`

2. **Extraction**: R scripts parse PDFs using `pdftools` with coordinate-based extraction
   - `profile_rsp.R`: Page 2 (Risk-Standardized Performance + confidence intervals)
   - `profile_observed.R`: Page 4 (Observed performance: denominator, numerator, rate)
   - `profile_national.R`: National comparison data from Excel supplement

3. **Output**: Processed data saved as CSV and RDS
   - CSV: `data/processed/{state}/{period}/{date}/{type}/{state}_{period}_cfsr_profile_{type}.csv`
   - RDS: `D:/repo_childmetrix/cm-reports/shared/cfsr/data/{STATE}_cfsr_profile_{type}_{period}.rds`

4. **Consumption**: RDS files loaded by Shiny apps in cm-reports for visualization

### Directory Structure

```
cfsr-profile/
├── code/
│   ├── config.R                        # Central configuration (flags, paths)
│   ├── run_profile.R                   # Orchestrator for all extraction scripts
│   ├── run.R                           # Development runner (sources run_profile.R)
│   ├── profile_rsp.R                   # Extract RSP data (page 2)
│   ├── profile_observed.R              # Extract observed data (page 4)
│   ├── profile_national.R              # Extract national comparison (Excel)
│   ├── functions/
│   │   ├── functions_cfsr_profile_rsp.R   # Shared utility functions
│   │   └── functions_cfsr_profile_nat.R   # National-specific functions
│   ├── cfsr_round4_indicators_dictionary.csv  # Indicator metadata
│   └── PROFILE_EXTRACTION_ANALYSIS.md  # Technical documentation
├── data/
│   ├── processed/                      # Output CSV files by state/period/date/type
│   └── raw/                            # PDF source files (not in git)
└── old/                                # Archived code (deprecated Shiny app)
```

## Key Scripts

### config.R

Central configuration file that controls extraction behavior:

```r
# Feature flags
rsp_enabled <- TRUE             # Extract Risk-Standardized Performance
observed_enabled <- TRUE        # Extract Observed Performance
national_enabled <- TRUE        # Extract National comparison data

# Output paths
path_cm_reports_cfsr_data <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
```

### run_profile.R

Orchestrator that coordinates all extraction scripts:
- Sets up folder structure
- Sources enabled extraction scripts based on config flags
- Manages state_code and profile_period variables
- Called by `run.R` or can be sourced directly

**Usage**:
```r
state_code <- "md"
profile_period <- "2025_02"
source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")
```

### profile_rsp.R

Extracts Risk-Standardized Performance from PDF page 2:
- **Top table** (y=190-400): 5 permanency/placement indicators, 9 AFCARS periods
- **Bottom table** (y=410-520): 2 maltreatment indicators, 6 periods (3 AFCARS AB + 3 NCANDS FY)
- **Data fields**: RSP, RSP lower/upper bounds, data used periods, national performance
- **Period formats**: "20A20B" (AFCARS A period), "20B21A" (B period), "20AB_FY20" (maltreatment), "FY20-21" (recurrence)

### profile_observed.R

Extracts Observed Performance from PDF page 4:
- **Top table**: Same 5 indicators as RSP, up to 9 AFCARS periods
- **Bottom table**: Same 2 maltreatment indicators, 6 periods
- **Data fields**: Denominator, numerator, observed_performance
- **Period formats**: Same as RSP (converted from "20AB.FY20" → "20AB_FY20" for consistency)
- **DQ handling**: Preserves "DQ" flags as NA, filters truly empty periods

### profile_national.R

Extracts national comparison data from Excel supplement:
- **Source**: "National - Supplemental Context Data - {Month} {Year}.xlsx"
- **Data**: National performance values by indicator and period
- **Purpose**: Provides comparison baseline for state performance

## Extraction Patterns

### PDF Coordinate-Based Extraction

All scripts use `pdftools::pdf_data()` which returns text elements with x/y coordinates:

```r
# Extract table using coordinate boundaries
df_raw <- extract_tableau_table(
  raw_data,
  y_min = 190,          # Top boundary
  y_max = 400,          # Bottom boundary
  x_cuts = c(135, 240, 305, ...),  # Column split points
  y_tolerance = 10      # Vertical grouping threshold
)
```

**Key parameters**:
- `y_min/y_max`: Define table boundaries
- `x_cuts`: X-coordinates that split columns (determined by period header positions)
- `y_tolerance`: Max vertical distance to group text elements into same row

### Period Handling

**Period formats**:
- `20A20B`: AFCARS A period (Oct 2019 - Sep 2020)
- `20B21A`: AFCARS B period (Apr 2020 - Mar 2021)
- `20AB_FY20`: Maltreatment in care (Oct 2019 - Sep 2020, FY20)
- `FY20-21`: Recurrence of maltreatment (FY 2020-2021)

**Period conversion**:
- `make_period_meaningful_rsp()`: Converts period codes to readable labels
  - "20A20B" → "Oct '19 - Sep '20"
  - "20AB_FY20" → "Oct '19 - Sep '20, FY20"
  - "FY20-21" → "FY20-21"

### Data Quality Handling

**DQ Flags**: "DQ" in PDFs indicates data quality issues prevented calculation
- **RSP data**: Preserved as NA in rsp column, includes explanation in data_used
- **Observed data**: Preserved as NA in all three fields (denominator, numerator, observed_performance)
- **Empty periods**: Filtered out (no DQ, no data) to reduce output size

## Common Workflows

### Extracting Data for a New Profile Period

1. **Download PDF** from ShareFile to `S:/Shared Folders/{state}/cfsr/uploads/{YYYY_MM}/`
2. **Run extraction**:
   ```r
   state_code <- "md"
   profile_period <- "2025_02"
   source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")
   ```
3. **Verify outputs**:
   - CSV: `data/processed/md/2025_02/{date}/rsp/` and `/observed/`
   - RDS: `D:/repo_childmetrix/cm-reports/shared/cfsr/data/MD_cfsr_profile_*.rds`
4. **Test Shiny apps** in cm-reports to verify data loads correctly

### Adding Support for a New State

1. **Create state folder structure**: `data/processed/{state}/`
2. **Add state to config** if needed (most configs are state-agnostic)
3. **Run extraction** with new state_code
4. **Add state to cm-reports** navigation and routing

### Troubleshooting Extraction Issues

**Common issues**:
1. **Wrong column alignment**: Check x_cuts against actual period header x-coordinates
   - Debug: Print raw_data for period header row, adjust x_cuts to midpoints between headers
2. **Missing rows**: Check y_tolerance - too small groups rows separately, too large merges unrelated rows
3. **Text fragmentation**: PDF text elements may be split (e.g., "Denomi", "nat", "or")
   - Solution: Use indicator name matching or position-based extraction
4. **Period mismatch**: Some states may have different period coverage
   - Check PDF page 4 for actual periods present, adjust column headers accordingly

## Output Structure

### CSV Columns

**RSP data** (`profile_rsp.R`):
```
state, indicator, period, period_meaningful, data_used,
rsp, rsp_lower, rsp_upper, national_performance,
as_of_date, profile_version, source
```

**Observed data** (`profile_observed.R`):
```
state, indicator, period, period_meaningful,
denominator, numerator, observed_performance,
as_of_date, profile_version, source
```

### File Naming Conventions

- **CSV**: `{state}_{period} - cfsr profile - {type} - {date}.csv`
  - Example: `md_2025_02 - cfsr profile - rsp - 2025-12-14.csv`
- **RDS**: `{STATE}_cfsr_profile_{type}_{period}.rds`
  - Example: `MD_cfsr_profile_rsp_2025_02.rds`

## Integration with cm-reports

The extracted RDS files are consumed by Shiny apps in `cm-reports/shared/cfsr/`:

1. **RDS location**: `cm-reports/shared/cfsr/data/`
2. **App structure**:
   - `app_rsp/`: Risk-Standardized Performance visualizations
   - `app_observed/`: Observed performance charts
   - `app_national/`: National comparison dashboard
3. **Data loading**: Apps use `global.R` to load RDS based on URL parameters (`?state=MD&profile=2025_02`)

## Important Notes

- **Coordinate-based extraction**: Positions are PDF-specific and may vary slightly between profiles
- **Two-table structure**: Both page 2 (RSP) and page 4 (observed) have top table (5 indicators) + bottom table (2 maltreatment)
- **Period consistency**: Observed period format converted to match RSP ("20AB.FY20" → "20AB_FY20")
- **DQ vs Empty**: DQ flags preserved as NA, truly empty periods filtered out
- **Run date folders**: Each run creates dated subfolder (YYYY-MM-DD) for reproducibility
- **Orchestrator pattern**: `run_profile.R` coordinates all scripts, sources functions, manages state
- **Function library**: Shared utilities in `functions_cfsr_profile_rsp.R` used across extraction scripts
- **Dictionary**: `cfsr_round4_indicators_dictionary.csv` provides indicator metadata for joins

## Development Tips

- **Debug PDF coordinates**: Use `View(raw_data)` to inspect x/y positions of text elements
- **Test extraction**: Run individual scripts (profile_rsp.R) after setting state_code/profile_period
- **Verify output**: Check CSV row counts match expected (# indicators × # measure types × # periods with data)
- **Period header detection**: `grep("^[0-9]{2}[AB][0-9]{2}[AB]$", ...)` finds AFCARS period codes
- **Coordinate tolerance**: Start with y_tolerance=5, increase if rows split incorrectly
