# CFSR Shiny Dashboard - Bug Backlog

## Recent Improvements

### ✅ Integrate Shiny App into ChildMetrix Reporting Platform

**Status:** ✅ Completed
**Priority:** High
**Date Completed:** 2025-10-10

**Description:**
Successfully integrated the CFSR Statewide Data Indicators Shiny dashboard into the ChildMetrix reporting platform at `r_cm_reports/md/cfsr/performance/`.

**Implementation:**

1. **Copied app files** to production location:
   - From: `r_cfsr_profile/shiny_app/`
   - To: `r_cm_reports/md/cfsr/performance/app/`

2. **Updated data pipeline** to save to both locations:
   - Modified `prepare_app_data.R` to save `.rds` file to:
     - DEV: `r_cfsr_profile/shiny_app/data/cfsr_indicators_latest.rds`
     - PROD: `r_cm_reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds`

3. **Created wrapper HTML files:**
   - `index_static.html` - For production deployment with Shiny Server
   - `index.html` - For local development on localhost
   - Features:
     - Profile period selector (August 2025, February 2025, etc.)
     - State parameter from parent window
     - Loading indicator
     - Responsive design

4. **Updated platform navigation** in `md/index.html`:
   - Primary sidebar: Points to `cfsr/performance/index_static.html`
   - Secondary nav: "Performance" button loads dashboard with profile parameter
   - Period selector: Updates dashboard when changed

5. **Created comprehensive documentation:**
   - `README.md` - Integration guide and file locations
   - `DEPLOYMENT.md` - Deployment checklist and options

**Platform Integration:**
```
ChildMetrix Platform (md/index.html)
├── Sidebar Navigation
│   └── "CFSR Data Profile" → cfsr/performance/index_static.html
│
├── Secondary Navigation (when CFSR selected)
│   ├── Performance → Interactive Shiny dashboard
│   ├── Presentations → CFSR presentations
│   ├── Data Dictionary → Indicator definitions
│   └── Notes → Implementation notes
│
└── Profile Period Selector
    └── Updates dashboard via URL parameter
```

**File Locations:**
- Shiny App: `r_cm_reports/md/cfsr/performance/app/`
- Wrapper: `r_cm_reports/md/cfsr/performance/index_static.html`
- Data: `r_cm_reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds`

**Benefits:**
✅ Single-click access from main platform
✅ Seamless integration with existing navigation
✅ Profile period switching via dropdown
✅ State-aware (reads from URL parameter)
✅ Maintains development and production environments
✅ Auto-updates data via r_cfsr_profile.R pipeline

**Deployment Options:**
- Local: Run via `shiny::runApp()` on port 3838
- Shiny Server: Production deployment for multi-user access
- Docker: Containerized deployment
- RStudio Connect: Enterprise deployment (future)

**Next Steps:**
1. Set up Shiny Server for production hosting
2. Test profile period switching with multiple data versions
3. Consider removing legacy static HTML files (cfsr_md_*.html)

---

### ✅ Chain r_cfsr_profile.R and prepare_app_data.R Together

**Status:** ✅ Completed
**Priority:** High
**Date Completed:** 2025-10-10

**Description:**
The two data processing scripts are now chained together so you only need to run `r_cfsr_profile.R` and it will automatically run `prepare_app_data.R` to generate the .rds file for the Shiny app.

**Implementation:**

1. **Added `profile_period` variable** to r_cfsr_profile.R (line 51):
   ```r
   # Set this once at the top
   profile_period <- "2025_02"  # or "2025_08", etc.
   ```

2. **Auto-run logic** at end of r_cfsr_profile.R (lines 161-176):
   - After saving CSV files, automatically sources prepare_app_data.R
   - Passes `profile_period` variable to child script
   - Displays completion messages

3. **Updated prepare_app_data.R** to accept `profile_period` from parent:
   - If `profile_period` exists (auto-run): uses that specific period
   - If not (manual run): finds most recent YYYY_MM folder
   - **Critical:** Only looks within the specified profile_period folder for date subfolders

**Profile Version Isolation:**

The system now properly isolates profile versions:
- February 2025 profile: All data in `data/2025_02/processed/[date]/`
- August 2025 profile: All data in `data/2025_08/processed/[date]/`
- prepare_app_data.R looks for most recent date subfolder **within** the specified profile period
- No cross-contamination between profile versions

