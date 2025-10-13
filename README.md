# CFSR Profile Data Processing Project

## Overview

This R project processes **National Supplemental Context Data** files from the Children's Bureau that track state-by-state performance on **Child and Family Services Review (CFSR)** statewide data indicators. The data files are provided to states approximately every 6 months (typically February and August) and include:

- State-by-state performance and trends on CFSR statewide data indicators
- Foster care entry rates
- National performance by age, race/ethnicity

## Project Structure

```
D:\repo_childmetrix\r_cfsr_profile\
│
├── code/
│   └── r_cfsr_profile.R          # Main processing script
│
├── data/
│   └── YYYY_MM/                  # Period-specific data folders (e.g., 2025_02/)
│       ├── raw/                  # Raw input files
│       │   └── National - Supplemental Context Data - [Month YYYY].xlsx
│       └── processed/            # Processed output files
│           └── YYYY-MM-DD/       # Run-specific outputs (timestamped)
│
└── r_cfsr_profile.Rproj          # RStudio project file
```

## Dependencies

### External Utilities

This project depends on centralized R utilities located at:
**`D:\repo_childmetrix\r_utilities\`**

#### Core Dependencies:
- **[loader.R](D:/repo_childmetrix/r_utilities/loader.R)** - Centralized loader that sources all utility scripts
- **[core/r_load_packages.R](D:/repo_childmetrix/r_utilities/core/r_load_packages.R)** - Package management (40+ tidyverse and data science packages)
- **[core/generic_functions.R](D:/repo_childmetrix/r_utilities/core/generic_functions.R)** - Reusable helper functions:
  - `setup_folders()` - Creates project directory structure
  - `find_file()` - Smart file finder for raw/processed folders
  - `save_to_folder_run()` - Standardized file output with naming conventions
  - `to_date_safe()` - Robust date parsing from multiple formats
  - `get_period_dates()` - Quarter/month/year period calculations

#### Project-Specific Functions:
- **[project_specific/functions_cfsr_profile.R](D:/repo_childmetrix/r_utilities/project_specific/functions_cfsr_profile.R)** - CFSR-specific utilities:
  - `cfsr_profile_version()` - Extracts profile month/year from filename
  - `cfsr_profile_extract_asof_date()` - Parses AFCARS/NCANDS submission date
  - `extract_relevant_rows()` - Filters data to state performance rows
  - `make_period_meaningful()` - Converts period codes (e.g., "19A19B") to readable labels
  - `rank_states_by_performance()` - Ranks states by most recent performance

### R Packages

The project uses 40+ packages managed via `pacman`, including:
- **tidyverse** (dplyr, tidyr, ggplot2, stringr, purrr, readr)
- **openxlsx** / **readxl** - Excel file I/O
- **lubridate** - Date/time manipulation
- **janitor** - Data cleaning
- **flextable** / **gt** - Table formatting
- And many more (see [r_load_packages.R](D:/repo_childmetrix/r_utilities/core/r_load_packages.R:1))

## Data Processing Workflow

### 1. Setup and Initialization

```r
# Load all utilities and packages
source("D:/repo_childmetrix/r_utilities/loader.R")
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"))

# Configure project
commitment <- "cfsr profile"
commitment_description <- "national"

# Set up folder structure for reporting period (e.g., 2025_02)
my_setup <- setup_folders("2025_02")
```

This creates:
- `data/2025_02/raw/`
- `data/2025_02/processed/`
- `output/2025_02/`
- `data/2025_cumulative/`

### 2. Processed Indicators

The script processes 6 key CFSR indicators from separate Excel worksheets:

| Indicator | Worksheet Name | Output Dataset |
|-----------|---------------|----------------|
| Foster care entry rate per 1,000 children | Entry rates | `ind_entrate_df` |
| Re-entry into foster care after exiting to reunification/guardianship | Reentry to FC | `ind_reentry_df` |
| Permanency in 12 months (entries) | Perm in 12 (entries) | `ind_perm12_df` |
| Permanency in 12 months (12-23 months in care) | Perm in 12 (12-23 mos) | `ind_perm1223_df` |
| Permanency in 12 months (24+ months in care) | Perm in 12 (24+ mos) | `ind_perm24_df` |
| Placement stability (moves/1,000 days in care) | Placement stability | `ind_ps_df` |

### 3. Data Processing Steps (Per Indicator)

Each indicator follows this pipeline:

#### a. Load Data
```r
data_df <- find_file(
  keyword = "National",
  directory_type = "raw",
  file_type = "excel",
  sheet_name = "Entry rates"  # or other worksheet
)
```

#### b. Extract Metadata
```r
# Profile version
ver <- cfsr_profile_version()
ver$profile_version  # "August 2024"
ver$source          # Full APA citation

