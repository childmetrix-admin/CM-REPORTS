# Fix: Period Format Standardization (Comma to Underscore)

## Problem

The join between national data and observed/RSP data was failing for Maltreatment in Care indicator because of inconsistent period formats:

- **National data**: Used comma separator (e.g., `"20AB,FY20"`)
- **Observed/RSP data**: Used underscore separator (e.g., `"20AB_FY20"`)

This caused the left join in `profile_observed.R` (lines 344-349) to fail, leaving `state_rank` and `reporting_states` as NA for Maltreatment indicators.

## Solution

Updated the national extraction script to replace commas with underscores in the period column **before** creating `period_meaningful`. This ensures consistency across all data sources.

## Changes Made

### File: `code/functions/functions_cfsr_profile_nat.R`

**Function: `process_standard_indicator()`** (Lines 160-175)

Added period format fix before `period_meaningful` creation:

```r
final_df <- data_long %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),
    denominator = as.numeric(denominator),
    numerator = as.numeric(numerator),
    performance = as.numeric(performance),
    indicator = indicator_name,
    # Fix period format: replace comma with underscore (e.g., "20AB,FY20" => "20AB_FY20")
    # This ensures period matches the format used in observed/RSP data for proper joins
    period = gsub(",", "_", period),
    as_of_date = as_of_date,
    source = ver$source,
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  )
```

**Function: `process_entry_rate_indicator()`** (Lines 266-278)

Added same period format fix:

```r
final_df <- final_df %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),
    census_year = as.numeric(year),
    indicator = indicator_name,
    # Fix period format: replace comma with underscore (e.g., "20AB,FY20" => "20AB_FY20")
    # This ensures period matches the format used in observed/RSP data for proper joins
    period = gsub(",", "_", period),
    as_of_date = as_of_date,
    source = ver$source,
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  )
```

## Impact

### ✅ Period Format Now Consistent

**Before:**
- National CSV/RDS: `period = "20AB,FY20"`
- Observed CSV/RDS: `period = "20AB_FY20"`
- RSP CSV/RDS: `period = "20AB_FY20"`
- **Join fails** ❌

**After:**
- National CSV/RDS: `period = "20AB_FY20"`
- Observed CSV/RDS: `period = "20AB_FY20"`
- RSP CSV/RDS: `period = "20AB_FY20"`
- **Join succeeds** ✅

### ✅ Period Meaningful Still Works

The `make_period_meaningful()` function in `functions_cfsr_profile_shared.R` handles both formats:

- **Case 3** (line 660): Matches `"^[0-9]{2}AB_FY[0-9]{2}$"` (underscore)
- **Case 3a** (line 674): Matches `"^[0-9]{2}AB,FY[0-9]{2}$"` (comma)

Both produce identical output: `"Oct '19 - Sep '20, FY20"`

Since we now convert commas to underscores before calling the function, Case 3 (underscore) will match and produce the correct result.

## Testing

To verify the fix works:

```r
# 1. Regenerate national data (will have underscore format)
source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")
run_profile(state = "md", period = "2025_02", source = "national")

# 2. Regenerate observed data (join should now succeed for Maltreatment)
run_profile(state = "md", period = "2025_02", source = "observed")

# 3. Check that rank columns populated correctly
test_file <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data/MD_cfsr_profile_observed_2025_02.rds"
observed <- readRDS(test_file)

# Look at Maltreatment in Care specifically
observed %>%
  filter(grepl("Maltreatment", indicator)) %>%
  select(indicator_short, period, state_rank, reporting_states) %>%
  print()

# Should see rank values (not NA)
```

## Rollout

**Priority:** High - Fixes broken rank joins for Maltreatment indicators

**Steps:**
1. Regenerate national RDS files for all periods in production
2. Regenerate observed RDS files for all states/periods
3. Verify rank columns populated correctly in Summary app

## Implementation Date

2026-01-16
