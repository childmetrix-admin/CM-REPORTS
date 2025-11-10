# CFSR Performance Dashboard - Integration Guide

## Overview

This directory contains the CFSR Statewide Data Indicators interactive dashboard, integrated into the ChildMetrix reporting platform.

## Directory Structure

```
performance/
├── app/                          # Shiny application files
│   ├── app.R                    # Main Shiny app
│   ├── global.R                 # Global setup
│   ├── modules/                 # Shiny modules
│   ├── functions/               # Helper functions
│   ├── data/                    # Data files (.rds)
│   └── www/                     # Static assets
├── index_static.html            # Wrapper for iframe integration (USE THIS)
├── index.html                   # Alternative wrapper for localhost dev
├── cfsr_md_2025_02.html        # Legacy static reports (deprecated)
├── cfsr_md_2025_08.html        # Legacy static reports (deprecated)
└── README.md                    # This file
```

## How It Works

### 1. Data Processing Pipeline

**Location:** `D:/repo_childmetrix/cfsr-profile/code/cfsr_profile.R`

```r
# Set profile period
profile_period <- "2025_02"  # Change this for different profiles

# Run the script - it auto-chains to prepare_app_data.R
source("D:/repo_childmetrix/cfsr-profile/code/cfsr_profile.R")
```

**What happens:**
1. Processes raw Excel file from `cfsr-profile/data/[profile]/raw/`
2. Calculates direction-aware rankings for all periods
3. Adds reporting_states column
4. Saves CSV to `cfsr-profile/data/[profile]/processed/[date]/`
5. **Automatically runs** `prepare_app_data.R`
6. Generates `.rds` file and saves to **BOTH**:
   - Development: `cfsr-profile/shiny_app/data/cfsr_indicators_latest.rds`
   - **Production: `cm-reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds`**

### 2. Deployment Structure

**Development Environment:**
- Location: `D:/repo_childmetrix/cfsr-profile/shiny_app/`
- Purpose: Testing and development
- Run directly: `shiny::runApp("D:/repo_childmetrix/cfsr-profile/shiny_app")`

**Production Environment:**
- Location: `D:/repo_childmetrix/cm-reports/md/cfsr/performance/app/`
- Purpose: Deployed in ChildMetrix platform
- Access: Via iframe wrapper at `cfsr/performance/index_static.html`

### 3. Integration with ChildMetrix Platform

The dashboard is embedded in the main platform via:

**Main Navigation** (`md/index.html`):
- Click "CFSR Data Profile" in sidebar
- Loads `cfsr/performance/index_static.html` in iframe

**Secondary Navigation** (top bar):
- Performance (active) → Shows interactive dashboard
- Presentations → CFSR presentations
- Data Dictionary → Indicator definitions
- Notes → Implementation notes

**Profile Period Selector:**
- Dropdown in top-right: "August 2025", "February 2025", etc.
- Changes URL parameter: `?profile=2025_08`
- Dashboard wrapper passes this to Shiny app (future enhancement)

### 4. State Parameter Handling

The platform passes the state via URL parameter:
```
cfsr/performance/index_static.html?state=MD&profile=2025_02
```

The wrapper HTML extracts `state` and passes it to the Shiny app iframe:
```javascript
const state = getStateFromURL() || 'MD';
iframe.src = `app/?state=${state}`;
```

The Shiny app (`app.R`) reads the state parameter:
```r
selected_state <- reactive({
  query <- parseQueryString(session$clientData$url_search)
  query$state %||% "Maryland"
})
```

## Running the Dashboard

### Option 1: Standalone (Development)

```r
# From R console
shiny::runApp("D:/repo_childmetrix/cfsr-profile/shiny_app")

# Or with specific port
shiny::runApp("D:/repo_childmetrix/cfsr-profile/shiny_app", port = 3838)
```

Then navigate to: `http://localhost:3838?state=MD`

### Option 2: Integrated in Platform (Production)