# AFCARS/NCANDS submission date
asof <- cfsr_profile_extract_asof_date(data_df)
asof$as_of_date     # Date object
```

#### c. Clean and Reshape
```r
# Filter to relevant columns and state rows
data_df <- extract_relevant_rows(data_df)

# Extract period metadata (years/periods from first row)
metadata <- data_df[1, ]
periods <- metadata[7:11] %>% as.character()

# Rename columns dynamically
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# Reshape wide to long
final_df <- data_clean %>%
  pivot_longer(...) %>%
  left_join(period_to_year, by = "period")
```

#### d. Enrich and Rank
```r
final_df <- final_df %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),
    indicator = "Foster care entry rate per 1,000",
    period_meaningful = make_period_meaningful(period),  # "Oct '18 - Sep '19"
    as_of_date = as_of_date,
    source = ver$source,
    profile_version = ver$profile_version
  ) %>%
  rank_states_by_performance()  # Ranks by most recent period only
```

#### e. Select Final Columns
```r
ind_entrate_df <- final_df %>%
  select(state, indicator, period, period_meaningful,
         denominator, numerator, performance, state_rank,
         census_year, as_of_date, profile_version, source)
```

### 4. Combine and Save

```r
# Combine all indicators
ind_data <- bind_rows(
  ind_entrate_df, ind_reentry_df, ind_perm12_df,
  ind_perm1223_df, ind_perm24_df, ind_ps_df
)

