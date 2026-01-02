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
message("Processed ", nrow(ind_data), " rows")
message("Profile version: ", metadata$profile_version)
message("CSV saved to: ", folder_run)

########################################
# ADD METADATA AND JOIN DICTIONARY ----
########################################

# Load dictionary and join all metadata (for both display and calculations)
dict_path <- "D:/repo_childmetrix/cfsr-profile/code/cfsr_round4_indicators_dictionary.csv"
if (!file.exists(dict_path)) {
  stop("Dictionary not found at: ", dict_path)
}

dict <- read.csv(dict_path, stringsAsFactors = FALSE)
message("Loaded dictionary with ", nrow(dict), " indicators")

# Join ALL dictionary metadata
ind_data <- ind_data %>%
  left_join(
    dict %>% select(
      indicator,
      indicator_sort,
      indicator_short,
      indicator_very_short,
      category,
      description,
      denominator_def = denominator,
      numerator_def = numerator,
      national_standard,
      direction_rule,
      direction_desired,
      direction_legend,
      decimal_precision,
      scale,
      format,
      risk_adjustment,
      exclusions,
      notes
    ),
    by = "indicator"
  )

message("Joined dictionary metadata")

# Check for missing joins
missing_joins <- ind_data %>%
  filter(is.na(category)) %>%
  distinct(indicator)

if (nrow(missing_joins) > 0) {
  warning("The following indicators did not match the dictionary:")
  print(missing_joins[["indicator"]])
}

########################################
# PREPARE RDS FOR SHINY APP ----
########################################

# Filter to most recent period per indicator
# (App only needs latest data, CSV has all periods)
app_data <- ind_data %>%
  group_by(indicator) %>%
  filter(period == max(period, na.rm = TRUE)) %>%
  ungroup()

message("Filtered to latest period: ", nrow(app_data), " rows")

########################################
# SAVE RDS FOR SHINY APP ----
########################################

message("\n--- Saving RDS for Shiny App ---")

# PROD: Period-specific file WITHOUT state prefix (shared app location)
# National data is identical across states, so no state prefix needed
output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
if (!dir.exists(output_dir_prod)) {
  dir.create(output_dir_prod, recursive = TRUE)
}

output_file_prod_period <- file.path(output_dir_prod,
  paste0("cfsr_profile_national_", profile_period, ".rds"))
saveRDS(app_data, output_file_prod_period)
message("Saved to PROD: ", output_file_prod_period)

########################################
# SUMMARY ----
########################################

message("\n=== National Processing Complete ===")
message("State: ", state_code)
message("Profile period: ", profile_period)
message("Total rows (CSV): ", nrow(ind_data))
message("App rows (RDS): ", nrow(app_data))
message("Unique indicators: ", length(unique(ind_data$indicator)))
message("Profile version: ", metadata$profile_version)
message("\nData ready for Shiny app!")
message("  - Switch profiles via URL parameter: ?state=", tolower(state_code),
        "&profile=", profile_period)
