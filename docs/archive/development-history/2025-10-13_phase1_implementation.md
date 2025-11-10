# Phase 1 Implementation Status

**Date:** 2025-10-13
**Status:** ✅ Part 1 Complete - Part 2 Pending

---

## ✅ Completed

### 1. Git Backup
- ✅ Committed current working state to both repositories
- ✅ r_cfsr_profile: commit `e9ff9d7`
- ✅ r_cm_reports: commit `467a4a6`

### 2. File Organization System
- ✅ Created `code/organize_cfsr_uploads.R` with functions:
  - `organize_all_cfsr_files()` - Batch organize all CFSR files from source directory
  - `organize_cfsr_files()` - Organize files for single state
  - `extract_period_from_filename()` - Auto-detect period from filename
  - `extract_state_from_filename()` - Auto-detect state code from filename
  - `state_name_to_code()` - Convert state name to 2-letter code

- ✅ **Features:**
  - Auto-detects state and period from filenames (no manual input needed!)
  - Handles National files: saves to `_shared/` then copies to each state folder
  - Checksum-based duplicate detection (skips identical files)
  - Organized structure: `data/uploads/{STATE}/{PERIOD}/`
  - Support for full state names ("Maryland") and codes ("MD")

- ✅ **Tested with MD sample data:**
  - 3 periods: 2025_02, 2024_08, 2024_02
  - 9 files total (6 MD-specific + 3 National)
  - All files organized correctly
  - National files copied to each MD period folder

### 3. Batch Processing System
- ✅ Created `code/process_cfsr_batch.R` with functions:
  - `process_all_cfsr_data()` - Process all pending state/period combinations
  - `preview_processing_queue()` - Preview what will be processed
  - `process_single_cfsr()` - Process one state/period
  - `scan_pending_work()` - Find unprocessed data
  - Processing log functions (get/save/update)

