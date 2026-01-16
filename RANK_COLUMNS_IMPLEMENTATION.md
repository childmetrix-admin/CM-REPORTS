# Implementation: Adding Rank Columns to Observed Data

## Summary

Enhanced the observed data extraction pipeline to include `state_rank` and `reporting_states` columns from the national data. This allows the Summary app to display state rankings without loading a second data file.

## Changes Made

### File Modified: `code/profile_observed.R`

**Location:** Lines 329-381 (new section: ADD RANK COLUMNS FROM NATIONAL DATA)

**What Changed:**
1. Added new section AFTER validation and BEFORE CSV/RDS save
2. Loads national RDS file and performs left join on `indicator`, `period`, and `state_abb`
3. Adds `state_rank` and `reporting_states` columns to `observed_data`
4. If national data not found, adds placeholder NA columns so structure is consistent
5. Updates column selection to include rank columns (lines 374-375)
6. Simplified RDS save section - now just saves `observed_data` directly (line 420)

**Result:** Both CSV and RDS files now contain the same 36 columns including rank data

### New Columns Added to Observed RDS Files

| Column | Type | Source | Description |
|--------|------|--------|-------------|
| `state_rank` | integer | National data | State's rank for this indicator/period (1 = best) |
| `reporting_states` | integer | National data | Number of states reporting data for this indicator/period |

## Dependencies

**IMPORTANT:** The national data file must be generated BEFORE the observed data file for each state/period.

**Recommended run order:**
1. Run `profile_national.R` first (generates `cfsr_profile_national_{YYYY_MM}.rds`)
2. Run `profile_observed.R` second (adds rank columns from national data)

If national data doesn't exist, the script will:
- Issue a warning
- Save observed data WITHOUT rank columns
- Suggest running `profile_national.R` first

## Usage

### Using the Orchestrator (Recommended)

```r
# Run all data sources for MD 2025_02 (national will run first)
source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")
run_profile(state = "md", period = "2025_02")
```

### Manual Execution

```r
# Step 1: Generate national data
source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")
run_profile(state = "md", period = "2025_02", source = "national")

# Step 2: Generate observed data with rank columns
run_profile(state = "md", period = "2025_02", source = "observed")
```

## Testing

A test script is provided to verify the implementation:

```r
source("D:/repo_childmetrix/cfsr-profile/code/test_rank_columns.R")
```

**Expected output:**
- ✓ Both `state_rank` and `reporting_states` columns present
- Sample data showing rank values
- Data quality report (NA counts)

## Impact on Apps

### Summary App (`cm-reports/shared/cfsr/summary/app_summary/`)

**Benefit:** Can now display state rankings without loading national data

**Before:**
```r
observed_data <- load_observed_data(state, profile)
# Rank columns not available - would need to load national data separately
```

**After:**
```r
observed_data <- load_observed_data(state, profile)
# Rank columns included in observed data: state_rank, reporting_states
# CSV and RDS both have identical 36-column structure
```

**Next Steps:**
- Update summary app UI to add "Rank" column
- Format rank as "3 of 52" using `state_rank` and `reporting_states`

### Other Apps (RSP, Observed)

**No impact:** These apps don't need rank columns, but they're available if needed in the future.

## Data Structure

### Observed CSV and RDS Files (After Enhancement)

**CSV Filename:** `data/processed/{state}/{period}/{date}/observed/observed_data_{timestamp}.csv`
**RDS Filename:** `{STATE}_cfsr_profile_observed_{YYYY_MM}.rds`

**New Total Columns:** 36 (was 34)
- Original 34 columns (state, indicator, period, performance, status, etc.)
- **+2 NEW:** `state_rank`, `reporting_states`

**Important:** CSV and RDS now have identical structure - RDS is simply a snapshot of the CSV data

**Column Order:**
```
state, state_abb, category, indicator, period, period_meaningful,
denominator, numerator, observed_performance,
national_standard, status, data_used,
as_of_date, profile_version, source,
state_rank, reporting_states,  <-- NEW (added after source, before dictionary metadata)
indicator_sort, indicator_short, indicator_very_short,
description, denominator_def, numerator_def,
direction_rule, direction_desired, direction_legend,
decimal_precision, scale, format,
risk_adjustment, exclusions, notes
```

## Validation

The script includes automatic validation:

✓ **Match reporting:** Shows how many rows successfully got rank data from join
✓ **Graceful fallback:** If national data missing, adds placeholder NA columns so structure is consistent
✓ **Column structure:** CSV and RDS always have same 36 columns (even if rank values are NA)

## Regenerating Existing Data

To add rank columns to existing observed RDS files:

```r
# Regenerate all observed files for a specific period
source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")
run_profile(period = "2025_02", source = "observed")

# Regenerate for specific state/period
run_profile(state = "md", period = "2025_02", source = "observed")
```

**Note:** National data must already exist for the target period.

## Troubleshooting

### Issue: "National data file not found"

**Cause:** National RDS doesn't exist for this profile period

**Result:** Script continues and adds NA placeholder columns so structure is consistent

**Solution (to add real rank data):**
```r
run_profile(state = "md", period = "2025_02", source = "national")
# Then regenerate observed:
run_profile(state = "md", period = "2025_02", source = "observed")
```

### Issue: Many rows have rank=NA

**Possible causes:**
- Expected for certain periods (FY periods in Maltreatment indicators don't match ABAB periods in national data)
- National data may not have all indicators for all periods
- Check which indicator-period combinations are unmatched (script reports this)

## Implementation Date

2026-01-16

## Related Files

- `code/profile_observed.R` - Main extraction script (modified)
- `code/profile_national.R` - National data extraction (unchanged)
- `code/test_rank_columns.R` - Test script (new)
- `shared/cfsr/data/` - RDS output directory
