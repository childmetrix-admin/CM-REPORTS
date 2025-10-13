# CFSR Profile Script - Refactoring Analysis

## Executive Summary

The [r_cfsr_profile.R](code/r_cfsr_profile.R) script contains significant code duplication across 6 indicator processing sections. **Approximately 480 lines of the 604-line script (79%) consist of repeated code patterns** that can be consolidated into reusable functions.

## Identified Refactoring Opportunities

### 1. **CRITICAL: Metadata Extraction (Lines 66-76 repeated 6x)**

**Issue**: Profile version and as_of_date are extracted once per indicator but are identical across all indicators.

**Current Code** (repeated 6 times):
```r
ver <- cfsr_profile_version()
asof <- cfsr_profile_extract_asof_date(data_df)  # Only done for Entry Rate
```

**Refactoring**: Extract metadata ONCE at the beginning after loading the first sheet.

**Location**: Main script (not a function - just reorganize)

**Benefits**:
- Eliminates 5 redundant function calls to `cfsr_profile_version()`
- Eliminates potential inconsistency if metadata differs across sheets
- Clarifies that metadata is file-level, not indicator-level
- `as_of_date` is currently only extracted for Entry Rate (line 73) but used in ALL indicators

---

### 2. **HIGH PRIORITY: Standard Indicator Processing Function**

**Issue**: Lines 186-263 (Re-Entry through Placement Stability) are nearly identical, repeated 5 times with only 3 variables changing.

**Repeated Pattern** (80 lines × 5 indicators = 400 lines):
```r
# 1. Load sheet
data_df <- find_file(keyword = "National",
                     directory_type = "raw",
                     file_type = "excel",
                     sheet_name = "SHEET_NAME")  # VARIABLE 1

# 2. Select columns
keep_cols <- c(1:10)  # VARIABLE 2
data_df <- data_df[, keep_cols, drop = FALSE]
data_df <- extract_relevant_rows(data_df)

# 3. Extract metadata
metadata <- data_df[1, ]
periods <- metadata[2:4] %>% as.character()  # VARIABLE 3
data_clean <- data_df[-1, ]

# 4. Rename columns
den_cols <- paste0("den_", periods)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# 5. Convert to numeric
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

# 6. Reshape wide to long
data_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("den") | starts_with("num") | starts_with("per"),
    names_to = c(".value", "period"),
    names_pattern = "(den|num|per)_(\\d+[A-Z]\\d+[A-Z])"
  ) %>%
  rename(denominator = den, numerator = num, performance = per)

# 7. Add metadata columns
final_df <- data_long %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),
    denominator = as.numeric(denominator),
    numerator = as.numeric(numerator),
    performance = as.numeric(performance),
    indicator = "INDICATOR_NAME",  # VARIABLE 4
    as_of_date = as_of_date,
    source = ver$source,
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  )

# 8. Rank states
final_df <- rank_states_by_performance(final_df)

# 9. Select final columns
ind_df <- final_df %>%
  select(state, indicator, period, period_meaningful, denominator, numerator,
         performance, state_rank, as_of_date, profile_version, source)
```

**Refactoring**: Create function `process_standard_indicator()`

**Proposed Function** (add to `functions_cfsr_profile.R`):
```r
# Process standard CFSR indicator with den/num/per structure
# ----------------------------
#
# Handles 5 of 6 indicators (all except Entry Rate which has years/census data)
#
# @param sheet_name: Excel worksheet name
# @param indicator_name: Full indicator display name
# @param keep_cols: Column range to select (e.g., c(1:10))
# @param period_cols: Column indices for period labels (e.g., 2:4)
# @param ver: Profile version list from cfsr_profile_version()
# @param as_of_date: Date from cfsr_profile_extract_asof_date()
#
# @return: Tibble with standardized indicator structure

process_standard_indicator <- function(sheet_name,
                                       indicator_name,
                                       keep_cols = c(1:10),
                                       period_cols = 2:4,
                                       ver = NULL,
                                       as_of_date = NULL) {

  # Get from global env if not provided
  if (is.null(ver)) ver <- get("ver", envir = .GlobalEnv)
  if (is.null(as_of_date)) as_of_date <- get("as_of_date", envir = .GlobalEnv)

  # 1. Load sheet
  data_df <- find_file(
    keyword = "National",
    directory_type = "raw",
    file_type = "excel",
    sheet_name = sheet_name
  )

  # 2. Select columns and rows
  data_df <- data_df[, keep_cols, drop = FALSE]
  data_df <- extract_relevant_rows(data_df)

  # 3. Extract metadata
  metadata <- data_df[1, ]
  periods <- metadata[period_cols] %>% as.character()
  data_clean <- data_df[-1, ]

  # 4. Rename columns
  den_cols <- paste0("den_", periods)
  num_cols <- paste0("num_", periods)
  per_cols <- paste0("per_", periods)
  colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

  # 5. Convert to numeric
  data_clean <- data_clean %>%
    mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

  # 6. Reshape wide to long
  data_long <- data_clean %>%
    pivot_longer(
      cols = starts_with("den") | starts_with("num") | starts_with("per"),
      names_to = c(".value", "period"),
      names_pattern = "(den|num|per)_(\\d+[A-Z]\\d+[A-Z])"
    ) %>%
    rename(denominator = den, numerator = num, performance = per)

  # 7. Add metadata columns
  final_df <- data_long %>%
    mutate(
      state = ifelse(state == "District of Columbia", "D.C.", state),
      denominator = as.numeric(denominator),
      numerator = as.numeric(numerator),
      performance = as.numeric(performance),
      indicator = indicator_name,
      as_of_date = as_of_date,
      source = ver$source,
      period_meaningful = make_period_meaningful(period),
      profile_version = ver$profile_version
    )

  # 8. Rank states
  final_df <- rank_states_by_performance(final_df)

  # 9. Select final columns (no census_year for standard indicators)
  final_df %>%
    select(state, indicator, period, period_meaningful, denominator, numerator,
           performance, state_rank, as_of_date, profile_version, source)
}
```