**Requirements:**
1. Shiny Server installed and configured
2. App deployed to Shiny Server directory

**Shiny Server Configuration** (`/etc/shiny-server/shiny-server.conf`):
```
server {
  listen 3838;

  location /cfsr {
    site_dir D:/repo_childmetrix/cm-reports/md/cfsr/performance/app;
    log_dir /var/log/shiny-server;
    directory_index on;
  }
}
```

**Access:**
1. Start Shiny Server
2. Open ChildMetrix platform: `file:///D:/repo_childmetrix/cm-reports/md/index.html`
3. Click "CFSR Data Profile" in sidebar
4. Dashboard loads in iframe via `cfsr/performance/index_static.html`

### Option 3: Quick Test (No Server)

For quick testing without Shiny Server:

1. Open two browser tabs:
   - Tab 1: Run Shiny standalone on port 3838
   - Tab 2: Open `file:///D:/repo_childmetrix/cm-reports/md/index.html`

2. Update `index_static.html` line ~130 temporarily:
   ```javascript
   const appPath = `http://localhost:3838/?state=${state}`;
   ```

3. Click "CFSR Data Profile" in platform

## Updating Data

### To update for a new profile period:

1. **Place raw data file:**
   ```
   D:/repo_childmetrix/cfsr-profile/data/2025_02/raw/
   National - Supplemental Context Date - February 2025.xlsx
   ```

2. **Update profile period in R script:**
   ```r
   # In cfsr_profile.R line 51
   profile_period <- "2025_02"
   ```

3. **Run data processing:**
   ```r
   source("D:/repo_childmetrix/cfsr-profile/code/cfsr_profile.R")
   ```

4. **Verify output:**
   ```
   ✓ CSV saved to: data/2025_02/processed/[date]/
   ✓ RDS saved to DEV: cfsr-profile/shiny_app/data/
   ✓ RDS saved to PROD: cm-reports/md/cfsr/performance/app/data/
   ```

5. **Restart Shiny app** (if running) to load new data

## File Locations Summary

| What | Development | Production |
|------|------------|-----------|
| **Shiny App** | `cfsr-profile/shiny_app/` | `cm-reports/md/cfsr/performance/app/` |
| **Data (.rds)** | `cfsr-profile/shiny_app/data/` | `cm-reports/md/cfsr/performance/app/data/` |
| **Data Processing** | `cfsr-profile/code/cfsr_profile.R` | (same) |
| **Raw Data** | `cfsr-profile/data/[profile]/raw/` | (same) |
| **Wrapper HTML** | N/A | `cm-reports/md/cfsr/performance/index_static.html` |

## Troubleshooting

### Dashboard not loading in iframe

1. Check Shiny app is running:
   ```r
   shiny::runApp("D:/repo_childmetrix/cm-reports/md/cfsr/performance/app", port = 3838)
   ```

2. Check browser console for errors (F12)

3. Verify data file exists:
   ```
   cm-reports/md/cfsr/performance/app/data/cfsr_indicators_latest.rds
   ```

### Wrong state showing

1. Check URL parameter in address bar: `?state=MD`
2. Check platform is passing state correctly
3. Check Shiny app `selected_state()` reactive

### Wrong profile period

1. Re-run `cfsr_profile.R` with correct `profile_period`
2. Verify RDS file updated in PROD location
3. Restart Shiny app

### Data not updating

1. Verify `prepare_app_data.R` ran successfully
2. Check both DEV and PROD locations for `.rds` file
3. Check file timestamp matches recent processing
4. Restart Shiny app to clear cache

## Future Enhancements

- [ ] Multiple profile versions: Load different `.rds` files based on `?profile=2025_08` parameter
- [ ] Direct state switching: Update Shiny app when user changes state in main platform
- [ ] Remove legacy static HTML files once fully migrated to interactive dashboard
- [ ] Add authentication/authorization if needed for production deployment
- [ ] Consider using ShinyProxy or RStudio Connect for enterprise deployment