# Save to data/2025_02/processed/YYYY-MM-DD/
# Filename: 2025_02 - cfsr profile - national - YYYY-MM-DD.csv
save_to_folder_run(ind_data, "csv")
```

## Output Data Structure

The final dataset contains these columns:

| Column | Type | Description |
|--------|------|-------------|
| `state` | chr | State name (52 total: 50 states + D.C. + Puerto Rico) |
| `indicator` | chr | Full indicator name |
| `period` | chr | Raw period code (e.g., "19A19B") |
| `period_meaningful` | chr | Human-readable period (e.g., "Oct '18 - Sep '19") |
| `denominator` | num | Population denominator |
| `numerator` | num | Event numerator |
| `performance` | num | Performance metric (rate, percentage, or ratio) |
| `state_rank` | int | State ranking (1-52, only for most recent period) |
| `census_year` | int | Reference year (for entry rate only) |
| `as_of_date` | Date | AFCARS/NCANDS data submission date |
| `profile_version` | chr | Profile publication (e.g., "February 2025") |
| `source` | chr | Full APA citation |

## Key Functions Reference

### From `generic_functions.R`

#### `setup_folders(folder_date)`
Creates standardized directory structure and sets global path variables.
- **Input**: `"2025_02"` or `"2024_Q3"` or `"2024_CY"`
- **Globals set**: `folder_raw`, `folder_processed`, `folder_output`, `folder_cumulative`, `reporting_period_start`, `reporting_period_end`

#### `find_file(keyword, directory_type, file_type, sheet_name)`
Locates and reads files from raw/processed folders.
- **Example**: `find_file("National", "raw", "excel", "Entry rates")`
- Returns data frame directly

#### `save_to_folder_run(df, ext)`
Saves output with standardized naming convention.
- **Naming**: `[folder_date] - [commitment] - [commitment_description] - [run_date].[ext]`
- Creates run-specific timestamped subfolder

### From `functions_cfsr_profile.R`

#### `cfsr_profile_version()`
Extracts profile month/year from filename pattern:
`"National - Supplemental Context Data - February 2025.xlsx"`
- **Returns**: List with `profile_version`, `month`, `year`, `source` (APA citation)

#### `cfsr_profile_extract_asof_date(data_df)`
Parses AFCARS/NCANDS submission date from header row like:
`"AFCARS and NCANDS submissions as of 08-15-2024"`
- **Returns**: List with `as_of_date` (Date), `date_string`, `header_text`
- **Side effect**: Sets global `as_of_date`

#### `extract_relevant_rows(data_df)`
Filters Excel data to:
- Period metadata row (first row matching year/period pattern)
- State rows (Alabama through Wyoming, 52 total)

#### `make_period_meaningful(period)`
Converts period codes to readable labels:
- `"19A19B"` → `"Oct '18 - Sep '19"`
- `"19B20A"` → `"Apr '19 - Mar '20"`

#### `rank_states_by_performance(df)`
Ranks states 1-52 based on performance in the most recent period only.
- Handles missing values (`NA`) appropriately
- Earlier periods receive `NA` for `state_rank`

## Usage Instructions

### Prerequisites

1. Ensure `D:\repo_childmetrix\r_utilities\` is accessible
2. Install required packages (automatically handled by `loader.R` via `pacman`)
3. Obtain National Supplemental Context Data file from Children's Bureau

### Running the Script

1. **Copy raw data file** to `data/YYYY_MM/raw/` folder:
   ```
   National - Supplemental Context Data - February 2025.xlsx
   ```

2. **Update period in script** ([r_cfsr_profile.R:50](code/r_cfsr_profile.R#L50)):
   ```r
   my_setup <- setup_folders("2025_02")  # Change to current period
   ```

3. **Run the script**:
   ```r
   source("D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R")
   ```

4. **Output location**:
   ```
   data/2025_02/processed/YYYY-MM-DD/2025_02 - cfsr profile - national - YYYY-MM-DD.csv
   ```

## Data Source

**Children's Bureau, Administration for Children and Families**
U.S. Department of Health & Human Services
Administration on Children, Youth and Families

Files provided biannually (February & August) containing:
- AFCARS (Adoption and Foster Care Analysis and Reporting System) data
- NCANDS (National Child Abuse and Neglect Data System) data

## Notes

- **Data file format**: Each indicator occupies a separate worksheet with consistent structure:
  - Row 1: Period labels (year or period codes like "19A19B")
  - Subsequent rows: State data (52 rows: Alabama → Wyoming)
  - Columns grouped as: denominator(s), numerator(s), performance metric(s)

- **Period codes**:
  - `YYAYYB` format: 12-month fiscal year Oct-Sep (e.g., "19A19B" = Oct 2018 - Sep 2019)
  - `YYBZZA` format: 12-month fiscal year Apr-Mar (e.g., "19B20A" = Apr 2019 - Mar 2020)

- **State ranking**: Only calculated for the most recent period to support current comparisons

- **Naming convention**: D.C. (not "District of Columbia") for consistency with other outputs

## Recent Refactoring (2025-10-09)

The main processing script was recently refactored to eliminate code duplication:
- **Before**: 604 lines with repeated code
- **After**: 139 lines using reusable functions
- **Reduction**: 77% fewer lines, 100% elimination of redundant code

### New Functions Added
- `process_standard_indicator()` - Handles 5 of 6 indicators
- `process_entry_rate_indicator()` - Handles Entry Rate (special case)

### Documentation
- **[REFACTORING_ANALYSIS.md](REFACTORING_ANALYSIS.md)** - Detailed analysis of refactoring opportunities
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - What was changed and why
- **[FUNCTION_USAGE_GUIDE.md](FUNCTION_USAGE_GUIDE.md)** - Quick reference for using new functions

### Benefits
- ✅ Easier to add new indicators (6 lines instead of 80)
- ✅ Single source of truth for processing logic
- ✅ Fixed potential metadata inconsistency bug
- ✅ Metadata now extracted once instead of 6 times

## Author

Joy (Purpose noted in script header: [r_cfsr_profile.R:4](code/r_cfsr_profile.R#L4))

## Related Projects

This project shares utilities with other Child Metrics projects:
- MDCPS project (Maryland child welfare data)
- Other state/national child welfare analyses

All share the centralized `r_utilities` folder for consistency and maintainability.
