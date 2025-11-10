# CFSR Statewide Data Indicators - Interactive Dashboard

Interactive Shiny dashboard for exploring state-by-state performance on CFSR indicators.

**Note:** This guide assumes you've already run the data processing pipeline. If not, see [../README.md](../README.md) for instructions on processing raw data from ShareFile.

---

## Overview

This dashboard provides:
- **Overview page** - Small multiples of all 8 indicators for quick comparison
- **8 detailed indicator pages** - Full 52-state rankings with selected state highlighting
- **Data dictionary** - Searchable table of indicator definitions
- **State-specific views** - Filter by state via URL parameter

---

## Quick Start

### Prerequisites

Data must be processed first:

```r
# From cfsr-profile root directory:
state_code <- "md"          # Lowercase
profile_period <- "2024_08"
source("D:/repo_childmetrix/cfsr-profile/code/cfsr_profile.R")

# This automatically runs prepare_app_data.R which creates:
# - data/app_data/md/cfsr_indicators_2024_08.rds
# - data/app_data/md/cfsr_indicators_latest.rds
# - cm-reports/states/md/cfsr/performance/app/data/md_cfsr_indicators_latest.rds (PROD)
```

### Running the Dashboard

**Option 1: RStudio**
1. Open `app.R`
2. Click "Run App" button

**Option 2: R Console**
```r
library(shiny)
runApp("D:/repo_childmetrix/cfsr-profile/shiny_app")
```

**Option 3: Specific Port**
```r
shiny::runApp("D:/repo_childmetrix/cfsr-profile/shiny_app", port = 3838)
```

### Testing

Access the app at: `http://localhost:[PORT]/`

**Test different states via URL parameter:**
- Maryland (default): `http://localhost:3838/`
- Kentucky: `http://localhost:3838/?state=ky`
- Michigan: `http://localhost:3838/?state=mi`

---

## File Structure

```
shiny_app/
├── app.R                       # Main Shiny application
├── global.R                    # Global data loading
├── prepare_app_data.R          # Data preparation (auto-run by cfsr_profile.R)
├── modules/
│   └── indicator_page.R        # Reusable indicator page module
├── functions/
│   ├── utils.R                 # Utility functions
│   ├── data_prep.R             # Data preparation functions
│   └── chart_builder.R         # Chart generation functions
└── www/
    └── custom.css              # Custom styles
```

---

## Data Flow

### From Processing to Dashboard

```
1. Raw Data (ShareFile)
   S:/Shared Folders/md/cfsr/uploads/2024_08/
   └── National - Supplemental Context Data - August 2024.xlsx

2. Processing (cfsr_profile.R)
   Reads from ShareFile → Processes indicators → Saves CSV
   Output: data/processed/md/2024_08/[date]/md_2024_08 - cfsr profile - national.csv

3. Preparation (prepare_app_data.R - auto-runs)
   Reads CSV → Joins dictionary → Filters to latest period → Saves RDS

4. Dashboard Data Sources
   DEV:  data/app_data/md/cfsr_indicators_latest.rds
   PROD: D:/repo_childmetrix/cm-reports/states/md/cfsr/performance/app/data/md_cfsr_indicators_latest.rds

5. Shiny App (app.R)
   Loads RDS → Renders dashboard
```

---

## Features

### Overview Page
- Grid of 8 small charts (one per indicator)
- Shows top 10 states + selected state
- Organized by category (Safety, Permanency, Well-Being)
- Click any chart to navigate to detailed page

### Indicator Pages
- Full 52-state ranking chart
- Selected state highlighted in blue
- National standard shown as green line (where applicable)
- Previous/Next navigation buttons
- Collapsible sections:
  - **Measure Details** - Indicator definition, denominator, numerator
  - **View Data Table** - Sortable/searchable table with export options

### Data Dictionary
- All 8 indicators with full metadata
- Searchable and sortable
- Export to CSV/Excel

### State Selection
- Controlled via URL parameter: `?state=md`
- State code must be lowercase 2-letter code
- Invalid states default to Maryland

---

## Production Deployment

### To ChildMetrix Platform

The dashboard integrates into the **cm-reports** platform at:
```
D:/repo_childmetrix/cm-reports/states/md/cfsr/performance/
```

**Automatic Deployment:**

When you run `cfsr_profile.R` → `prepare_app_data.R`, it automatically saves to both locations:
- **DEV:** `cfsr-profile/data/app_data/md/cfsr_indicators_latest.rds`
- **PROD:** `cm-reports/states/md/cfsr/performance/app/data/md_cfsr_indicators_latest.rds`

**Integration:**
- Shiny app runs on port 3838
- Wrapper HTML (`cm-reports/states/md/cfsr/performance/index_static.html`) embeds app in iframe
- Platform navigation passes state parameter to dashboard

