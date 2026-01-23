#####################################
#####################################
# PROCESS CFSR DATA PROFILES
#####################################
#####################################

# Entry point for all CFSR profile processing workflows
# This script provides a user-friendly interface to run_profile.R

# Instructions:
# 1. Set your parameters in the RUN section below
# 2. Click "Source" to run
# 3. Check console for results

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Detect monorepo root
detect_monorepo_root <- function() {
  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "CLAUDE.md")) ||
        file.exists(file.path(current, ".git"))) {
      return(current)
    }
    current <- dirname(current)
  }
  return(Sys.getenv("CM_REPORTS_ROOT", "d:/repo_childmetrix/cm-reports"))
}

# Load the run_profile function
monorepo_root <- detect_monorepo_root()
source(file.path(monorepo_root, "cfsr/extraction/run_profile.R"))

#####################################
# RUN ----
#####################################

# Uncomment ONE workflow below and modify as needed
# Source options:
# - all     = All CFSR files found (pdf, national, and state)
# - rsp     = Risk-Standardized Performance (page 2 of PDF)
# - observed = Observed Performance (page 4 of PDF)
# - national = National supplemental context (Excel file)
# - state   = State supplemental context (Excel file)

# Check what data is available first
# print_available_data()

# Workflow 1: Process everything found (all files for all states and periods in ShareFile)
run_profile(source = "all")

# Workflow 2: Specific state + period + all files
# run_profile(state = "md", period = "2025_02", source = "all")

# Workflow 3: Specific state + period + specific file
# run_profile(state = "md", period = "2025_02", source = "national")

# Workflow 4: Specific state + all periods + all files
# run_profile(state = "ky", source = "all")

# Workflow 5: Specific period + all states + all files
# run_profile(period = "2025_02", source = "all")

# Workflow 6: Specific source only (for all states/periods that have it)
# run_profile(source = "rsp")

#####################################
# NOTES ----
#####################################

# Data Source Location:
# - ShareFile: S:/Shared Folders/{state}/cfsr/uploads/{period}/
# - PDFs: "{STATE} - Data Profile {YYYY_MM}.pdf"
# - Excel: "National - Supplemental Context Data.xlsx" and "{ST} - Supplemental Context Data.xlsx"

# Output Locations:
# - RDS files (for Shiny apps): cfsr/data/rds/
# - CSV archives: cfsr/data/csv/

# Available States (as of Jan 2026):
# - MD (Maryland)
# - KY (Kentucky)

# Available Periods:
# - 2024_02, 2024_08, 2025_02, 2025_08 (Maryland)
# - 2025_02, 2025_08 (Kentucky)