**Workflow:**

1. Set `profile_period <- "2025_02"` in r_cfsr_profile.R
2. Run `source("r_cfsr_profile.R")`
3. Done! Both scripts run automatically

**Files Modified:**
1. `code/r_cfsr_profile.R` - Added profile_period variable and auto-run logic
2. `shiny_app/prepare_app_data.R` - Added profile_period detection and usage

**Documentation:**
Created [README_WORKFLOW.md](../README_WORKFLOW.md) with detailed instructions

**Benefits:**
✅ One-step data processing (no need to run two scripts)
✅ Proper profile version isolation (2025_02 vs 2025_08)
✅ Always uses correct profile period (no mixing versions)
✅ Can still run prepare_app_data.R manually if needed
✅ Clear console messages showing which profile is being processed

---

## Pending Features

### 1. Default Sort Indicator Data Tables by State

**Status:** Pending
**Priority:** Low
**Date Requested:** 2025-10-10

**Description:**
The data tables on indicator pages currently default to sorting by rank (or the order they appear in the data). Change the default sort to alphabetical by state name instead.

**Current Behavior:**
- Tables show states in rank order (or data order)
- User must click "State" column header to sort alphabetically

**Desired Behavior:**
- Tables should default to alphabetical sort by state name
- User can still click other columns to re-sort

**Location:**
Indicator page data tables - likely in `modules/indicator_page.R` where `DT::datatable()` is called

**Implementation Notes:**
- Use DT's `order` option to specify default sort column
- Example: `options = list(order = list(list(0, 'asc')))` for first column ascending
- Need to identify which column index is "State" (likely column 0 or 1)

---

### 2. Change Overview Icon in Sidebar

**Status:** Pending
**Priority:** Low
**Date Requested:** 2025-10-10

**Description:**
The Overview menu item in the sidebar currently uses the `chart-bar` icon (📊). Need to find a different icon that better represents an overview/dashboard/summary page.

**Current Implementation:**
```r
menuItem("Overview", tabName = "overview", icon = icon("chart-bar"))
```

**Location:**
`shiny_app/app.R` line 79

**Considerations:**
- Should convey "overview" or "summary" concept
- Font Awesome icons available via `icon()` function
- Options to consider:
  - `icon("home")` - house icon
  - `icon("dashboard")` - dashboard/tachometer
  - `icon("table")` - table icon (since overview now shows table)
  - `icon("th")` - grid/thumbnails icon
  - `icon("list")` - list icon
  - `icon("clipboard-list")` - clipboard with list
  - `icon("chart-line")` - line chart
  - `icon("eye")` - eye/view icon

---

### 3. Move Data Dictionary Link to Main Iframe

**Status:** Under Consideration
**Priority:** Low
**Date Requested:** 2025-10-10

**Description:**
Consider removing the "Data Dictionary" menu item from the Shiny app sidebar and instead placing it in the main iframe navigation (parent application).

**Current Implementation:**
```r
menuItem("Data Dictionary", tabName = "dictionary", icon = icon("book"))
```

**Location:**
`shiny_app/app.R` line 88

**Rationale:**
- Since the app will be embedded in an iframe, some navigation elements can be moved to the parent application
- Similar to how the state selector and profile version were removed from indicator pages
- Reduces redundancy between iframe and parent navigation
- Keeps the sidebar focused on data visualization pages

**Impact:**
- Would need to remove the Data Dictionary tab from the Shiny app
- Parent application would need to provide access to the data dictionary
- Need to confirm this is desired before implementing

---

## Known Issues

### 1. Plotly Warning: "Ignoring 1 observation"

**Status:** Deferred
**Priority:** Low
**Date Reported:** 2025-10-10

**Description:**
When rendering charts with national standard target lines, the console shows multiple warnings:
- 10-14 warnings: "Can't display both discrete & continuous data on same axis"
- 1 warning: "Ignoring 1 observation"

**Root Cause:**
The `add_segments()` function used to draw the target line mixes discrete y-axis data (state names) with the categorical axis created by `reorder(state, sort_value)`. Plotly can't fully reconcile these two approaches.

**Impact:**
- Visual: None - charts display correctly with target lines appearing as expected
- Functional: None - no data is actually lost or missing
- Console warnings only (not visible to end users)

