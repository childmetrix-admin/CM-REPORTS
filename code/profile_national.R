# Title:          CFSR Profile - National Data Processing
#                 Process National Supplemental Context Data

# Purpose:        Extract and process national-level CFSR data showing
#                 state-by-state performance on all indicators

#####################################
# NOTES ----
#####################################

# This script processes the National Supplemental Context Data file provided
# to states every 6 months (February & August). It shows state-by-state
# performance and trends on the CFSR statewide data indicators and entry rates.
# Also shows national performance by age, race/ethnicity.

# IMPORTANT: This script expects state_code and profile_period to be set
# by the orchestrator (run_profile.R) or manually before sourcing.

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
if (!exists("state_code") || !exists("profile_period")) {
  message("WARNING: state_code and profile_period not set.")
  message("Either run via run_profile.R or set manually before sourcing.")
}

source("D:/repo_childmetrix/utilities-core/loader.R")

# Load CFSR profile functions (national data)
source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_nat.R")

########################################
# CONFIGURATION ----
########################################

# Establish current period and set up folders and global variables
# Uses CFSR-specific setup for multi-state support
my_setup <- setup_cfsr_folders(profile_period, state_code)

# Set file name elements for save_to_folder_run()
folder_date <- paste0(state_code, "_", profile_period)
commitment <- "cfsr profile"
commitment_description <- "national"

########################################
# EXTRACT SHARED METADATA (ONCE) ----
########################################

# Extract metadata common to all indicators (profile version and as_of_date)
metadata <- extract_shared_metadata()

########################################
# PROCESS INDICATORS ----
########################################

# --------------------------------------
# Entry Rate (special case - has years/census_year)
# --------------------------------------

ind_entrate_df <- process_entry_rate_indicator(
  list(profile_version = metadata$profile_version,
       month = metadata$profile_month,
       year = metadata$profile_year,
       source = metadata$source),
  metadata$as_of_date
)

# --------------------------------------
# Re-Entry
# --------------------------------------

ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# --------------------------------------
# Perm in 12 (entries)
# --------------------------------------

ind_perm12_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (entries)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# --------------------------------------
# Perm in 12 (12-23)
# --------------------------------------

ind_perm1223_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (12-23 mos)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# --------------------------------------
# Perm in 12 (24+ mos)
# --------------------------------------

ind_perm24_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (24+ mos)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# --------------------------------------
# Placement Stability
# --------------------------------------

ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# --------------------------------------
# Maltreatment in Care
# --------------------------------------

ind_maltreatment_df <- process_standard_indicator(
  sheet_name = "Maltreatment in care",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# --------------------------------------
# Recurrence of Maltreatment
# --------------------------------------

ind_recurrence_df <- process_standard_indicator(
  sheet_name = "Recurrence of maltreatment",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# --------------------------------------
# Append ind_data together and save
# --------------------------------------

ind_data <- bind_rows(ind_entrate_df, ind_reentry_df, ind_perm12_df,
                      ind_perm1223_df, ind_perm24_df, ind_ps_df,
                      ind_maltreatment_df, ind_recurrence_df)

# Create run folder in new processed structure: data/processed/STATE/PERIOD/YYYY-MM-DD/national/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "national")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
  message("Created run folder: ", folder_run)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)

save_to_folder_run(ind_data, "csv")

########################################
# AUTO-RUN PREPARE_APP_DATA ----
########################################

message("\n=== Data processing complete ===")
message("Now preparing data for Shiny app...\n")

# Run prepare_app_data.R with the same profile_period
prepare_script <- "D:/repo_childmetrix/cfsr-profile/shiny_app/prepare_app_data.R"
if (file.exists(prepare_script)) {
  source(prepare_script)
  message("\n=== All done! ===")
  message("Data ready for Shiny app at profile period: ", profile_period)
} else {
  warning("Could not find prepare_app_data.R at: ", prepare_script)
}
