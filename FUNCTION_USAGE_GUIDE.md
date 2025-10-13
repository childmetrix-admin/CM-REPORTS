# CFSR Profile Functions - Quick Reference Guide

## Overview

This guide shows how to use the refactored CFSR profile processing functions.

---

## Function 1: `process_standard_indicator()`

### Purpose
Processes indicators that have standard den/num/per column structure (5 of 6 indicators).

### Basic Usage
```r
ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  indicator_name = "Re-entry into foster care after exiting to reunification or guardianship"
)
```

### Full Parameters
```r
process_standard_indicator(
  sheet_name,           # Required: Excel worksheet name
  indicator_name,       # Required: Full indicator display name
  keep_cols = c(1:10), # Optional: Column range to select
  period_cols = 2:4,   # Optional: Columns containing period labels
  ver = NULL,          # Optional: Profile version (gets from global if NULL)
  as_of_date = NULL    # Optional: AFCARS date (gets from global if NULL)
)
```

### Returns
Tibble with columns:
- `state`
- `indicator`
- `period`
- `period_meaningful`
- `denominator`
- `numerator`
- `performance`
- `state_rank` (only for most recent period)
- `as_of_date`
- `profile_version`
- `source`

### Examples

#### Example 1: Re-Entry (standard usage)
```r
ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  indicator_name = "Re-entry into foster care after exiting to reunification or guardianship",
  ver = ver,
  as_of_date = asof$as_of_date
)
```

#### Example 2: Placement Stability (standard usage)
```r
ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  indicator_name = "Placement stability (moves/1,000 days in care)",
  ver = ver,
  as_of_date = asof$as_of_date
)
```

#### Example 3: Custom column range
If an indicator has more columns (e.g., 12 instead of 10):
```r
ind_custom_df <- process_standard_indicator(
  sheet_name = "New Indicator",
  indicator_name = "New Indicator Name",
  keep_cols = c(1:12),    # Override default c(1:10)
  period_cols = 2:5,      # Override default 2:4
  ver = ver,
  as_of_date = asof$as_of_date
)
```

#### Example 4: Using global variables (simplest)
If `ver` and `as_of_date` are in global environment:
```r
ind_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  indicator_name = "Re-entry into foster care after exiting to reunification or guardianship"
)
# Function will automatically get ver and as_of_date from global env
```

---

## Function 2: `process_entry_rate_indicator()`

### Purpose
Processes the Entry Rate indicator (special case with years and census_year column).

### Basic Usage
```r
ind_entrate_df <- process_entry_rate_indicator(ver, asof$as_of_date)
```

### Full Parameters
```r
process_entry_rate_indicator(
  ver = NULL,          # Optional: Profile version (gets from global if NULL)
  as_of_date = NULL    # Optional: AFCARS date (gets from global if NULL)
)
```

### Returns
Tibble with columns:
- `state`
- `indicator`
- `period`
- `period_meaningful`
- `denominator`
- `numerator`
- `performance`
- `state_rank` (only for most recent period)
- `census_year` ⭐ (unique to Entry Rate)
- `as_of_date`
- `profile_version`
- `source`

### Examples

#### Example 1: Explicit parameters (recommended)
```r
ind_entrate_df <- process_entry_rate_indicator(
  ver = ver,
  as_of_date = asof$as_of_date
)
```

#### Example 2: Using global variables
If `ver` and `as_of_date` are in global environment:
```r
ind_entrate_df <- process_entry_rate_indicator()
# Function will automatically get ver and as_of_date from global env
```

---

## Complete Workflow Example

### Step 1: Setup
```r
# Load utilities
source("D:/repo_childmetrix/r_utilities/loader.R")
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"))

# Set up project
commitment <- "cfsr profile"
commitment_description <- "national"
my_setup <- setup_folders("2025_02")
```

### Step 2: Extract Metadata (Once)
```r
# Profile version and citation (shared across all indicators)
ver <- cfsr_profile_version()

# AFCARS/NCANDS submission date (shared across all indicators)
data_df_temp <- find_file(
  keyword = "National",
  directory_type = "raw",
  file_type = "excel",
  sheet_name = "Entry rates"
)
asof <- cfsr_profile_extract_asof_date(data_df_temp)
```

### Step 3: Process All Indicators
```r
# Entry Rate (special case)
ind_entrate_df <- process_entry_rate_indicator(ver, asof$as_of_date)

# Re-Entry
ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  indicator_name = "Re-entry into foster care after exiting to reunification or guardianship",
  ver = ver,
  as_of_date = asof$as_of_date
)

# Permanency in 12 months (entries)
ind_perm12_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (entries)",
  indicator_name = "Permanency in 12 mos (entries)",
  ver = ver,
  as_of_date = asof$as_of_date
)

# Permanency in 12 months (12-23 months in care)
ind_perm1223_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (12-23 mos)",
  indicator_name = "Permanency in 12 mos (12-23 mos)",
  ver = ver,
  as_of_date = asof$as_of_date
)

# Permanency in 12 months (24+ months in care)
ind_perm24_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (24+ mos)",
  indicator_name = "Permanency in 12 mos (24+ mos)",
  ver = ver,
  as_of_date = asof$as_of_date
)

# Placement Stability
ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  indicator_name = "Placement stability (moves/1,000 days in care)",
  ver = ver,
  as_of_date = asof$as_of_date
)
```