**Usage** (replaces 80 lines × 5 = 400 lines with 25 lines):
```r
# Extract metadata once (shared across all indicators)
ver <- cfsr_profile_version()
data_df <- find_file(keyword = "National", directory_type = "raw",
                     file_type = "excel", sheet_name = "Entry rates")
asof <- cfsr_profile_extract_asof_date(data_df)

# Process 5 standard indicators with 5 function calls
ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  indicator_name = "Re-entry into foster care after exiting to reunification or guardianship"
)

ind_perm12_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (entries)",
  indicator_name = "Permanency in 12 mos (entries)"
)

ind_perm1223_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (12-23 mos)",
  indicator_name = "Permanency in 12 mos (12-23 mos)"
)

ind_perm24_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (24+ mos)",
  indicator_name = "Permanency in 12 mos (24+ mos)"
)

ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  indicator_name = "Placement stability (moves/1,000 days in care)"
)
```

**Benefits**:
- Reduces ~400 lines to ~25 lines (94% reduction)
- Single source of truth for processing logic
- Easier to maintain and debug
- Consistent handling across indicators
- Prepares for future indicators (Maltreatment in care, Recurrence of maltreatment)

---

### 3. **MEDIUM PRIORITY: Entry Rate Special Case Function**

**Issue**: Entry Rate (lines 60-177) is unique because it has:
- Different column structure (years + periods instead of just periods)
- `census_year` column in output
- More complex reshaping with `child_pop_long` and `period_to_year` mapping

**Current Code**: 118 lines of indicator-specific logic

**Refactoring**: Create function `process_entry_rate_indicator()`

**Proposed Function** (add to `functions_cfsr_profile.R`):
```r
# Process Entry Rate indicator (special case with years)
# ----------------------------
#
# Entry Rate is unique: has both years (for denominator) and periods (for num/per)
#
# @param ver: Profile version list from cfsr_profile_version()
# @param as_of_date: Date from cfsr_profile_extract_asof_date()
#
# @return: Tibble with entry rate structure (includes census_year)

process_entry_rate_indicator <- function(ver = NULL, as_of_date = NULL) {

  # Get from global env if not provided
  if (is.null(ver)) ver <- get("ver", envir = .GlobalEnv)
  if (is.null(as_of_date)) as_of_date <- get("as_of_date", envir = .GlobalEnv)

  # 1. Load sheet
  data_df <- find_file(
    keyword = "National",
    directory_type = "raw",
    file_type = "excel",
    sheet_name = "Entry rates"
  )

  # 2. Select columns and rows
  keep_cols <- c(1:16)
  data_df <- data_df[, keep_cols, drop = FALSE]
  data_df <- extract_relevant_rows(data_df)

  # 3. Extract metadata
  metadata <- data_df[1, ]
  years <- metadata[2:6] %>% as.numeric()
  periods <- metadata[7:11] %>% as.character()
  data_clean <- data_df[-1, ]

  # 4. Rename columns
  den_cols <- paste0("den_", years)
  num_cols <- paste0("num_", periods)
  per_cols <- paste0("per_", periods)
  colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

  # 5. Convert to numeric
  data_clean <- data_clean %>%
    mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

  # 6. Reshape child population (denominator by year)
  child_pop_long <- data_clean %>%
    pivot_longer(
      cols = starts_with("den"),
      names_to = "year",
      names_pattern = "den_(\\d{4})"
    ) %>%
    rename(denominator = value)

  # 7. Reshape entry data (numerator/performance by period)
  data_long <- data_clean %>%
    pivot_longer(
      cols = starts_with("num") | starts_with("per"),
      names_to = c(".value", "period"),
      names_pattern = "(num|per)_(\\d+[A-Z]\\d+[A-Z])"
    ) %>%
    rename(numerator = num, performance = per)

  # 8. Create period-to-year mapping
  period_to_year <- tibble(
    period = periods,
    year = as.character(years)
  )

  # 9. Join all data
  data_long <- data_long %>%
    left_join(period_to_year, by = "period")

  final_df <- data_long %>%
    left_join(child_pop_long, by = c("state", "year"))

  # 10. Add metadata columns
  final_df <- final_df %>%
    mutate(
      state = ifelse(state == "District of Columbia", "D.C.", state),
      census_year = as.numeric(year),
      indicator = "Foster care entry rate per 1,000",
      as_of_date = as_of_date,
      source = ver$source,
      period_meaningful = make_period_meaningful(period),
      profile_version = ver$profile_version
    )

  # 11. Rank states
  final_df <- rank_states_by_performance(final_df)

  # 12. Select final columns (includes census_year)
  final_df %>%
    select(state, indicator, period, period_meaningful, denominator, numerator,
           performance, state_rank, census_year, as_of_date, profile_version, source)
}
```

