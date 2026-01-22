# CFSR Profile Data Processing Workflow

## Overview

This document explains how to process CFSR profile data and prepare it for the Shiny app. The scripts are now **chained together** so you only need to run one file.

## Profile Version Management

### Folder Structure

Data is organized by profile period (YYYY_MM format):

```
r_cfsr_profile/
└── data/
    ├── 2025_02/                    # February 2025 profile
    │   ├── raw/                    # Input Excel files
    │   └── processed/
    │       └── 2025-10-10/         # Date-stamped run folders
    │           └── *.csv           # Generated CSV files
    │
    └── 2025_08/                    # August 2025 profile
        ├── raw/                    # Input Excel files
        └── processed/
            └── 2025-10-15/         # Date-stamped run folders
                └── *.csv           # Generated CSV files
```

### How It Works

1. **r_cfsr_profile.R** uses `profile_period` variable to determine which folder to use
2. **prepare_app_data.R** looks for the **most recent date subfolder WITHIN the specified profile period**
3. Each profile period (2025_02, 2025_08, etc.) is completely isolated from others

This ensures:
- ✅ Running data for 2025_02 profile only affects `data/2025_02/` folder
- ✅ Running data for 2025_08 profile only affects `data/2025_08/` folder
- ✅ No cross-contamination between profile versions
- ✅ You can have multiple profile versions ready and switch between them

## How to Process Data

### Step 1: Place Raw Data File

Copy the Excel file to the appropriate raw folder:

```
data/[YYYY_MM]/raw/National - Supplemental Context Date - [Month YYYY].xlsx
```

Example for February 2025 profile:
```
data/2025_02/raw/National - Supplemental Context Date - February 2025.xlsx
```

### Step 2: Set Profile Period

In [code/r_cfsr_profile.R](code/r_cfsr_profile.R), update line 51:

```r
# IMPORTANT: Set the profile period here (e.g., "2025_02", "2025_08")
# This determines which folder the data is saved to and processed from
profile_period <- "2025_02"  # <-- CHANGE THIS
```

### Step 3: Run r_cfsr_profile.R

```r
source("D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R")
```

**That's it!** The script will:
1. ✅ Process all 8 indicators from the Excel file
2. ✅ Calculate direction-aware rankings for all periods
3. ✅ Add reporting_states column
4. ✅ Save CSV to `data/[profile_period]/processed/[today's date]/`
5. ✅ **Automatically run prepare_app_data.R**
6. ✅ Generate the .rds file for the Shiny app
7. ✅ Display summary statistics

### Output

You'll see messages like:

```
=== Data processing complete ===
Now preparing data for Shiny app...

Looking for data in: D:/repo_childmetrix/r_cfsr_profile/data
Using profile period from r_cfsr_profile.R: 2025_02
Looking in processed folder: D:/repo_childmetrix/r_cfsr_profile/data/2025_02/processed
Using run date: 2025-10-10
Loading data from: D:/repo_childmetrix/.../2025_02_cfsr_profile_national_2025-10-10.csv
Loaded 1248 rows
...
Saved prepared data to: D:/repo_childmetrix/r_cfsr_profile/shiny_app/data/cfsr_indicators_latest.rds

=== All done! ===
Data ready for Shiny app at profile period: 2025_02
```

## Manual Running (Advanced)

If you need to run the scripts separately:

### Option 1: Run r_cfsr_profile.R only

Just run the script - it will auto-chain to prepare_app_data.R

### Option 2: Run prepare_app_data.R manually

```r
# Set the profile period first
profile_period <- "2025_02"

# Then run the script
source("D:/repo_childmetrix/r_cfsr_profile/shiny_app/prepare_app_data.R")
```

**OR** just run it without setting profile_period - it will automatically use the most recent YYYY_MM folder:

```r
source("D:/repo_childmetrix/r_cfsr_profile/shiny_app/prepare_app_data.R")
```

## Switching Between Profile Versions

### Scenario: You have both 2025_02 and 2025_08 data processed

To use **February 2025** profile in the app:
```r
profile_period <- "2025_02"
source("D:/repo_childmetrix/r_cfsr_profile/shiny_app/prepare_app_data.R")
```

To use **August 2025** profile in the app:
```r
profile_period <- "2025_08"
source("D:/repo_childmetrix/r_cfsr_profile/shiny_app/prepare_app_data.R")
```

The prepare_app_data.R script will:
1. Look only in `data/[profile_period]/processed/` folder
2. Find the most recent date subfolder within that profile
3. Use that data to generate the .rds file for the Shiny app

## Key Files

| File | Purpose |
|------|---------|
| [code/r_cfsr_profile.R](code/r_cfsr_profile.R) | Main data processing script - **Run this one** |
| [shiny_app/prepare_app_data.R](shiny_app/prepare_app_data.R) | Prepares data for Shiny - **Auto-runs** |
| [code/cfsr_round4_indicators_dictionary.csv](code/cfsr_round4_indicators_dictionary.csv) | Indicator metadata (names, directions, formats) |
| shiny_app/data/cfsr_indicators_latest.rds | Output file used by Shiny app |

## Troubleshooting

### "No YYYY_MM data folders found"
- Check that you set `profile_period` correctly (e.g., "2025_02", not "2025-02")
- Check that the raw Excel file exists in `data/[profile_period]/raw/`

### "Dictionary not found"
- Check that `code/cfsr_round4_indicators_dictionary.csv` exists
- Check the path in prepare_app_data.R line 60

### "No CSV files found in processed folder"
- r_cfsr_profile.R may have failed
- Check console for error messages
- Verify raw Excel file is in the correct location

### Wrong profile version showing in app
- Re-run prepare_app_data.R with the correct `profile_period`
- Check the summary output to confirm which period was used
- Restart the Shiny app to load the new .rds file
