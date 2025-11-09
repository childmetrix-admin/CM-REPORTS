# Title:          Process data from
                  # National - Supplemental Context Date - [Month YYYY] .xlsx

# Purpose:        Joy

#####################################
# NOTES ----
#####################################

# This file is provided to every state about every 6 months (usually February
# & August). It show state-by-state performance and trends on the CFSR
# statewide data indicators and entry rates. Also shows national performance by
# age, race/ethnicity.

#####################################
# TODO ----
#####################################


#####################################
# OTHER DEPENDENCIES (e.g., files)
#####################################

# 1. Manually copy to raw folder:
# - National - Supplemental Context Date - [Month YYYY] .xlsx

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
source("D:/repo_childmetrix/r_utilities/loader.R")

# Load functions specific to this project
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"), chdir = FALSE)

########################################
# FOLDER PATHS & DIRECTORY STRUCTURE ----
########################################

# Base data folder
base_data_dir <- "D:/repo_childmetrix/cfsr-profile/data"

# File name elements (e.g., MD_2024_01 - [commitment] - [commitment_description] - 2024-02-15.csv")
# e.g., save_to_folder_run(claiming_df)
# Will be set after state_code and profile_period are defined
# commitment <- "cfsr profile"
# commitment_description <- "national"

# IMPORTANT: Set the state and profile period here
# state_code: 2-letter state code (e.g., "MD", "KY")
# profile_period: format "YYYY_MM" (e.g., "2025_02", "2025_08")
state_code <- "MD"
profile_period <- "2024_08"

# Establish current period and set up folders and global variables
# Uses new CFSR-specific setup for multi-state support
my_setup <- setup_cfsr_folders(profile_period, state_code)

# Set file name elements for save_to_folder_run()
# Include state code in filename for multi-state support
folder_date <- paste0(state_code, "_", profile_period)
commitment <- "cfsr profile"
commitment_description <- "national"

########################################
# EXTRACT SHARED METADATA (ONCE) ----
########################################

# Profile version and citation (same for all indicators)
ver <- cfsr_profile_version()

# AFCARS/NCANDS submission date (same for all indicators)
# Load any sheet to extract the as_of_date from header
data_df_temp <- find_cfsr_file(keyword = "National",
                               file_type = "excel",
                               sheet_name = "Entry rates")
asof <- cfsr_profile_extract_asof_date(data_df_temp)

########################################
# PROCESS INDICATORS ----
########################################

# --------------------------------------
# Entry Rate (special case - has years/census_year)
# --------------------------------------

ind_entrate_df <- process_entry_rate_indicator(ver, asof$as_of_date)

# --------------------------------------
# Re-Entry
# --------------------------------------

ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  ver = ver,
  as_of_date = asof$as_of_date
)

# --------------------------------------
# Perm in 12 (entries)
# --------------------------------------

ind_perm12_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (entries)",
  ver = ver,
  as_of_date = asof$as_of_date
)

# --------------------------------------
# Perm in 12 (12-23)
# --------------------------------------

ind_perm1223_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (12-23 mos)",
  ver = ver,
  as_of_date = asof$as_of_date
)

# --------------------------------------
# Perm in 12 (24+ mos)
# --------------------------------------

ind_perm24_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (24+ mos)",
  ver = ver,
  as_of_date = asof$as_of_date
)

# --------------------------------------
# Placement Stability
# --------------------------------------

ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  ver = ver,
  as_of_date = asof$as_of_date
)

# --------------------------------------
# Maltreatment in Care
# --------------------------------------

ind_maltreatment_df <- process_standard_indicator(
  sheet_name = "Maltreatment in care",
  ver = ver,
  as_of_date = asof$as_of_date
)

# --------------------------------------
# Recurrence of Maltreatment
# --------------------------------------

ind_recurrence_df <- process_standard_indicator(
  sheet_name = "Recurrence of maltreatment",
  ver = ver,
  as_of_date = asof$as_of_date
)

# --------------------------------------
# Append ind_data together and save
# --------------------------------------

ind_data <- bind_rows(ind_entrate_df, ind_reentry_df, ind_perm12_df,
                      ind_perm1223_df, ind_perm24_df, ind_ps_df,
                      ind_maltreatment_df, ind_recurrence_df)

# Create run folder in new processed structure: data/processed/STATE/PERIOD/YYYY-MM-DD/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"))
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