**Usage** (replaces 118 lines with 1 line):
```r
ind_entrate_df <- process_entry_rate_indicator(ver, as_of_date)
```

**Benefits**:
- Isolates special-case logic
- Reduces main script by ~118 lines
- Documents why Entry Rate is different
- Makes future changes to Entry Rate processing easier

---

## Refactored Main Script Structure

### Before: 604 lines
```r
# Setup (50 lines)
# Entry Rate inline code (118 lines)
# Re-Entry inline code (80 lines)
# Perm 12 (entries) inline code (80 lines)
# Perm 12 (12-23) inline code (80 lines)
# Perm 12 (24+) inline code (80 lines)
# Placement Stability inline code (80 lines)
# Combine and save (4 lines)
```

### After: ~110 lines (82% reduction)
```r
#####################################
# LIBRARIES & UTILITIES ----
#####################################

source("D:/repo_childmetrix/r_utilities/loader.R")
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"))

########################################
# FOLDER PATHS & DIRECTORY STRUCTURE ----
########################################

commitment <- "cfsr profile"
commitment_description <- "national"
my_setup <- setup_folders("2025_02")

########################################
# EXTRACT SHARED METADATA (ONCE) ----
########################################

# Profile version and citation (same for all indicators)
ver <- cfsr_profile_version()

# AFCARS/NCANDS submission date (same for all indicators)
data_df <- find_file(keyword = "National", directory_type = "raw",
                     file_type = "excel", sheet_name = "Entry rates")
asof <- cfsr_profile_extract_asof_date(data_df)

########################################
# PROCESS INDICATORS ----
########################################

# Entry Rate (special case - has years/census_year)
ind_entrate_df <- process_entry_rate_indicator(ver, asof$as_of_date)

# Standard indicators (den/num/per structure)
ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  indicator_name = "Re-entry into foster care after exiting to reunification or guardianship",
  ver = ver,
  as_of_date = asof$as_of_date
)

ind_perm12_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (entries)",
  indicator_name = "Permanency in 12 mos (entries)",
  ver = ver,
  as_of_date = asof$as_of_date
)

ind_perm1223_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (12-23 mos)",
  indicator_name = "Permanency in 12 mos (12-23 mos)",
  ver = ver,
  as_of_date = asof$as_of_date
)

ind_perm24_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (24+ mos)",
  indicator_name = "Permanency in 12 mos (24+ mos)",
  ver = ver,
  as_of_date = asof$as_of_date
)

ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  indicator_name = "Placement stability (moves/1,000 days in care)",
  ver = ver,
  as_of_date = asof$as_of_date
)

########################################
# COMBINE AND SAVE ----
########################################

ind_data <- bind_rows(
  ind_entrate_df, ind_reentry_df, ind_perm12_df,
  ind_perm1223_df, ind_perm24_df, ind_ps_df
)

save_to_folder_run(ind_data, "csv")
```

---

## Refactored `functions_cfsr_profile.R`

Add two new functions to the existing file:

```r
# Existing functions (195 lines)
# - cfsr_profile_version()
# - cfsr_profile_extract_asof_date()
# - extract_relevant_rows()
# - make_period_meaningful()
# - rank_states_by_performance()
# - cfsr_build_reentry_df() [incomplete, line 165]

# NEW FUNCTION 1: process_standard_indicator() (~80 lines)
# NEW FUNCTION 2: process_entry_rate_indicator() (~90 lines)
```

