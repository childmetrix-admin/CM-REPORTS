#####################################
#####################################
# PROCESS CFSR DATA PROFILES
#####################################
#####################################

# Entry point for all CFSR profile processing workflows

# Instructions:

# 1. Set your parameters in the RUN section below
# 2. Click "Source" to run
# 3. Check console for results

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load the run_profile function
source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")

#####################################
# RUN ----
#####################################

# Uncomment ONE workflow below and modify as needed
# Source options: 
# - all = CFSR files found: pdf, national, and state
# - rsp = pg 2 of PDF
# - observed = pg 4 of PDF
# - national = National- Supplemental ... excel file
# - state = [ST] - Supplemental ... excel file

# Check what's available first
# print_available_data()

# Workflow 1: Process everything found (all files for all states and periods in S: drive)
run_profile(source = "all")

# Workflow 2: Specific state + period + all 3 files
# run_profile(state = "md", period = "2025_02", source = "all")

# Workflow 3: Specific state + period + specific file
# run_profile(state = "md", period = "2025_02", source = "national")

# Workflow 4: Specific state + all periods and all 3 files
# run_profile(state = "ky", source = "all")

# Workflow 5: Specific period + all 3 files
# run_profile(period = "2025_02", source = "all")

# Workflow 6: Specific source only
# run_profile(state = "md", period = "2025_02", source = "national")