See [../../cm-reports/states/md/cfsr/performance/README.md](../../cm-reports/states/md/cfsr/performance/README.md) for platform integration details.

---

## Customization

### Change Default State

Edit `app.R`:

```r
# Load initial data (will be replaced when user-specific parameters are available in server)
app_data <- load_cfsr_data("MD", "latest")  # Change "MD" to preferred state
```

### Chart Colors

Edit `functions/chart_builder.R`:

```r
# Selected state color (blue) vs other states (gray)
bar_colors <- ifelse(ind_df$is_selected, "#4472C4", "#D3D3D3")

# National standard line (green)
line = list(color = "#87D180", dash = "dash")
```

### Number of States in Overview Charts

Edit `functions/chart_builder.R`:

```r
# For overview, show only top 10 + selected state
top_states <- ind_df %>%
  slice_head(n = 10)  # Change to 15, 20, etc.
```

---

## Troubleshooting

### "Data not found" Error

**Problem:** App can't find RDS file.

**Solution:**
```r
# Check if file exists
file.exists("D:/repo_childmetrix/cfsr-profile/data/app_data/md/cfsr_indicators_latest.rds")

# If FALSE, run processing
state_code <- "md"
profile_period <- "2024_08"
source("D:/repo_childmetrix/cfsr-profile/code/cfsr_profile.R")
```

### Wrong State Highlighting

**Problem:** URL parameter not working.

**Solution:**
- Use lowercase 2-letter code: `?state=md` (not `?state=MD` or `?state=Maryland`)
- Check browser URL bar for typos
- Verify state code is valid (see state_codes in `global.R`)

### Charts Not Displaying

**Problem:** Blank boxes where charts should be.

**Solution:**
1. Check browser console (F12) for JavaScript errors
2. Try different browser (Chrome, Firefox, Edge)
3. Clear browser cache (Ctrl+Shift+R)
4. Restart Shiny app

### Processing Multiple States

**Problem:** Want to add Kentucky/Michigan data.

**Solution:**
```r
# Process each state individually
states <- c("md", "ky", "mi")

for (state in states) {
  state_code <- state
  profile_period <- "2024_08"

  # Make sure files exist in ShareFile first:
  # S:/Shared Folders/ky/cfsr/uploads/2024_08/National - Supplemental...xlsx
  # S:/Shared Folders/mi/cfsr/uploads/2024_08/National - Supplemental...xlsx

  source("D:/repo_childmetrix/cfsr-profile/code/cfsr_profile.R")
}

# Each state now has its own RDS:
# - data/app_data/md/cfsr_indicators_latest.rds
# - data/app_data/ky/cfsr_indicators_latest.rds
# - data/app_data/mi/cfsr_indicators_latest.rds
```

---

## Required Packages

```r
# Install if needed
install.packages(c(
  "shiny", "shinydashboard", "plotly", "DT",
  "dplyr", "tidyr", "ggplot2"
))
```

All packages are automatically loaded via `global.R`.

---

## Development Status

**Current Version:** Phase 3 Complete (November 2025)

**✅ Implemented:**
- All 8 CFSR indicators
- Overview page with small multiples
- Detailed indicator pages with rankings
- State highlighting and selection
- Previous/Next navigation
- Data dictionary
- Multi-state support
- ShareFile integration
- Lowercase state code convention

**🚀 Potential Future Enhancements:**
- Profile period selector (switch between 2024_08, 2025_02, etc.)
- Side-by-side state comparison mode
- Export charts as PNG/PDF
- Trend analysis across multiple periods
- Custom state groupings (regions, peer groups)

---

## Related Documentation

- **[../README.md](../README.md)** - Main project documentation and data processing workflow
- **[../docs/WORKFLOW.md](../docs/WORKFLOW.md)** - Detailed processing workflow
- **[../docs/FUNCTIONS.md](../docs/FUNCTIONS.md)** - Function reference guide
- **[../docs/CHANGELOG.md](../docs/CHANGELOG.md)** - Project history and changes
- **[../../cm-reports/states/md/cfsr/performance/README.md](../../cm-reports/states/md/cfsr/performance/README.md)** - ChildMetrix platform integration

---

## Tips

1. **Performance:** First load may take 2-3 seconds. Subsequent page changes are instant.

2. **Browser Cache:** If you make code changes and don't see them, hard refresh (Ctrl+Shift+R).

3. **Console Messages:** Watch R console during app startup for helpful diagnostic messages.

4. **Plotly Interactions:** Hover over charts to see interactive toolbar (zoom, pan, download, etc.).

5. **Data Updates:** When new CFSR data is released (every ~6 months), just re-run `cfsr_profile.R` with the new period.

---

**Built with:** R, Shiny, Plotly, DT, Tidyverse
**Last Updated:** November 2025
