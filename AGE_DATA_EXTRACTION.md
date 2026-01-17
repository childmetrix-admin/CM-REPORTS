# Age Data Extraction - National CFSR Profile

## Overview

Extended the national CFSR profile extraction to include age-based demographic breakdowns alongside state-level data. Age data appears in the same Excel sheets below the state data sections.

## Implementation Date

2026-01-16

## Problem

Previously, the extraction functions only captured state-level performance data from the CFSR 4 Data Profile Excel files. Age breakdown data (e.g., "<1 yr", "1-5 yrs", "6-12 yrs", etc.) existed in the same sheets but was not being extracted.

## Solution

Extended `process_standard_indicator()` and `process_entry_rate_indicator()` to:
1. Extract both state rows and age rows from the same Excel sheets
2. Process them using shared logic (same column structure)
3. Add `dimension` and `dimension_value` columns to distinguish between state and demographic data
4. Combine both datasets into unified output

## Data Structure

### New Columns

All national data now includes two new columns positioned after `indicator`:
- **`dimension`**: Type of data breakdown
  - `"State"` for state-level rows
  - `"Age at entry"`, `"Age on 1st day"`, etc. for age breakdowns
- **`dimension_value`**: Specific value within the dimension
  - `NA` for state rows (state name is in `state` column)
  - Age group for age rows (e.g., `"Total"`, `"<1 yr"`, `"1-5 yrs"`)

**Column order**: `state, indicator, dimension, dimension_value, period, ...`

### Column Values by Row Type

**State rows:**
- `dimension = "State"`
- `dimension_value = NA`
- `state = "Maryland"` (actual state name)
- `state_rank = 1-52` (calculated rank)
- `reporting_states = 52` (total states reporting)

**Age rows:**
- `dimension = "Age at entry"` (or similar header text)
- `dimension_value = "<1 yr"` (or specific age group)
- `state = "National"`
- `state_rank = NA` (not applicable for national-level data)
- `reporting_states = NA` (not applicable for national-level data)

## Changes Made

### 1. New Helper Function: `extract_dimension_rows()`

**File:** `D:\repo_childmetrix\cfsr-profile\code\functions\functions_cfsr_profile_excel.R` (lines 118-178)

Extracts demographic breakdown sections from Excel data using pattern matching.

**Parameters:**
- `dimension_header_pattern`: Regex to find dimension header (e.g., `"Age"`)
- `end_marker_pattern`: Regex to find end marker (e.g., `"Race/ethnicity"`)

**Returns:** List with:
- `header`: Dimension header text (e.g., `"Age at entry"`)
- `data`: Dataframe of dimension rows

**Logic:**
- Finds dimension header row by pattern matching on column 1
- Extracts all rows between header and end marker
- Handles varying numbers of dimension values (not hard-coded)

### 2. Updated `process_standard_indicator()`

**File:** `D:\repo_childmetrix\cfsr-profile\code\functions\functions_cfsr_profile_excel.R` (lines 197-367)

**Changes:**
- Extract both state rows and age rows from full sheet
- Created internal helper function `process_rows()` that works for both data types
- Add `dimension` and `dimension_value` columns based on row type
- Split ranking logic: only rank state rows, set rank columns to NA for age rows
- Combine both datasets using `bind_rows()`
- Updated column selection to include `dimension` and `dimension_value`

### 3. Updated `process_entry_rate_indicator()`

**File:** `D:\repo_childmetrix\cfsr-profile\code\functions\functions_cfsr_profile_excel.R` (lines 393-545)

**Changes:**
- Same pattern as `process_standard_indicator()`
- Handles years/periods structure specific to entry rate
- Includes `census_year` column (unlike standard indicators)

### 4. Updated Shiny App Data Loading

**File:** `D:\repo_childmetrix\cm-reports\shared\cfsr\functions\utils.R` (lines 92-105)

**Changes:**
Added filter in `load_cfsr_data()` to exclude age data when loading national profiles:

```r
# For national data: Filter to only state-level rows (exclude age/race demographic breakdowns)
if (type == "national" && "dimension" %in% names(data)) {
  data <- data %>%
    filter(dimension == "State") %>%
    select(-dimension, -dimension_value)
}
```

**Why:** Shiny apps currently only display state-level comparisons. Age breakdown visualization will be added in a future enhancement.

## Testing

To verify the changes work correctly:

```r
# 1. Regenerate national data with age extraction
source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")
run_profile(state = "md", period = "2025_02", source = "national")

# 2. Check that age data is included in national RDS
test_file <- "D:/repo_childmetrix/cfsr-profile/data/national/cfsr_profile_national_2025_02.rds"
national <- readRDS(test_file)

# Verify dimension column exists
stopifnot("dimension" %in% names(national))

# Check state rows
state_rows <- national %>% filter(dimension == "State")
stopifnot(nrow(state_rows) > 0)
stopifnot(all(!is.na(state_rows$state_rank)))

# Check age rows
age_rows <- national %>% filter(dimension != "State")
stopifnot(nrow(age_rows) > 0)
stopifnot(all(age_rows$state == "National"))
stopifnot(all(is.na(age_rows$state_rank)))
stopifnot(all(!is.na(age_rows$dimension_value)))

# 3. Verify Shiny app filters correctly
library(dplyr)
source("D:/repo_childmetrix/cm-reports/shared/cfsr/functions/utils.R")
app_data <- load_cfsr_data(state = "MD", profile = "2025_02", type = "national")

# Should not have dimension column (filtered out)
stopifnot(!"dimension" %in% names(app_data))

# Should only have state rows
stopifnot(all(app_data$state != "National"))
```

## Backwards Compatibility

- **Old RDS files** (before this change): Do not have `dimension` column
  - Shiny app check: `"dimension" %in% names(data)` ensures filter only runs on new files
  - Old files load normally without filtering

- **New RDS files**: Have `dimension` column
  - Shiny apps filter to `dimension = "State"` and remove dimension columns
  - Maintains same column structure as old files for app compatibility

## Future Work

### Phase 2: Race/Ethnicity Data
- Extend `extract_dimension_rows()` to handle race/ethnicity sections
- Same pattern as age data extraction
- Update `process_rows()` helper to handle race data

### Phase 3: Shiny App Enhancement
- Add tab in indicator detail pages for "By Age" view
- Display age breakdown charts using national age data
- Similar to existing "By State" tab
- Filter national data to age rows: `filter(dimension == "Age at entry")`

## Rollout

**Priority:** Medium - Adds new data without breaking existing functionality

**Steps:**
1. Regenerate national RDS files for all periods in production
2. Verify age data appears correctly in RDS files
3. Test Shiny apps load correctly (should auto-filter to state rows only)
4. No changes needed to observed/RSP data or apps

## Files Changed

1. `D:\repo_childmetrix\cfsr-profile\code\functions\functions_cfsr_profile_excel.R`
   - Added `extract_dimension_rows()` helper function
   - Updated `process_standard_indicator()` to extract age data
   - Updated `process_entry_rate_indicator()` to extract age data
   - Updated function documentation

2. `D:\repo_childmetrix\cm-reports\shared\cfsr\functions\utils.R`
   - Updated `load_cfsr_data()` to filter out age data for Shiny apps
   - Added backwards compatibility check for `dimension` column
