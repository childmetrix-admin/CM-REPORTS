# CFSR Profile Extraction Code Analysis

## Overview

This document analyzes the similarities and differences between `profile_rsp.R` (page 2 extraction) and `profile_observed.R` (page 4 extraction), and recommends code organization strategies.

## Comparison: Page 2 (RSP) vs Page 4 (Observed)

### Similarities

1. **PDF Structure**
   - Same PDF source file
   - Same indicator names in column 1
   - Same National Performance values in column 2
   - Similar table grid structure with x/y coordinates

2. **Indicator Coverage**
   - Both extract 7 indicators (5 in top table, 2 in bottom table)
   - Same indicator names and order
   - Same two-table structure (top: 5 permanency indicators, bottom: 2 safety indicators)

3. **Period Coverage**
   - Same time periods covered (just different column positions)
   - Same period labeling formats (e.g., "20A20B", "FY20-21")

4. **Workflow Structure**
   - Both use coordinate-based extraction with `pdftools::pdf_data()`
   - Both use `extract_tableau_table()` for table parsing
   - Both reshape from wide to long format
   - Both add metadata and save CSV + RDS

### Key Differences

| Aspect | Page 2 (RSP) | Page 4 (Observed) |
|--------|--------------|-------------------|
| **Row Structure** | RSP / RSP interval / Data used | Denominator / Numerator / Observed performance |
| **Column Start** | Column 4 starts first period (~300px) | Column 3 starts first period (~255px) |
| **Vertical Spacing** | Standard spacing | Tighter spacing (may need y adjustment) |
| **Data Complexity** | Intervals with special characters (†, ‡) | Simple numeric values |
| **Parsing Needs** | Complex interval parsing, percentage conversion | Straightforward numeric extraction |
| **Output Columns** | rsp, rsp_lower, rsp_upper, data_used | denominator, numerator, observed_performance |

## Code Reusability Assessment

### Functions That Should Be SHARED

These functions are identical or nearly identical between scripts and should be moved to `functions_cfsr_profile_shared.R`:

1. **`extract_tableau_table()`** ✅
   - Core table extraction function
   - Used by both RSP and Observed
   - Currently duplicated in profile_rsp.R (lines 101-113)

2. **`extract_headers()`** ✅
   - Header extraction from coordinate ranges
   - Used by both RSP and Observed
   - Currently in profile_rsp.R (lines 342-362)

3. **`generate_bottom_cols()`** ✅
   - Generates column names for bottom table based on top table periods
   - Used by both RSP and Observed
   - Currently in profile_rsp.R (lines 399-406)

4. **Basic text cleaning** (partial)
   - `str_replace_all(text, "[^[:graph:]]", "")` - used by both
   - Simple trimming and whitespace cleanup

### Functions That Are SCRIPT-SPECIFIC

#### RSP-Specific (`profile_rsp.R`)

1. **`process_table()`** - Filters for RSP/RSP interval/Data used rows
2. **`fix_shadow_text()`** - Cleans OCR artifacts specific to page 2
3. **`repair_maltreatment_row()`** - Fixes maltreatment decimal splits
4. **`fix_rsp_interval_bleed()`** - Fixes RSP interval column overflow
5. **`fix_recurrence_shift()`** - Fixes recurrence column misalignment
6. **`convert_percentages()`** - Converts RSP percentages to decimals
7. **`expand_rsp_intervals()`** - Splits interval ranges into lower/upper bounds
8. **`reshape_rsp_wide_to_long()`** - Reshapes with RSP columns
9. **`fix_maltreatment_data_used()`** - Repairs maltreatment "Data used" values

#### Observed-Specific (`profile_observed.R`)

1. **`process_table_observed()`** - Filters for Denominator/Numerator/Observed performance rows
2. **`reshape_observed_wide_to_long()`** - Reshapes with observed performance columns
3. **Simpler numeric extraction** - No interval parsing needed

### Functions Already in `functions_cfsr_profile_rsp.R` That Are SHARED

These are currently in the RSP functions file but are actually shared:

1. **`setup_cfsr_folders()`** - Multi-state folder setup
2. **`find_cfsr_file()`** - File finding in uploads folder
3. **`extract_pdf_metadata()`** - PDF filename parsing
4. **`load_indicator_dictionary()`** - Load indicator metadata
5. **`get_indicator_name()`** - Dictionary lookup
6. **`cfsr_profile_version()`** - Extract profile month/year
7. **`cfsr_profile_extract_asof_date()`** - Extract AFCARS/NCANDS date

### Period Conversion Functions

These are similar but with slight differences:

- **`make_period_meaningful_rsp()`** - More complex (handles AB_FY and FY ranges)
- **`make_period_meaningful_observed()`** - Simpler (standard AB and FY formats)