**Attempted Fixes:**
- Tried using plotly shapes with `yref = "paper"` - caused target lines to disappear and broke axis formatting
- Using numeric positions (0.5 to num_states+0.5) - didn't work with categorical axis

**Workaround:**
Warnings can be safely ignored. They do not affect chart functionality or data accuracy.

**Potential Future Solutions:**
- Investigate plotly's `shapes` feature more thoroughly
- Consider using a different plotting library (ggplotly) if warnings become problematic
- Research if newer versions of plotly have better support for mixing discrete/continuous in add_segments

---

### 2. Tooltip Formatting - Top/Bottom Padding Not Working

**Status:** Deferred
**Priority:** Low
**Date Reported:** 2025-10-10

**Description:**
Tooltips (hover text on chart bars) don't support top or bottom padding using `<br>` tags. While left and right padding can be simulated with spaces, and vertical spacing after the state name works with `<br><br>`, additional padding at the top and bottom of the tooltip box doesn't render.

**Root Cause:**
Plotly for R has limited HTML/CSS support in hover templates (`hovertemplate`). Unlike the JavaScript version, it doesn't support:
- Full HTML table elements for proper alignment
- CSS padding/margin properties
- `<br>` tags at the very beginning or end of the hover text

**Current State:**
- ✅ Left/right padding: Using 2 spaces on each side
- ✅ Spacing after state name: `<br><br>` works
- ❌ Top padding: `<br>` at the start doesn't render
- ❌ Bottom padding: `<br>` at the end doesn't render
- ❌ Column alignment: Can't align values without HTML tables

**Impact:**
- Visual only - tooltip content is readable but could be more polished
- No functional issues

**Potential Future Solutions:**
- Explore plotly JavaScript integration for full HTML support
- Consider custom tooltip implementation using Shiny's UI elements
- Wait for plotly R package updates with better HTML support
- Accept current limitations as acceptable for MVP

---

## Completed Items

### ✅ Replace Overview Visualizations with Rankings Table

**Status:** ✅ Completed
**Priority:** Medium
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
Replaced the 8 small multiple bar charts on the Overview page with an interactive rankings table showing all states (rows) by all indicators (columns).

**Old Implementation:**
- 8 separate small bar charts grouped by category (Safety, Permanency, Well-Being)
- Each chart showed only top 10 states for that indicator
- Required scrolling to see all indicators
- Took up significant vertical space

