#####################################
#####################################
# CFSR Profile - National Supplemental Context Data (excel) ----
#####################################
#####################################

# Extract and process national-level CFSR data from excel file 
# This file is identical for all states and shows data for all states

# Create csv (for FYI) and .rds file of data (for national shiny app) 
# (rds file cfsr_profile_national ...) doesn't have state prefix since it's 
# identical for all states. rds is limited to most recent period, csv has all periods.

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
# LIBRARIES & CONFIGURATION ----
#####################################

# IMPORTANT: This script expects the following globals to be set by run_profile.R:
#   - state_code, profile_period (set by setup_profile_env)
#   - folder_uploads, folder_processed, folder_app_data (set by initialize_common_globals)
#   - folder_date, commitment, my_setup (set by initialize_common_globals)
#   - NOTE: No pdf_path/pdf_metadata for national source (uses Excel files)

# Source national-specific functions
source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_nat.R")

# Set source-specific configuration
commitment_description <- "national"

########################################
# EXTRACT SHARED METADATA (ONCE) ----
########################################

# Extract metadata common to all indicators (profile version and as_of_date)
metadata <- extract_shared_metadata()

########################################
# PROCESS INDICATORS ----
########################################

# Entry Rate (special case - has years/census_year)
########################################

ind_entrate_df <- process_entry_rate_indicator(
  list(profile_version = metadata$profile_version,
       month = metadata$profile_month,
       year = metadata$profile_year,
       source = metadata$source),
  metadata$as_of_date
)

# Re-Entry
########################################

ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# Perm in 12 (entries)
########################################

ind_perm12_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (entries)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# Perm in 12 (12-23)
########################################

ind_perm1223_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (12-23 mos)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# Perm in 12 (24+ mos)
########################################

ind_perm24_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (24+ mos)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# Placement Stability
########################################

ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# Maltreatment in Care
########################################

ind_maltreatment_df <- process_standard_indicator(
  sheet_name = "Maltreatment in care",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# Recurrence of Maltreatment
########################################

ind_recurrence_df <- process_standard_indicator(
  sheet_name = "Recurrence of maltreatment",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date
)

# Append ind_data together and save
########################################

ind_data <- bind_rows(ind_entrate_df, ind_reentry_df, ind_perm12_df,
                      ind_perm1223_df, ind_perm24_df, ind_ps_df,
                      ind_maltreatment_df, ind_recurrence_df)

########################################
# SAVE CSV ----
########################################

# Create run folder in processed structure: data/processed/STATE/PERIOD/DATE/observed/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "national")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
  message("Created run folder: ", folder_run)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)

# Save using save_to_folder_run pattern
save_to_folder_run(ind_data, "csv")

message("\n=== National CSV processing complete ===")
message("Processed ", nrow(observed_data), " rows for ", pdf_metadata$state)
message("Profile version: ", pdf_metadata$profile_version)
message("CSV saved to: ", folder_run)

########################################
# SAVE RDS FOR SHINY APP ----
########################################

message("\n--- Saving RDS for Shiny App ---")

# Run prepare_app_data.R with the same profile_period
prepare_script <- "D:/repo_childmetrix/cfsr-profile/code/prepare_app_data.R"
if (file.exists(prepare_script)) {
  source(prepare_script)
  message("\n=== All done! ===")
  message("Data ready for Shiny app at profile period: ", profile_period)
} else {
  warning("Could not find prepare_app_data.R at: ", prepare_script)
}