Could be consolidated into a single function with better logic, or kept separate for clarity.

## Recommended Code Organization

### Option A: Create Shared Functions File (RECOMMENDED)

**Structure:**
```
code/
├── functions/
│   ├── functions_cfsr_profile_shared.R  (NEW - shared extraction functions)
│   ├── functions_cfsr_profile_rsp.R     (RSP-specific functions only)
│   └── functions_cfsr_profile_observed.R (NEW - Observed-specific functions)
├── profile_rsp.R
├── profile_observed.R
└── profile_national.R
```

**`functions_cfsr_profile_shared.R` would contain:**
- PDF/file handling: `setup_cfsr_folders()`, `find_cfsr_file()`, `extract_pdf_metadata()`
- Dictionary: `load_indicator_dictionary()`, `get_indicator_name()`
- Version/date: `cfsr_profile_version()`, `cfsr_profile_extract_asof_date()`
- Table extraction: `extract_tableau_table()`, `extract_headers()`, `generate_bottom_cols()`
- State ranking: `rank_states_by_performance()`

**`functions_cfsr_profile_rsp.R` would contain:**
- `process_table()` (RSP version)
- `fix_shadow_text()`, `repair_maltreatment_row()`, `fix_rsp_interval_bleed()`
- `fix_recurrence_shift()`, `convert_percentages()`, `expand_rsp_intervals()`
- `reshape_rsp_wide_to_long()`
- `make_period_meaningful_rsp()`

**`functions_cfsr_profile_observed.R` (NEW) would contain:**
- `process_table_observed()` (Observed version)
- `reshape_observed_wide_to_long()`
- `make_period_meaningful_observed()`

**Benefits:**
- Clear separation of concerns
- Easier to maintain and test
- Reduces code duplication
- Each script sources only what it needs

### Option B: Keep Current Structure

**Structure:**
```
code/
├── functions/
│   ├── functions_cfsr_profile_rsp.R     (keep as-is, includes shared functions)
│   └── functions_cfsr_profile_nat.R
├── profile_rsp.R                        (includes extraction helpers inline)
└── profile_observed.R                   (includes extraction helpers inline)
```

**Benefits:**
- Simpler - no refactoring needed
- Each script is more self-contained

**Drawbacks:**
- Code duplication (extract_tableau_table, extract_headers, etc.)
- Harder to maintain consistency
- Larger file sizes

## Coordinate Adjustments for Page 4

### X Coordinates

Page 4 periods start in column 3 (vs column 4 on page 2). Based on user's note:

> "Page 4 column 3 starts first period data (page 2 column 4 starts first period data) - but they are at the same X coordinate"

**Implication:** The x_cuts may actually be the SAME between page 2 and page 4, since the x coordinates align even though the logical column numbers differ.

**Recommendation:** Test extraction with page 2 x_cuts first, then adjust if needed.

### Y Coordinates

Page 4 has tighter vertical spacing. User noted:

> "Page 4 has tighter vertical spacing between rows (less space between Indicator name and first row of data)"

**Current values (page 2):**
- Top table: `y_min = 190, y_max = 480`
- Zone A (Maltreatment in care): `y_min = 490, y_max = 565`
- Zone B (Recurrence): `y_min = 570, y_max = 615`

**Recommendation:** Start with page 2 values and adjust based on actual extracted data. May need to:
- Reduce y_tolerance from 5 to 3-4
- Shift y_min/y_max boundaries slightly

## Testing Plan

### Phase 1: Test Extraction

1. Run `profile_observed.R` with a sample Maryland PDF
2. Inspect `df_top_raw` and `df_zone_a/b` for correct cell alignment
3. Adjust x_cuts and y coordinates as needed
4. Verify all 7 indicators extract correctly

### Phase 2: Validate Data

1. Compare extracted values to PDF manually for 2-3 indicators
2. Check that period labels match header row
3. Verify denominator, numerator, observed performance values are correct
4. Test with multiple states (MD, KY) to ensure consistency

### Phase 3: Refactor (if Option A chosen)

1. Create `functions_cfsr_profile_shared.R`
2. Move shared functions from `functions_cfsr_profile_rsp.R` and `profile_rsp.R`
3. Create `functions_cfsr_profile_observed.R` with observed-specific functions
4. Update `profile_rsp.R` to source shared functions file
5. Update `profile_observed.R` to source shared + observed functions files
6. Re-test both scripts to ensure no regressions

## Next Steps

1. **User approval on code organization** (Option A or B)
2. **Test profile_observed.R** with real PDF
3. **Refactor if Option A chosen**
4. **Document any coordinate adjustments needed**
5. **Integrate into run_profile.R orchestrator**
