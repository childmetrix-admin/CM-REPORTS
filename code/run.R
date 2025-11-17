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

# Uncomment ONE workflow below and modify as needed:

# Workflow 1: Specific state + period
run_profile(state = "md", period = "2025_02", source = "rsp")

# Workflow 2: All periods for a state
# run_profile(state = "md", source = "all")

# Workflow 3: All states for a period
# run_profile(period = "2025_02", source = "all")

# Workflow 4: ALL states and ALL periods (process everything found)
# run_profile(source = "national")

# Workflow 5: Specific source only
# run_profile(state = "md", period = "2025_02", source = "national")

# Check what's available first
# print_available_data()