### Step 4: Combine and Save
```r
ind_data <- bind_rows(
  ind_entrate_df,
  ind_reentry_df,
  ind_perm12_df,
  ind_perm1223_df,
  ind_perm24_df,
  ind_ps_df
)

save_to_folder_run(ind_data, "csv")
```

---

## Adding Future Indicators

### For Standard Indicators (den/num/per structure)

```r
# Example: Maltreatment in Care
ind_maltreatment_df <- process_standard_indicator(
  sheet_name = "Maltreatment in care",
  indicator_name = "Maltreatment in foster care",
  ver = ver,
  as_of_date = asof$as_of_date
)

# Add to combine step
ind_data <- bind_rows(
  ind_entrate_df,
  ind_reentry_df,
  ind_perm12_df,
  ind_perm1223_df,
  ind_perm24_df,
  ind_ps_df,
  ind_maltreatment_df  # ← Add here
)
```

### For Non-Standard Indicators

If indicator has different structure, create new function in `functions_cfsr_profile.R`:

```r
process_custom_indicator <- function(sheet_name, indicator_name, ver = NULL, as_of_date = NULL) {
  # Custom processing logic here
  # Follow pattern from process_standard_indicator()
  # Return tibble with same column structure
}
```

---

## Troubleshooting

### Error: "folder_raw is not defined"
**Solution**: Run `setup_folders()` before calling processing functions
```r
my_setup <- setup_folders("2025_02")
```

### Error: "object 'ver' not found"
**Solution**: Extract metadata before processing indicators
```r
ver <- cfsr_profile_version()
```

### Error: "object 'as_of_date' not found"
**Solution**: Extract AFCARS date before processing
```r
data_df_temp <- find_file(keyword = "National", directory_type = "raw",
                          file_type = "excel", sheet_name = "Entry rates")
asof <- cfsr_profile_extract_asof_date(data_df_temp)
```

### Error: "No 'National*.xlsx' file found"
**Solution**: Copy raw data file to data/YYYY_MM/raw/ folder
```
data/2025_02/raw/National - Supplemental Context Data - February 2025.xlsx
```

### Wrong column count error
**Solution**: Adjust `keep_cols` parameter
```r
# If indicator has 12 columns instead of 10
ind_df <- process_standard_indicator(
  sheet_name = "Sheet Name",
  indicator_name = "Indicator Name",
  keep_cols = c(1:12),  # ← Adjust this
  ver = ver,
  as_of_date = asof$as_of_date
)
```

---

## Tips & Best Practices

### ✅ DO
- Extract metadata once at the beginning
- Pass `ver` and `as_of_date` explicitly to functions
- Use descriptive `indicator_name` that matches output requirements
- Verify sheet names match exactly (case-sensitive)

### ❌ DON'T
- Don't extract metadata separately for each indicator
- Don't modify function parameters unless indicator structure differs
- Don't forget to add new indicators to `bind_rows()` step

---

## Column Specifications

### Standard Structure (5 indicators)
```
Column 1: State name
Columns 2-4: Period labels (e.g., "19A19B", "19B20A", "20A20B")
Columns 5-7: Denominators (by period)
Columns 8-10: Numerators (by period)
Columns 11-13: Performance values (by period)  [Not selected by default keep_cols]
```

### Entry Rate Structure (1 indicator)
```
Column 1: State name
Columns 2-6: Years (e.g., 2019, 2020, 2021, 2022, 2023)
Columns 7-11: Period labels (e.g., "19A19B", "19B20A", ...)
Columns 12-16: Child population by year (denominators)  [Maps to years]
```

---

## Function Source Code Location

Both functions are in:
**`D:\repo_childmetrix\r_utilities\project_specific\functions_cfsr_profile.R`**

- `process_standard_indicator()` starts at line 155
- `process_entry_rate_indicator()` starts at line 242

---

## Related Documentation

- **[README.md](README.md)** - Project overview and setup
- **[REFACTORING_ANALYSIS.md](REFACTORING_ANALYSIS.md)** - Detailed refactoring rationale
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - What was changed and why
- **[FUNCTION_USAGE_GUIDE.md](FUNCTION_USAGE_GUIDE.md)** - This file

---

## Quick Reference Card

```r
# SETUP
source("D:/repo_childmetrix/r_utilities/loader.R")
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"))
my_setup <- setup_folders("2025_02")

# METADATA (once)
ver <- cfsr_profile_version()
data_df_temp <- find_file(keyword = "National", directory_type = "raw",
                          file_type = "excel", sheet_name = "Entry rates")
asof <- cfsr_profile_extract_asof_date(data_df_temp)

# PROCESS INDICATORS
ind_entrate_df <- process_entry_rate_indicator(ver, asof$as_of_date)
ind_reentry_df <- process_standard_indicator("Reentry to FC", "Re-entry...", ver = ver, as_of_date = asof$as_of_date)
# ... repeat for other indicators ...

# COMBINE & SAVE
ind_data <- bind_rows(ind_entrate_df, ind_reentry_df, ...)
save_to_folder_run(ind_data, "csv")
```
