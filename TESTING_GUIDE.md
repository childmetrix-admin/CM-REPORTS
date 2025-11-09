# Phase 1 - Testing Guide

**Date:** 2025-10-13
**Status:** ✅ All code updates complete - Ready for testing

---

## ✅ Completed Updates

1. ✅ **Backups created** - All files backed up safely
2. ✅ **functions_cfsr_profile.R** - Added `setup_cfsr_folders()` and `find_cfsr_file()`
3. ✅ **r_cfsr_profile.R** - Added state_code, uses new functions
4. ✅ **prepare_app_data.R** - Saves multiple period-specific RDS files
5. ✅ **global.R** - Updated for new data locations (both dev and prod)

---

## 🧪 Testing Steps

### **Test 1: Process One Period (2025_02)**

This will test the complete workflow for a single period:

```r
# Open R and navigate to project
setwd("D:/repo_childmetrix/r_cfsr_profile")

# Set parameters
state_code <- "MD"
profile_period <- "2025_02"

# Run processing
source("code/r_cfsr_profile.R")
```

**Expected Output:**
```
Created uploads folder: D:/repo_childmetrix/r_cfsr_profile/data/uploads/MD/2025_02
Created processed folder: D:/repo_childmetrix/r_cfsr_profile/data/processed/MD/2025_02
Created app_data folder: D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD
Reading file: National - Supplemental Context Data - February 2025.xlsx
[Processing indicators...]
Created run folder: D:/repo_childmetrix/r_cfsr_profile/data/processed/MD/2025_02/2025-10-13

=== Data processing complete ===
Now preparing data for Shiny app...

======================================================================
Preparing Shiny App Data
======================================================================

Using state/period from r_cfsr_profile.R: MD - 2025_02
[...]
✓ Saved to DEV (period-specific): [...]/app_data/MD/cfsr_indicators_2025_02.rds
✓ Saved to DEV (latest): [...]/app_data/MD/cfsr_indicators_latest.rds
✓ Saved to PROD (period-specific): [...]/MD_cfsr_indicators_2025_02.rds
✓ Saved to PROD (latest): [...]/MD_cfsr_indicators_latest.rds

✓ Data ready for Shiny app!
```

**Verify Files Created:**
```r
# Check processed CSV
file.exists("D:/repo_childmetrix/r_cfsr_profile/data/processed/MD/2025_02/2025-10-13/MD_2025_02 - cfsr profile - national - 2025-10-13.csv")

# Check RDS files
file.exists("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_2025_02.rds")
file.exists("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_latest.rds")
file.exists("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app/data/MD_cfsr_indicators_2025_02.rds")
```

---

### **Test 2: Verify Data Structure**

```r
# Load and inspect the RDS file
test_data <- readRDS("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_2025_02.rds")

# Check structure
str(test_data)
nrow(test_data)  # Should have data rows
names(test_data)  # Should include all expected columns

# Check key columns exist
required_cols <- c("state", "indicator", "period", "performance",
                   "state_rank", "reporting_states", "profile_version")
all(required_cols %in% names(test_data))  # Should be TRUE
```

---

### **Test 3: Test Shiny App (Development)**

```r
# Run Shiny app from dev location
shiny::runApp("D:/repo_childmetrix/r_cfsr_profile/shiny_app", port = 3838)
```

**In Browser:**
1. Navigate to `http://localhost:3838/?state=MD`
2. Check that data loads correctly
3. Navigate through different indicators
4. Verify charts and tables display

**Expected:** App should load with MD February 2025 data

---

### **Test 4: Test Shiny App (Production)**

```r
# Run Shiny app from production location
shiny::runApp("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app", port = 3838)
```

**In Browser:**
1. Navigate to `http://localhost:3838/?state=MD`
2. Verify same functionality as dev

---

### **Test 5: Process Additional Periods**

Process the other two periods to test multi-period support:

```r
# Process 2024_08
state_code <- "MD"
profile_period <- "2024_08"
source("D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R")

# Process 2024_02
state_code <- "MD"
profile_period <- "2024_02"
source("D:/repo_childmetrix/r_cfsr_profile/code/r_cfsr_profile.R")
```

**Expected:** Each period creates its own folders and RDS files

**Verify Multiple Periods Exist:**
```r
# Check all three periods have RDS files
file.exists("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_2025_02.rds")
file.exists("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_2024_08.rds")
file.exists("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_2024_02.rds")
```

---

### **Test 6: Batch Processing (Optional)**

Test the batch processing system:

```r
# Preview what will be processed
source("code/process_cfsr_batch.R")
preview_processing_queue()

# Process all periods at once
process_all_cfsr_data()

# Check processing log
log <- read.csv("data/processing_log.csv")
print(log)
```

**Expected:**
- Preview shows all 3 MD periods
- Processing completes successfully
- Log shows all 3 as "success"

---

### **Test 7: Test Batch File Organization**

Test organizing files from an "uploads" folder:

```r
# Organize files (should already be done, but test again)
source("code/organize_cfsr_uploads.R")
result <- organize_all_cfsr_files("D:/repo_childmetrix/r_cfsr_profile/uploads")

# Check result
print(result$organized)  # Number of files organized
print(result$by_state)   # Files by state
```

