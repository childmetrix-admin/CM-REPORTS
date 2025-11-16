# Title:          CFSR Profile - State-Level Data
#                 Process state-level CFSR data from Excel files

# Purpose:        Extract and process state-level (county/regional) CFSR data
#                 from state-specific supplemental Excel files

#####################################
# NOTES ----
#####################################

# This script processes state-level CFSR data that breaks down indicators
# by county, region, or other geographic subdivisions within the state.

# This complements the national-level data (profile_national.R) and
# risk-standardized performance data (profile_rsp.R).

# INPUT: State-specific Excel files with county/regional breakdowns
# OUTPUT: Processed CSV with state-level data by indicator, period, and geography

# IMPORTANT: This script expects state_code and profile_period to be set
# by the orchestrator (run_profile.R) or manually before sourcing.

#####################################
# TO DO ----
#####################################

# [ ] Define input file structure and naming conventions
# [ ] Create extraction functions in code/functions/
# [ ] Determine output data structure
# [ ] Create Shiny app visualization strategy

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
if (!exists("state_code") || !exists("profile_period")) {
  message("WARNING: state_code and profile_period not set.")
  message("Either run via run_profile.R or set manually before sourcing.")
}

source("D:/repo_childmetrix/utilities-core/loader.R")

# Load CFSR profile functions (state-level data)
# TODO: Create functions_cfsr_profile_state.R in code/functions/
# source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_state.R")

########################################
# CONFIGURATION ----
########################################

# Establish current period and set up folders and global variables
# Uses CFSR-specific setup for multi-state support
my_setup <- setup_cfsr_folders(profile_period, state_code)

# Base data folder (from ShareFile)
base_data_dir <- file.path("S:/Shared Folders", state_code, "cfsr/uploads", profile_period)

# Set file name elements for save_to_folder_run()
folder_date <- paste0(state_code, "_", profile_period)
commitment <- "cfsr profile"
commitment_description <- "state"

########################################
# EXTRACT STATE-LEVEL DATA ----
########################################

# TODO: Implement state-level data extraction
# Expected workflow:
# 1. Scan base_data_dir for state-level Excel files
# 2. Extract geographic breakdowns (county/region)
# 3. Process indicators at sub-state level
# 4. Combine into standardized output format

message("\n=== State-level CFSR data processing ===")
message("This script is a template for future implementation.")
message("\nExpected input: ", base_data_dir)
message("Expected output: data/processed/", state_code, "/", profile_period, "/{date}/state/")

# Placeholder for future implementation
# state_data <- extract_state_level_data(base_data_dir)

########################################
# SAVE PROCESSED DATA ----
########################################

# TODO: Save to processed data folder
# Structure: data/processed/{state}/{period}/{date}/state/

# output_dir <- file.path(folder_processed, "state")
# if (!dir.exists(output_dir)) {
#   dir.create(output_dir, recursive = TRUE)
# }
#
# output_file <- file.path(output_dir,
#                          paste0(folder_date, " - ", commitment, " - ", commitment_description, ".csv"))
# write.csv(state_data, output_file, row.names = FALSE)
# message("\n✓ Saved to: ", output_file)

########################################
# AUTO-RUN PREPARE_APP_DATA (FUTURE) ----
########################################

# TODO: Create prepare_app_data_state.R to generate RDS files for Shiny app
# Will enable geographic visualizations (maps, regional comparisons)

# message("\n=== Data processing complete ===")
# message("Now preparing data for Shiny app...\n")
#
# prepare_script <- "D:/repo_childmetrix/cfsr-profile/shiny_app/prepare_app_data_state.R"
# if (file.exists(prepare_script)) {
#   source(prepare_script)
#   message("\n=== All done! ===")
#   message("Data ready for Shiny app at profile period: ", profile_period)
# } else {
#   warning("Could not find prepare_app_data_state.R at: ", prepare_script)
# }