- ✅ **Features:**
  - Processing status tracker (`data/processing_log.csv`)
  - Skip already-processed data automatically
  - Force reprocess option
  - Filter by states and/or periods
  - Dry run mode
  - Continue on error (one failure doesn't stop batch)
  - Detailed progress reporting

---

## 🔧 Remaining Work

### 4. Update `r_cfsr_profile.R`
**Changes needed:**

```r
# Add state_code parameter
state_code <- "MD"  # ADD THIS LINE
profile_period <- "2025_02"

# Update file paths to read from uploads instead of raw
# OLD: data/2025_02/raw/
# NEW: data/uploads/MD/2025_02/

# Update output paths to include state
# OLD: data/2025_02/processed/2025-10-13/
# NEW: data/processed/MD/2025_02/2025-10-13/

# Update find_file() function calls to look in uploads
data_df_temp <- find_file(
  keyword = "National",
  directory_type = "uploads",  # Changed from "raw"
  state_code = state_code,      # NEW parameter
  profile_period = profile_period,
  file_type = "excel",
  sheet_name = "Entry rates"
)
```

### 5. Update `prepare_app_data.R`
**Changes needed:**

```r
# Read from new processed location
# OLD: data/2025_02/processed/2025-10-13/
# NEW: data/processed/MD/2025_02/2025-10-13/

# Save multiple RDS files instead of just one
# OLD: shiny_app/data/cfsr_indicators_latest.rds
# NEW:
#   data/app_data/MD/cfsr_indicators_2025_02.rds
#   data/app_data/MD/cfsr_indicators_latest.rds (symlink or copy of newest)
#   r_cm_reports/md/cfsr/performance/app/data/MD_cfsr_indicators_2025_02.rds

# Keep period-specific RDS files (don't overwrite)
```

### 6. Update Shiny App (`global.R`)
**Changes needed:**

```r
# Load profile-specific data based on URL parameter
profile_param <- getQueryString()$profile %||% "2025_02"
state_param <- getQueryString()$state %||% "MD"

data_file <- file.path("data", paste0(state_param, "_cfsr_indicators_", profile_param, ".rds"))

if (file.exists(data_file)) {
  app_data <- readRDS(data_file)
} else {
  # Fallback to latest
  app_data <- readRDS("data/cfsr_indicators_latest.rds")
}
```

### 7. Update `functions_cfsr_profile.R`
**Changes needed:**

Update `find_file()` and `setup_folders()` functions to:
- Support new directory structure
- Add `state_code` parameter
- Look in `uploads/` instead of `raw/`
- Create state-specific `processed/` folders

---

## 📁 New Folder Structure

```
r_cfsr_profile/
├── data/
│   ├── uploads/                          # Raw files from ACF/states
│   │   ├── _shared/                      # National files (source of truth)
│   │   │   ├── 2025_02/
│   │   │   │   └── National - Supplemental Context Data - February 2025.xlsx
│   │   │   ├── 2024_08/
│   │   │   └── 2024_02/
│   │   └── MD/                            # Maryland files
│   │       ├── 2025_02/
│   │       │   ├── National - Supplemental Context Data - February 2025.xlsx  (copied)
│   │       │   ├── Maryland - Supplemental Context Data - February 2025.xlsx
│   │       │   └── MD - CFSR 4 Data Profile - February 2025.pdf
│   │       ├── 2024_08/
│   │       └── 2024_02/
│   │
│   ├── processed/                         # Processed CSVs
│   │   └── MD/
│   │       ├── 2025_02/
│   │       │   └── 2025-10-13/
│   │       │       └── MD_2025_02_cfsr_profile_national_2025-10-13.csv
│   │       ├── 2024_08/
│   │       └── 2024_02/
│   │
│   ├── app_data/                          # RDS files for Shiny
│   │   └── MD/
│   │       ├── cfsr_indicators_2025_02.rds
│   │       ├── cfsr_indicators_2024_08.rds
│   │       ├── cfsr_indicators_2024_02.rds
│   │       └── cfsr_indicators_latest.rds  (copy of newest)
│   │
│   └── processing_log.csv                 # Status tracker
│
└── code/
    ├── organize_cfsr_uploads.R            # ✅ NEW - File organization
    ├── process_cfsr_batch.R               # ✅ NEW - Batch processing
    ├── r_cfsr_profile.R                   # 🔧 NEEDS UPDATE
    └── functions_cfsr_profile.R           # 🔧 NEEDS UPDATE (in r_utilities)
```

---

## 🧪 Testing Plan

Once updates are complete:

### Test 1: Organize Files
```r
source("code/organize_cfsr_uploads.R")
organize_all_cfsr_files("D:/repo_childmetrix/r_cfsr_profile/uploads")
```
**Expected:** Files organized into `data/uploads/MD/{period}/` with National files copied

### Test 2: Preview Queue
```r
source("code/process_cfsr_batch.R")
preview_processing_queue()
```
**Expected:** Shows MD has 3 pending periods (2025_02, 2024_08, 2024_02)

### Test 3: Process All
```r
process_all_cfsr_data()
```
**Expected:**
- Processes 3 state/period combinations
- Creates CSVs in `data/processed/MD/{period}/`
- Creates RDS in `data/app_data/MD/`
- Updates processing log
- Copies to r_cm_reports

### Test 4: Verify Skip Logic
```r
process_all_cfsr_data()  # Run again
```
**Expected:** Skips all 3 (already processed)

### Test 5: Force Reprocess
```r
process_all_cfsr_data(force_reprocess = TRUE, periods = "2025_02")
```
**Expected:** Reprocesses only MD 2025_02

---

## 📝 Usage Examples

### Workflow 1: Process New Upload

```r
# 1. User downloads files to Downloads folder
# 2. Organize files
source("code/organize_cfsr_uploads.R")
organize_all_cfsr_files("C:/Users/heisl/Downloads")

# 3. Preview what will be processed
source("code/process_cfsr_batch.R")
preview_processing_queue()

# 4. Process everything
process_all_cfsr_data()
```

### Workflow 2: Process Specific State/Period

```r
source("code/process_cfsr_batch.R")
process_all_cfsr_data(states = "MD", periods = "2025_02")
```

### Workflow 3: Dry Run First

```r
source("code/process_cfsr_batch.R")
process_all_cfsr_data(dry_run = TRUE)  # See what would happen
process_all_cfsr_data()                # Actually do it
```

---

## 🎯 Next Steps

1. **Update `r_utilities/project_specific/functions_cfsr_profile.R`:**
   - Add `state_code` parameter to `setup_folders()`
   - Update `find_file()` to look in `uploads/`
   - Update folder creation logic

2. **Update `r_cfsr_profile.R`:**
   - Add `state_code` variable
   - Update all file paths
   - Test with one period

3. **Update `prepare_app_data.R`:**
   - Read from new processed location
   - Save period-specific RDS files
   - Create app_data folder structure

4. **Test full workflow:**
   - Organize → Process → Deploy → Load in Shiny

5. **Update Shiny app:**
   - Dynamic profile loading based on URL
   - Test profile switching

---

## ⚠️ Important Notes

### For Testing
- Currently only MD data available (3 periods)
- MI data removed (CFSR 3 vs 4 structure differences)
- Can test multi-state later when more CFSR 4 data available

### Breaking Changes
- **Old workflow will NOT work** after these changes
- **Must run organize_all_cfsr_files()** before processing
- **Old `data/YYYY_MM/raw/` structure no longer used**

### Backward Compatibility
If you need to keep old workflow working:
- Keep old `r_cfsr_profile.R` as `r_cfsr_profile_OLD.R`
- New workflow uses updated script
- Can run both in parallel during transition

---

## 📞 Questions for User

Before proceeding with remaining updates:

1. **Are you ready to update the processing scripts?** This will break the old workflow.

2. **Should we keep old workflow as fallback?** (Save old script as `_OLD.R`)

3. **Want to test each step incrementally** or do all updates at once?

4. **Any concerns about the folder structure** or approach?

---

**Status:** Ready to proceed with steps 4-6 when you confirm!
