# New Indicators Added - Maltreatment & Recurrence

**Date Added**: 2025-10-09
**Status**: ✅ Complete

---

## Overview

Added two new CFSR indicators to the processing pipeline:
1. **Maltreatment in Care**
2. **Recurrence of Maltreatment**

Both indicators use the standard den/num/per structure but require custom period formatting.

---

## What Was Changed

### 1. **Updated `make_period_meaningful()` Function**

Location: [`functions_cfsr_profile.R:108-146`](D:/repo_childmetrix/r_utilities/project_specific/functions_cfsr_profile.R#L108)

Added two new period format cases:

#### Case 3: Maltreatment in Care Format
- **Input**: `"20AB,FY20"` (AFCARS AB + NCANDS FY)
- **Output**: `"Oct '19 - Sep '20, FY 2020"`
- **Logic**:
  - `AB` = Two 6-month AFCARS submissions (Oct-Sep fiscal year)
  - `FY` = NCANDS fiscal year submission
  - Start month: October of (year - 1)
  - End month: September of year

```r
} else if (grepl("^[0-9]{2}AB,FY[0-9]{2}$", period)) {
  # Case 3: Format "YYAB,FYYY" (e.g., "20AB,FY20") => Oct 'prev_year - Sep 'year, FY year
  # AFCARS AB (two 6-month submissions) + NCANDS FY
  year <- as.numeric(substr(period, 1, 2))
  fy_year <- as.numeric(substr(period, 7, 8))
  start_year <- (year - 1) + 2000
  end_year <- year + 2000
  fy_full <- fy_year + 2000
  return(paste0("Oct '", substr(as.character(start_year), 3, 4),
                " - Sep '", substr(as.character(end_year), 3, 4),
                ", FY ", fy_full))
```

**Examples**:
| Input | Output |
|-------|--------|
| `20AB,FY20` | `Oct '19 - Sep '20, FY 2020` |
| `21AB,FY21` | `Oct '20 - Sep '21, FY 2021` |
| `22AB,FY22` | `Oct '21 - Sep '22, FY 2022` |

#### Case 4: Recurrence of Maltreatment Format
- **Input**: `"FY20-21"` (Two NCANDS FY submissions)
- **Output**: `"FY 2020 - 2021"`
- **Logic**: Directly converts two-digit years to four-digit years

```r
} else if (grepl("^FY[0-9]{2}-[0-9]{2}$", period)) {
  # Case 4: Format "FYYY-YY" (e.g., "FY20-21") => FY year1 - year2
  # Two NCANDS FY submissions
  year1 <- as.numeric(substr(period, 3, 4))
  year2 <- as.numeric(substr(period, 6, 7))
  fy1_full <- year1 + 2000
  fy2_full <- year2 + 2000
  return(paste0("FY ", fy1_full, " - ", fy2_full))
```

**Examples**:
| Input | Output |
|-------|--------|
| `FY20-21` | `FY 2020 - 2021` |
| `FY21-22` | `FY 2021 - 2022` |
| `FY22-23` | `FY 2022 - 2023` |

---

### 2. **Added Indicators to Main Script**

Location: [`r_cfsr_profile.R:132-152`](D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R#L132)

#### Maltreatment in Care
```r
ind_maltreatment_df <- process_standard_indicator(
  sheet_name = "Maltreatment in care",
  indicator_name = "Maltreatment in foster care",
  ver = ver,
  as_of_date = asof$as_of_date
)
```

#### Recurrence of Maltreatment
```r
ind_recurrence_df <- process_standard_indicator(
  sheet_name = "Recurrence of maltreatment",
  indicator_name = "Recurrence of maltreatment",
  ver = ver,
  as_of_date = asof$as_of_date
)
```

#### Updated Combine Step
```r
ind_data <- bind_rows(ind_entrate_df, ind_reentry_df, ind_perm12_df,
                      ind_perm1223_df, ind_perm24_df, ind_ps_df,
                      ind_maltreatment_df, ind_recurrence_df)  # ← Added here
```

---

## Total Indicators Now Processed

| # | Indicator | Sheet Name | Period Format | Function Used |
|---|-----------|------------|---------------|---------------|
| 1 | Foster care entry rate per 1,000 | Entry rates | `19A19B` + years | `process_entry_rate_indicator()` |
| 2 | Re-entry into foster care | Reentry to FC | `19A19B` or `19B20A` | `process_standard_indicator()` |
| 3 | Permanency in 12 mos (entries) | Perm in 12 (entries) | `19A19B` or `19B20A` | `process_standard_indicator()` |
| 4 | Permanency in 12 mos (12-23 mos) | Perm in 12 (12-23 mos) | `19A19B` or `19B20A` | `process_standard_indicator()` |
| 5 | Permanency in 12 mos (24+ mos) | Perm in 12 (24+ mos) | `19A19B` or `19B20A` | `process_standard_indicator()` |
| 6 | Placement stability | Placement stability | `19A19B` or `19B20A` | `process_standard_indicator()` |
| 7 | **Maltreatment in foster care** | **Maltreatment in care** | **`20AB,FY20`** | `process_standard_indicator()` |
| 8 | **Recurrence of maltreatment** | **Recurrence of maltreatment** | **`FY20-21`** | `process_standard_indicator()` |

---

## Period Format Summary

The `make_period_meaningful()` function now handles **4 period formats**:

### Format 1: `YYAYYB` (Oct-Sep Fiscal Year)
- **Example**: `19A19B`
- **Output**: `Oct '18 - Sep '19`
- **Used by**: Re-entry, Perm in 12 (all 3), Placement Stability

### Format 2: `YYBZZA` (Apr-Mar Fiscal Year)
- **Example**: `19B20A`
- **Output**: `Apr '19 - Mar '20`
- **Used by**: Re-entry, Perm in 12 (all 3), Placement Stability

### Format 3: `YYAB,FYYY` (AFCARS + NCANDS)
- **Example**: `20AB,FY20`
- **Output**: `Oct '19 - Sep '20, FY 2020`
- **Used by**: Maltreatment in Care ⭐ NEW

### Format 4: `FYYY-YY` (NCANDS Range)
- **Example**: `FY20-21`
- **Output**: `FY 2020 - 2021`
- **Used by**: Recurrence of Maltreatment ⭐ NEW

---

## Data Structure

Both new indicators follow the standard structure:

### Excel Sheet Layout
```
Column 1: State name
Columns 2-4: Period labels (e.g., "20AB,FY20", "FY20-21")
Columns 5-7: Denominators (by period)
Columns 8-10: Numerators (by period)
```

### Output Columns
Both indicators produce tibbles with these columns:
- `state`
- `indicator`
- `period` (raw, e.g., "20AB,FY20")
- `period_meaningful` (formatted, e.g., "Oct '19 - Sep '20, FY 2020")
- `denominator`
- `numerator`
- `performance`
- `state_rank` (only for most recent period)
- `as_of_date`
- `profile_version`
- `source`

---

## Implementation Complexity

### Before Refactoring
Adding these 2 indicators would have required:
- 160 lines of code (80 lines × 2 indicators)
- Copying/pasting and modifying repeated processing logic
- High risk of copy-paste errors

### After Refactoring
Adding these 2 indicators required:
- **12 lines of code** (6 lines × 2 indicators)
- **2 new cases in `make_period_meaningful()`** (~30 lines)
- **Total: ~42 lines**

**Savings**: 160 - 42 = **118 lines saved** (74% reduction)

---

## Testing Checklist

Before running on production data, verify:

### 1. Period Formatting
- [ ] `20AB,FY20` → `Oct '19 - Sep '20, FY 2020` ✓
- [ ] `21AB,FY21` → `Oct '20 - Sep '21, FY 2021` ✓
- [ ] `FY20-21` → `FY 2020 - 2021` ✓
- [ ] `FY21-22` → `FY 2021 - 2022` ✓

### 2. Data Loading
- [ ] "Maltreatment in care" sheet exists in Excel file
- [ ] "Recurrence of maltreatment" sheet exists in Excel file
- [ ] Both sheets have correct column structure (1:10)
- [ ] Both sheets have period labels in columns 2-4

### 3. Output Verification
- [ ] `ind_maltreatment_df` contains expected rows/columns
- [ ] `ind_recurrence_df` contains expected rows/columns
- [ ] State rankings calculated correctly for most recent period
- [ ] All metadata (as_of_date, source, profile_version) populated
- [ ] D.C. name transformation applied

### 4. Integration
- [ ] Combined `ind_data` includes all 8 indicators
- [ ] Output CSV file created successfully
- [ ] File naming convention followed

---

## Period Format Detection Logic

The function uses regex patterns to detect formats:

```r
# Format 1: YYAYYB
grepl("^[0-9]{2}A[0-9]{2}B$", period)

# Format 2: YYBZZA
grepl("^[0-9]{2}B[0-9]{2}A$", period)

# Format 3: YYAB,FYYY
grepl("^[0-9]{2}AB,FY[0-9]{2}$", period)

# Format 4: FYYY-YY
grepl("^FY[0-9]{2}-[0-9]{2}$", period)
```

If none match, returns `NA_character_`.

---

## Future Considerations

### If More Period Formats Are Needed

Add additional `else if` clauses to `make_period_meaningful()`:

```r
} else if (grepl("^YOUR_PATTERN$", period)) {
  # Your parsing logic
  return(formatted_string)
```

### If Indicators Have Different Column Structure

Override parameters in `process_standard_indicator()`:

```r
ind_custom_df <- process_standard_indicator(
  sheet_name = "Custom Indicator",
  indicator_name = "Custom Indicator Name",
  keep_cols = c(1:12),      # If more columns needed
  period_cols = 2:5,         # If more period columns
  ver = ver,
  as_of_date = asof$as_of_date
)
```

---

## Code Quality Benefits

### Reusability
✅ Existing `process_standard_indicator()` function worked perfectly
✅ No new function needed
✅ Only period formatting required updating

### Maintainability
✅ Period formatting centralized in one function
✅ Easy to add more period formats in future
✅ Clear documentation of each format's meaning

### Consistency
✅ Same processing logic as other standard indicators
✅ Same output structure
✅ Same error handling

---

## Summary

| Metric | Value |
|--------|-------|
| **Indicators added** | 2 |
| **Lines of code added** | 42 |
| **Lines saved vs. old approach** | 118 (74%) |
| **New period formats supported** | 2 |
| **Total indicators now** | 8 |
| **Total period formats supported** | 4 |
| **Function modifications** | 1 (`make_period_meaningful()`) |
| **New functions created** | 0 |

---

## Documentation Location

This file: [`NEW_INDICATORS_ADDED.md`](NEW_INDICATORS_ADDED.md)

Related files:
- [`README.md`](README.md) - Project overview
- [`REFACTORING_SUMMARY.md`](REFACTORING_SUMMARY.md) - Original refactoring
- [`FUNCTION_USAGE_GUIDE.md`](FUNCTION_USAGE_GUIDE.md) - How to use functions

---

## Next Steps

1. ✅ Functions updated
2. ✅ Indicators added to main script
3. ⏳ Test with actual data
4. ⏳ Verify period formatting is correct
5. ⏳ Confirm output file includes all 8 indicators

**Ready for testing with February 2025 data file.**