**New Implementation:**
- Single interactive table using DT (DataTables)
- **Title:** "State Rankings on CFSR Statewide Data Indicators"
- **Subtitle:** "Most recent period available. Lower rank is better."
- Rows: All 52 states (alphabetically sorted, can be re-sorted by clicking columns)
- Columns: State + All 8 indicators (using `indicator_very_short`)
- Cell values: Rank numbers (1 = best)
- Color coding by rank:
  - Rank 1-10: Light green (#d4edda)
  - Rank 11-20: Lighter green (#e7f4e4)
  - Rank 21-30: Light gray (#f8f9fa)
  - Rank 31-40: Light yellow (#fff3cd)
  - Rank 41-50: Light red (#f8d7da)
  - Rank 51+: Pink (#f5c6cb)
- Selected state row highlighted in light blue (#E8F4FD)
- Sortable columns (click header to sort)
- Scrollable (600px height)

**Files Modified:**
1. `functions/chart_builder.R` - Added `build_overview_rankings_table()` function (lines 272-313)
2. `app.R` - Updated Overview tab UI with new title/subtitle (lines 115-140)
3. `app.R` - Replaced server logic to use DT::renderDataTable (lines 250-290)

**Benefits:**
✅ Shows all data at once in familiar table format
✅ Easy to read rank numbers
✅ Color-coded for quick visual assessment
✅ Sortable by any column
✅ Selected state clearly highlighted
✅ Compact and professional appearance
✅ Clearly communicates "lower rank is better"

---

### ✅ Add State Performance Summary Table

**Status:** ✅ Completed
**Priority:** Medium
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
Added a focused table on the Overview page showing the selected state's performance across all indicators with proper formatting and context.

**Implementation:**
- **Title:** "[State]'s Performance on CFSR Statewide Data Indicators" (dynamic based on selected state)
- **Subtitle:** "Most recent period available. Lower rank is better."
- **Columns:**
  1. Indicator (full names, not indicator_very_short)
  2. Rank (1 = best, or "DQ" if not calculated)
  3. Reporting States (number of states with non-null performance)
  4. Performance (percent indicators: X.X %, rate indicators: X.XX)
  5. National Standard (formatted appropriately, or "No national standard")
- **Formatting:**
  - Percent indicators: Multiply by 100, show 1 decimal, add "%" suffix
  - Rate indicators: Show 2 decimals, no suffix
  - National standards: Already in display units, only format decimals
  - DQ values: Show "DQ" for null ranks/performance
- **Footnote:** "DQ = Not calculated due to data quality issues. Reporting States = The number of states whose performance could be calculated."
- **Styling:** Compact (12px font, tight padding), center-aligned numeric columns

**Files Modified:**
1. `functions/chart_builder.R` - Added `build_state_performance_table()` function (lines 318-403)
2. `app.R` - Added state performance section to Overview tab UI (lines 115-131)
3. `app.R` - Added server logic for dynamic title and table rendering (lines 253-277)

**Result:**
✅ Users can quickly see their state's performance on all indicators
✅ Proper formatting for percents vs rates
✅ Clear indication of data quality issues (DQ)
✅ Context provided via reporting states count
✅ Compact, professional appearance

---

### ✅ Add Reporting States Column to CSV and Calculations

**Status:** ✅ Completed
**Priority:** Medium
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
Added a `reporting_states` column to the CSV files showing how many states had non-null performance for each indicator and period. This provides important context for understanding rankings (e.g., rank 30 of 30 means worst performer, not middle of the pack).

**Implementation:**
- Modified `rank_states_by_performance()` to calculate reporting_states alongside state_rank
- Calculation: `reporting_states = sum(!is.na(state_rank))` within each period group
- Added reporting_states to CSV output for both standard indicators and entry rate
- Updated Shiny app to use reporting_states from CSV in:
  - State performance summary table
  - Bar chart tooltips ("Rank: X of [reporting_states]" instead of "Rank: X of 52")

**Location:**
1. `r_utilities/project_specific/functions_cfsr_profile.R` - `rank_states_by_performance()` function (lines 239-298)
2. `r_utilities/project_specific/functions_cfsr_profile.R` - CSV output (lines 435, 536)
3. `shiny_app/functions/chart_builder.R` - Tooltip building (lines 63-67)
4. `shiny_app/functions/chart_builder.R` - State performance table (lines 318-403)

**Result:**
✅ CSV files include reporting_states column for standalone analysis
✅ Tooltips show accurate denominator for rankings
✅ Users can interpret rankings with proper context

---

### ✅ Calculate Ranks for All Periods (Not Just Most Recent)

**Status:** ✅ Completed
**Priority:** Medium
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
Updated the ranking function to calculate state_rank and reporting_states for ALL periods in the data, not just the most recent period. This enables historical analysis and trend tracking.

**Old Behavior:**
```r
rank_states_by_performance <- function(df) {
  most_recent_period <- max(df$period)
  df %>%
    group_by(period) %>%
    mutate(
      state_rank = if_else(
        period == most_recent_period,
        rank(performance, ties.method = "min", na.last = "keep"),
        NA_integer_
      )
    ) %>%
    ungroup()
}
```
- Only calculated ranks for `period == most_recent_period`
- Historical periods had `state_rank = NA`

**New Behavior:**
```r
rank_states_by_performance <- function(df) {
  # Load dictionary for direction_desired
  df %>%
    group_by(period) %>%
    mutate(
      state_rank = if (direction == "up") {
        rank(-performance, ties.method = "min", na.last = "keep")
      } else {
        rank(performance, ties.method = "min", na.last = "keep")
      },
      reporting_states = sum(!is.na(state_rank))
    ) %>%
    ungroup()
}
```
- Calculates ranks for ALL periods using `group_by(period)`
- Direction-aware ranking applied to each period
- Reporting_states calculated for each period

**Location:**
`r_utilities/project_specific/functions_cfsr_profile.R` - `rank_states_by_performance()` function (lines 239-298)

**Result:**
✅ All periods have state_rank values (not just most recent)
✅ Historical ranking analysis now possible
✅ Reporting_states available for all periods

---

### ✅ Remove State and Profile Badges from Indicator Pages

**Status:** ✅ Completed
**Priority:** Low
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
Removed the "Maryland" pill and "Profile: February 2025" badges from the top of indicator pages in preparation for iframe integration, since this information will be available in the parent application's top-level menu.

**Removed Elements:**
- State badge showing selected state name (e.g., "Maryland")
- Profile badge showing profile version (e.g., "Profile: February 2025")

**Location:**
`modules/indicator_page.R`

**Changes:**
1. **UI (lines 11-19):** Removed the div containing both badges
2. **Server (lines 82-94):** Removed output rendering functions for both badges

**Result:**
✅ Cleaner indicator page layout
✅ Reduced redundancy when embedded in iframe
✅ Parent application handles state/profile display

---

### ✅ Fix Character Encoding in Source Field (Data Preparation)

**Status:** ✅ Completed
**Priority:** Medium
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
When creating the CFSR profile national CSV files, the source field displayed "Childrenâ€™s Bureau" instead of "Children's Bureau" due to character encoding issues.

**Root Cause:**
The source citation in `functions_cfsr_profile.R` line 120 used a fancy/curly apostrophe (Unicode U+2019: `'`) instead of a regular ASCII apostrophe (`'`). The UTF-8 bytes `e2 80 99` were being misinterpreted as "â€™" when displayed.

**Solution:**
Replaced the fancy apostrophe with a regular ASCII apostrophe (`'`, byte `27`) in the `cfsr_profile_version()` function.

**Location:**
`r_utilities/project_specific/functions_cfsr_profile.R` line 120

**Fix Applied:**
```r
# Changed from:
"Children's Bureau. (...)"  # fancy apostrophe (U+2019)

# Changed to:
"Children's Bureau. (...)"  # regular apostrophe (ASCII)
```

**Result:**
✅ CSV files now correctly display "Children's Bureau" in the source field

---

### ✅ Improve Downloaded CSV Filename (Shiny App)

**Status:** ✅ Completed
**Priority:** Low
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
The CSV download filename format was improved for better clarity and usability.

**Old Format:**
`Maltreatment_in_care_2025-10-10.csv` (uses full indicator name with underscores + date)

**New Format:**
`cfsr_profile_maltreatment_2025-10-10.csv` (uses indicator_very_short, all lowercase, with cfsr_profile prefix)

**Solution:**
Updated the `downloadHandler` filename function in `modules/indicator_page.R` line 396 to use `indicator_very_short` with lowercase conversion and add "cfsr_profile_" prefix.

**Location:**
`modules/indicator_page.R` line 396

**Fix Applied:**
```r
# Changed from:
paste0(gsub("[^a-zA-Z0-9]", "_", ind_data()$indicator[1]), "_", Sys.Date(), ".csv")

# Changed to:
clean_name <- tolower(gsub("_+", "_", gsub("[^a-zA-Z0-9]", "_", ind_data()$indicator_very_short[1])))
clean_name <- sub("_$", "", clean_name)  # Remove trailing underscore
paste0("cfsr_profile_", clean_name, "_", Sys.Date(), ".csv")
```

**Examples:**
- Entry Rate → `cfsr_profile_entry_rate_2025-10-10.csv`
- Maltreatment → `cfsr_profile_maltreatment_2025-10-10.csv`
- Perm in 12 (entries) → `cfsr_profile_perm_in_12_entries_2025-10-10.csv`

**Result:**
✅ Downloaded CSV files now have clearer, more concise filenames with:
- cfsr_profile prefix
- Short indicator names (indicator_very_short)
- All lowercase for consistency
- No double underscores (collapses consecutive underscores and removes trailing ones)

---

### ✅ Revise Rank Function to Respect Direction (Data Preparation)

**Status:** ✅ Completed
**Priority:** Medium
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
The ranking function didn't respect the desired direction for each indicator. Rank 1 should always represent the best-performing state, regardless of whether higher or lower values are better for that indicator.

**Old Behavior:**
- Ranks were assigned using `rank(performance)`, which always gives rank 1 to the lowest value
- This was incorrect for "up" indicators (like Perm in 12) where higher values are better

**New Behavior:**
- For "up" indicators: Rank 1 = highest performance value (best) → uses `rank(-performance)`
- For "down" indicators: Rank 1 = lowest performance value (best) → uses `rank(performance)`
- Rank 1 always represents the best-performing state

**Location:**
`r_utilities/project_specific/functions_cfsr_profile.R` - `rank_states_by_performance()` function (lines 242-303)

**Fix Applied:**
The function now:
1. Loads the indicators dictionary to look up `direction_desired` for each indicator
2. Applies appropriate ranking based on direction:
   - "up" (higher is better): `rank(-performance)`
   - "down" (lower is better): `rank(performance)`
3. Tries multiple paths to find the dictionary file for robustness
4. Falls back to "down" as a safe default if dictionary not found

**Examples:**
- **Perm in 12 (entries)** - direction: "up"
  - State with 45% performance → Rank 1 (best)
  - State with 30% performance → Rank 25 (worse)

- **Entry Rate** - direction: "down"
  - State with 2.0 entries/1000 → Rank 1 (best)
  - State with 7.5 entries/1000 → Rank 50 (worse)

**Result:**
✅ Rankings now correctly reflect each indicator's desired direction
✅ Rank 1 always means "best performing state"

---

### ✅ Fix Shiny App Using Incorrect Rankings

**Status:** ✅ Completed
**Priority:** High
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
After fixing the rank calculation in `r_cfsr_profile.R`, the CSV files had correct rankings, but the Shiny app was still displaying incorrect rankings.

**Root Cause:**
The `get_indicator_data()` function in `shiny_app/functions/data_prep.R` was recalculating ranks instead of using the pre-calculated `state_rank` from the CSV. It sorted by performance and assigned `rank = row_number()`, which ignored the correct direction-aware rankings from the data preparation step.

**Location:**
`shiny_app/functions/data_prep.R` - `get_indicator_data()` function (lines 67-87)

**Fix Applied:**
```r
# Changed from:
# Sort by performance based on direction
# then mutate(rank = row_number())

# Changed to:
# Sort by state_rank (descending so rank 1 is at bottom for plotly)
ind_df <- ind_df %>%
  arrange(desc(state_rank))
# Use state_rank directly
ind_df <- ind_df %>%
  mutate(rank = state_rank)
```

**Result:**
✅ Shiny app now displays the correct direction-aware rankings from the CSV
✅ No need to regenerate data - just restart the Shiny app

---

### ✅ Fix Indicator Name Mismatch for "Perm in 12 (12-23 mos)"

**Status:** ✅ Completed
**Priority:** High
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
The indicator "Permanency in 12 months for children in care 12-23 months" was not being matched correctly, causing:
- Warning in `r_cfsr_profile.R`: "No indicator name found for sheet 'Perm in 12 (12-23 mos)'"
- Warning in `r_cfsr_profile.R`: "Direction not found for indicator"
- Warning in `prepare_app_data.R`: "The following indicators did not match the dictionary"
- Error in `app.R`: "subscript out of bounds" preventing app from starting

**Root Cause:**
The `load_indicator_dictionary()` function had a typo on line 40:
- Looking for: `"Perm in 12 months (12-23  months)"` (double space)
- Dictionary has: `"Perm in 12 months (12-23 months)"` (single space)

**Location:**
`r_utilities/project_specific/functions_cfsr_profile.R` - `load_indicator_dictionary()` function (line 40)

**Fix Applied:**
```r
# Changed from:
"Perm in 12 (12-23 mos)" = dict$indicator[dict$indicator_short == "Perm in 12 months (12-23  months)"]

# Changed to:
"Perm in 12 (12-23 mos)" = dict$indicator[dict$indicator_short == "Perm in 12 months (12-23 months)"]
```

**Result:**
✅ All 8 indicators now match correctly between CSV and dictionary
✅ No warnings during data preparation
✅ Shiny app starts without errors

---

### ✅ Reduce Sidebar Menu Spacing

**Status:** ✅ Completed
**Priority:** Low
**Date Reported:** 2025-10-10
**Date Completed:** 2025-10-10

**Description:**
Reduced vertical spacing between navigation links in the sidebar for a more compact layout.

**Location:**
`shiny_app/app.R` - CSS section (lines 109-110)

**Fix Applied:**
Added CSS rules:
```css
.sidebar-menu li { margin-bottom: 2px; }
.sidebar-menu li a { padding-top: 8px; padding-bottom: 8px; }
```

**Result:**
✅ Sidebar menu items are more compact with reduced spacing

---

