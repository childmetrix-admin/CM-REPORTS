# Quick runner script for CFSR profile processing
#
# Instructions:
# 1. Set your parameters in the RUN section below
# 2. Click "Source" to run
# 3. Check console for results

#####################################
# LOAD ORCHESTRATOR ----
#####################################
# (This loads the run_profile function)

source("D:/repo_childmetrix/cfsr-profile/code/run_profile.R")

#####################################
# RUN ----
#####################################

# Uncomment ONE workflow below and modify as needed
# Source options:
# - rsp
# - national
# - state

# Workflow 1: Specific state + period + all 3 files
run_profile(state = "md", period = "2025_02", source = "observed")

# Workflow 2: Specific state + period + specific file
# run_profile(state = "md", period = "2025_02", source = "national")

# Workflow 3: Specific state + all periods and all 3 files
# run_profile(state = "ky", source = "all")

# Workflow 4: Specific period + all 3 files
# run_profile(period = "2025_02", source = "all")

# Workflow 5: ALL states and ALL periods (process everything found)
# run_profile(source = "all")

# Workflow 6: Specific source only
# run_profile(state = "md", period = "2025_02", source = "national")

# Check what's available first
# print_available_data()