Total additions: ~170 lines to functions file
Total savings in main script: ~494 lines

**Net benefit**: Main script reduced from 604 → 110 lines (82% reduction)

---

## Implementation Priority

### Phase 1: Quick Wins (30 minutes)
1. ✅ **Reorganize metadata extraction** (lines 66-76)
   - Move `ver <- cfsr_profile_version()` to run once before all indicators
   - Move `asof <- cfsr_profile_extract_asof_date(data_df)` to run once
   - Update all 6 indicators to use shared `ver` and `asof$as_of_date`

### Phase 2: Standard Indicators (1 hour)
2. ✅ **Create `process_standard_indicator()`**
   - Add function to `functions_cfsr_profile.R`
   - Test with Re-Entry indicator
   - Replace remaining 4 standard indicators

### Phase 3: Entry Rate (45 minutes)
3. ✅ **Create `process_entry_rate_indicator()`**
   - Add function to `functions_cfsr_profile.R`
   - Test and replace Entry Rate section

### Phase 4: Future Indicators (as needed)
4. 🔮 **Add Maltreatment indicators**
   - Determine if they follow standard or special structure
   - Use `process_standard_indicator()` if possible
   - Create new specialized function if needed

---

## Benefits Summary

### Code Quality
- **Maintainability**: Single source of truth for processing logic
- **Readability**: Main script becomes self-documenting workflow
- **Testability**: Functions can be unit tested independently
- **Debuggability**: Easier to trace issues to specific functions

### Development Efficiency
- **Adding new indicators**: 2 lines instead of 80 lines
- **Fixing bugs**: Fix once in function vs. 6 places in script
- **Onboarding**: New developers understand workflow faster

### Robustness
- **Consistency**: Guaranteed identical processing across indicators
- **Metadata accuracy**: Shared metadata eliminates discrepancies
- **Error handling**: Centralized validation logic

---

## Potential Edge Cases to Consider

### 1. **Column Range Variations**
- Current: All standard indicators use `c(1:10)`
- Future: May need different ranges (e.g., `c(1:12)`)
- **Solution**: Already parameterized as `keep_cols` argument

### 2. **Period Column Variations**
- Current: All standard indicators use columns 2:4 for periods
- Future: May have more/fewer periods
- **Solution**: Already parameterized as `period_cols` argument

### 3. **Missing Data Handling**
- Some states may have NA for performance
- **Solution**: Already handled by `rank_states_by_performance(na.last = "keep")`

### 4. **Incomplete Function** (line 165 in functions_cfsr_profile.R)
- `cfsr_build_reentry_df()` function exists but is incomplete
- This appears to be an earlier refactoring attempt
- **Action**: Can remove this function after implementing new approach

---

## Testing Strategy

### Unit Tests (create `tests/test_cfsr_functions.R`)
```r
# Test metadata extraction
test_that("cfsr_profile_version extracts month and year", {
  # Test with mock filename
})

test_that("cfsr_profile_extract_asof_date parses dates correctly", {
  # Test with mock data frame
})

# Test indicator processing
test_that("process_standard_indicator handles standard structure", {
  # Test with mock data
})

test_that("process_entry_rate_indicator handles year/period structure", {
  # Test with mock data
})

# Test edge cases
test_that("process_standard_indicator handles missing values", {
  # Test with NAs in performance
})
```

### Integration Test
```r
# Run full script on 2025_02 data
# Compare output to original script output (should be identical)
```

---

## Questions for Consideration

1. **Should functions accept global variables or require explicit parameters?**
   - Current proposal: Optional parameters with fallback to globals
   - Alternative: Require all parameters explicitly (more functional, less convenient)

2. **Should `keep_cols` be auto-detected instead of specified?**
   - Pro: Less maintenance if column counts change
   - Con: May select incorrect columns if data structure changes unexpectedly

3. **Should indicator names be stored in a configuration file/list?**
   ```r
   indicator_config <- list(
     reentry = list(
       sheet = "Reentry to FC",
       name = "Re-entry into foster care after exiting to reunification or guardianship"
     ),
     # ...
   )
   ```
   - Pro: Central configuration management
   - Con: Adds complexity for 6-8 indicators

4. **Should the script support batch processing multiple periods?**
   - Current: Processes one period at a time (e.g., "2025_02")
   - Future: Loop over multiple periods?

---

## Conclusion

**Recommended Action**: Implement all three refactorings in order (Phases 1-3)

**Timeline**: ~2-3 hours for complete refactoring + testing

**Risk**: Low - Functions encapsulate existing logic without changing algorithms

**Payoff**: High - 82% reduction in main script length, much easier maintenance

**Future-Proofing**: Adding 2 new indicators will require 4 lines instead of 160 lines
