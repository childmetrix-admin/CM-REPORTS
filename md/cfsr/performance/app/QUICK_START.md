# Quick Start Guide - CFSR Shiny Dashboard

**Last Updated:** October 9, 2025

---

## 🚀 Running the App (3 Easy Steps)

### Step 1: Prepare the Data

Open R or RStudio and run:

```r
# Set working directory
setwd("D:/repo_childmetrix/r_cfsr_profile/shiny_app")

# Prepare data for app
source("prepare_app_data.R")
```

**Expected Output:**
```
Using period: 2025_02
Using run date: 2025-10-09
Loading data from: ../data/2025_02/processed/2025-10-09/2025_02 - cfsr profile - national - 2025-10-09.csv
Loaded 416 rows
Loaded dictionary with 8 indicators
Filtered to latest period: 416 rows
Joined dictionary metadata
Saved prepared data to: data/cfsr_indicators_latest.rds

=== SUMMARY ===
Total rows: 416
Unique indicators: 8
Unique states: 52
Profile version: February 2025

Data ready for Shiny app!
```

### Step 2: Run the App

```r
# Option 1: In RStudio
# Open app.R and click "Run App" button

# Option 2: From R console
library(shiny)
runApp("D:/repo_childmetrix/r_cfsr_profile/shiny_app")
```

### Step 3: Test the App

**Default URL:** `http://127.0.0.1:XXXX/`
- Replace XXXX with the port shown in console (usually 3838, 4567, etc.)

**Test URLs:**
- Default state (Maryland): `http://127.0.0.1:XXXX/`
- California: `http://127.0.0.1:XXXX/?state=ca`
- Texas: `http://127.0.0.1:XXXX/?state=tx`

---

## 📋 What to Check

### ✅ Overview Page
1. Click "Overview" in left sidebar
2. Should see 8 charts in grid (2 + 4 + 2)
3. State badge at top shows your state
4. Profile version shows "Profile: February 2025" (or current)

### ✅ Indicator Pages
1. Click "Safety" → "Entry Rate"
2. Should see:
   - Full chart with 52 states
   - Your state highlighted in blue
   - Navigation buttons ("Next: Maltreatment")
   - Collapsible "Measure Details" section
   - Collapsible "View Data Table" section

### ✅ Navigation
1. Click "Next: Maltreatment" button
2. Should navigate to Maltreatment in Care page
3. Should see both "Previous" and "Next" buttons
4. Click "Previous: Entry Rate" to go back

### ✅ Data Dictionary
1. Click "Data Dictionary" in left sidebar
2. Should see searchable table with 8 indicators
3. Test search box (type "permanency")
4. Test export buttons (CSV, Excel, Copy)

---

## 🐛 Troubleshooting

### "No data found" Error

**Problem:** App shows error message about missing data.

**Solution:**
```r
# Check if RDS file exists
file.exists("data/cfsr_indicators_latest.rds")

# If FALSE, run prepare script
source("prepare_app_data.R")
```

### "Dictionary not found" Error

**Problem:** Can't find dictionary CSV file.

**Solution:**
```r
# Check if dictionary exists
file.exists("../code/cfsr_round4_indicators_dictionary.csv")

# If FALSE, check your working directory
getwd()  # Should be: D:/repo_childmetrix/r_cfsr_profile/shiny_app
```

### Charts Not Displaying

**Problem:** Blank boxes where charts should be.

**Solution:**
1. Check browser console (F12) for JavaScript errors
2. Try a different browser (Chrome, Firefox, Edge)
3. Refresh the page (Ctrl+R or Cmd+R)
4. Restart the Shiny app

### State Not Highlighting

**Problem:** Wrong state is highlighted or no highlighting.

**Solution:**
1. Check URL parameter: `?state=md` (lowercase, 2-letter code)
2. Verify state code is valid (see `state_codes` in global.R)
3. Try using full state name in URL won't work - must use 2-letter code

### Navigation Buttons Not Working

**Problem:** Clicking Previous/Next does nothing.

**Solution:**
1. Check browser console for JavaScript errors
2. Verify sidebar menu items have correct `data-value` attributes
3. Try clicking the sidebar directly to test navigation

---

## 📦 Required Packages

The app will auto-load these packages (defined in global.R):

```r
library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(ggplot2)
```

**To install all packages:**
```r
install.packages(c("shiny", "shinydashboard", "plotly", "DT",
                   "dplyr", "tidyr", "ggplot2"))
```

---

## 🔄 Updating Data

When new CFSR data is released (every ~6 months):

### Step 1: Process Raw Data
```r
# Run main processing script
setwd("D:/repo_childmetrix/r_cfsr_profile")
source("code/r_cfsr_profile.R")
```

### Step 2: Prepare for Shiny
```r
# Prepare app data
setwd("shiny_app")
source("prepare_app_data.R")
```

### Step 3: Restart App
If app is already running, stop it (Esc in RStudio console) and re-run.

---

## 🎨 Customization

### Change Default State

Edit [functions/utils.R:53](functions/utils.R#L53):

```r
# Default to Maryland if not found
if (is.null(state_name)) {
  state_name <- "Maryland"  # ← Change this
}
```

### Change Chart Colors

Edit [app.R](app.R) or [functions/chart_builder.R](functions/chart_builder.R):

```r
# Selected state color
bar_colors <- ifelse(ind_df$is_selected, "#4472C4", "#D3D3D3")
                                          ^^^^^^^^   ^^^^^^^^
                                          Blue       Gray

# Target line color
line = list(color = "#87D180", ...)
                     ^^^^^^^^
                     Green
```

### Add More States to Overview Charts

Edit [functions/chart_builder.R:116](functions/chart_builder.R#L116):

```r
# For overview, show only top 10 + selected state if not in top 10
top_states <- ind_df %>%
  slice_head(n = 10)  # ← Change to 15, 20, etc.
```

---

## 📚 Documentation

- **[README.md](README.md)** - Full project documentation
- **[PHASE3_SUMMARY.md](PHASE3_SUMMARY.md)** - Technical implementation details
- **[test_phase3.R](test_phase3.R)** - Automated testing script

---

## 💡 Tips

1. **Performance**: First load may take 2-3 seconds. Subsequent page changes are instant.

2. **Browser Cache**: If you make changes and don't see them, clear browser cache (Ctrl+Shift+R)

3. **Development Mode**: For faster testing, set working directory once:
   ```r
   setwd("D:/repo_childmetrix/r_cfsr_profile/shiny_app")
   ```

4. **Console Messages**: Watch the R console for helpful messages during app startup

5. **Plotly Toolbar**: Hover over charts to see Plotly interactions (zoom, pan, download)

---

## 🎉 That's It!

You should now have a fully functional CFSR dashboard with:
- ✅ Overview page (8 charts)
- ✅ 8 detailed indicator pages
- ✅ Previous/Next navigation
- ✅ Data dictionary
- ✅ State highlighting
- ✅ Interactive charts

**Enjoy exploring the data! 📊**