---

## ✅ Success Criteria

All tests pass if:

1. ✅ **Processing completes** without errors
2. ✅ **CSV files created** in `data/processed/MD/{period}/YYYY-MM-DD/`
3. ✅ **Multiple RDS files exist** - one per period
4. ✅ **Shiny app loads** and displays data correctly
5. ✅ **All 3 periods process** successfully
6. ✅ **No overwriting** - all period files coexist

---

## ⚠️ Troubleshooting

### **Error: "folder_uploads not found"**
```r
# Run setup first
setup_cfsr_folders("2025_02", "MD")
```

### **Error: "No file found matching keyword 'National'"**
```r
# Check files in uploads folder
list.files("D:/repo_childmetrix/r_cfsr_profile/data/uploads/MD/2025_02/")

# Should show:
# - National - Supplemental Context Data - February 2025.xlsx
# - Maryland - Supplemental Context Data - February 2025.xlsx
# - MD - CFSR 4 Data Profile - February 2025.pdf
```

### **Error: "Shiny app data not found"**
```r
# Check if RDS files exist
file.exists("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_latest.rds")

# If not, run prepare_app_data.R manually
source("shiny_app/prepare_app_data.R")
```

### **Shiny app shows old data**
```r
# Check which file is loaded
readRDS("D:/repo_childmetrix/r_cfsr_profile/data/app_data/MD/cfsr_indicators_latest.rds") %>%
  distinct(profile_version, period)

# Should show the most recent period you processed
```

---

## 🔄 If Something Goes Wrong

### **Restore from Backup:**
```bash
# Restore all backup files
cd D:/repo_childmetrix/r_cfsr_profile
cp backups/2025-10-13_pre-phase1/r_cfsr_profile.R.backup code/r_cfsr_profile.R
cp backups/2025-10-13_pre-phase1/prepare_app_data.R.backup shiny_app/prepare_app_data.R
cp backups/2025-10-13_pre-phase1/global.R.backup shiny_app/global.R

cd D:/repo_childmetrix/r_utilities
cp backups/2025-10-13_pre-phase1/functions_cfsr_profile.R.backup project_specific/functions_cfsr_profile.R

cd D:/repo_childmetrix/r_cm_reports
cp backups/2025-10-13_pre-phase1/global.R.backup md/cfsr/performance/app/global.R
```

### **Or Restore from Git:**
```bash
cd D:/repo_childmetrix/r_cfsr_profile
git checkout e9ff9d7 -- code/r_cfsr_profile.R
git checkout e9ff9d7 -- shiny_app/prepare_app_data.R
git checkout e9ff9d7 -- shiny_app/global.R

cd D:/repo_childmetrix/r_cm_reports
git checkout 467a4a6 -- md/cfsr/performance/app/global.R
```

---

## 📊 Expected Folder Structure After Tests

```
r_cfsr_profile/
└── data/
    ├── uploads/                          # Raw files (already organized)
    │   ├── _shared/
    │   │   ├── 2025_02/
    │   │   ├── 2024_08/
    │   │   └── 2024_02/
    │   └── MD/
    │       ├── 2025_02/ (3 files)
    │       ├── 2024_08/ (3 files)
    │       └── 2024_02/ (3 files)
    │
    ├── processed/                         # NEW - Created by processing
    │   └── MD/
    │       ├── 2025_02/
    │       │   └── 2025-10-13/
    │       │       └── MD_2025_02 - cfsr profile - national - 2025-10-13.csv
    │       ├── 2024_08/
    │       │   └── 2025-10-13/
    │       │       └── MD_2024_08 - cfsr profile - national - 2025-10-13.csv
    │       └── 2024_02/
    │           └── 2025-10-13/
    │               └── MD_2024_02 - cfsr profile - national - 2025-10-13.csv
    │
    ├── app_data/                          # NEW - Created by prepare_app_data.R
    │   └── MD/
    │       ├── cfsr_indicators_2025_02.rds  ← Period-specific
    │       ├── cfsr_indicators_2024_08.rds
    │       ├── cfsr_indicators_2024_02.rds
    │       └── cfsr_indicators_latest.rds   ← Copy of newest
    │
    └── processing_log.csv                 # NEW - Created by batch processing
```

---

## 🎉 Next Steps After Testing

Once all tests pass:

1. **Commit changes** to git
2. **Deploy to staging server** (if applicable)
3. **Document workflow** for team members
4. **Create user guide** for adding new periods
5. **Plan multi-state expansion** (when you get KY, VA, etc. data)

---

## 📝 Notes for Future

### **Adding a New Period:**
```r
# 1. Organize files
organize_all_cfsr_files("~/Downloads")

# 2. Process
state_code <- "MD"
profile_period <- "2025_08"  # New period
source("code/r_cfsr_profile.R")

# Done! New period RDS created automatically
```

### **Adding a New State:**
```r
# Same process, just change state_code
state_code <- "KY"
profile_period <- "2025_02"
source("code/r_cfsr_profile.R")
```

### **Batch Processing Multiple States/Periods:**
```r
source("code/process_cfsr_batch.R")
process_all_cfsr_data()  # Processes everything in uploads/
```

---

**Ready to test! Start with Test 1 and work through each step.**
