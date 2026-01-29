#####################################
#####################################
# CFSR Profile - State Supplemental Context Data (excel) ----
#####################################
#####################################

# Extract and process state-level CFSR data from excel file 
# Create csv (for FYI) and .rds file of data (for shiny app) 

#####################################
# NOTES ----
#####################################

# This script processes the [State] Supplemental Context Data file provided
# to states every 6 months (February & August). It shows the state's observed 
# performance by period, age, race, and locality. 

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
source(file.path(
  dirname(sys.frame(1)$ofile),
  "../functions/functions_cfsr_profile_excel.R"
))

# Set source-specific configuration
commitment_description <- "state"

########################################
# EXTRACT SHARED METADATA (ONCE) ----
########################################

# Extract metadata common to all indicators (profile version and as_of_date)
metadata <- extract_shared_metadata(
  state_code = state_code,
  jurisdiction_header = "Locality"
)

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
  metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Re-Entry
########################################

ind_reentry_df <- process_standard_indicator(
  sheet_name = "Reentry to FC",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Perm in 12 (entries)
########################################

ind_perm12_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (entries)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Perm in 12 (12-23)
########################################

ind_perm1223_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (12-23 mos)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Perm in 12 (24+ mos)
########################################

ind_perm24_df <- process_standard_indicator(
  sheet_name = "Perm in 12 (24+ mos)",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Placement Stability
########################################

ind_ps_df <- process_standard_indicator(
  sheet_name = "Placement stability",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Maltreatment in Care
########################################

ind_maltreatment_df <- process_standard_indicator(
  sheet_name = "Maltreatment in care",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Recurrence of Maltreatment
########################################

ind_recurrence_df <- process_standard_indicator(
  sheet_name = "Recurrence of maltreatment",
  ver = list(profile_version = metadata$profile_version,
             month = metadata$profile_month,
             year = metadata$profile_year,
             source = metadata$source),
  as_of_date = metadata$as_of_date,
  jurisdiction_header = "Locality",
  state_code = state_code
)

# Append ind_data together and save
########################################

ind_data <- bind_rows(ind_entrate_df, ind_reentry_df, ind_perm12_df,
                      ind_perm1223_df, ind_perm24_df, ind_ps_df,
                      ind_maltreatment_df, ind_recurrence_df)

########################################
# ADD METADATA AND JOIN DICTIONARY ----
########################################

# Load dictionary and join all metadata (for both display and calculations)
# Join dictionary metadata using shared function
ind_data <- join_indicator_dictionary(ind_data)

# Standardize dimension values (race/ethnicity recoding)
ind_data <- standardize_dimension_values(ind_data)

########################################
# ADD RANK COLUMNS FROM NATIONAL DATA ----
########################################

# Load national data to add state_rank and reporting_states columns
# Use new hierarchical structure: domains/cfsr/data/rds/national/
national_file <- build_rds_path(state_code = NULL, profile_period, "national")

if (file.exists(national_file)) {
  national_data <- readRDS(national_file)

  # Join national data to add state_rank and reporting_states
  # Join on: indicator, period, state_abb
  # Note: Drop existing NA columns first to avoid .x/.y suffix conflicts
  ind_data <- ind_data %>%
    mutate(state_abb = convert_state_name_to_code(state)) %>%
    select(-state_rank, -reporting_states) %>%
    left_join(
      national_data %>%
        select(indicator, period, state_abb, state_rank, reporting_states),
      by = c("indicator", "period", "state_abb")
    )

} else {
  warning("National data file not found: ", national_file)
  warning("Continuing without rank columns. Run profile_excel_national.R first to add ranks.")
  # Add state_abb and placeholder rank columns so column structure is consistent
  ind_data <- ind_data %>%
    mutate(
      state_abb = convert_state_name_to_code(state),
      state_rank = NA_integer_,
      reporting_states = NA_integer_
    )
}

########################################
# ADD STATUS COLUMN FROM RSP DATA ----
########################################

# Load RSP data to add status column (indicates "dq" for data quality issues)
# This allows charts to show appropriate message when performance can't be calculated
rsp_file <- build_rds_path(state_code, profile_period, "rsp")

if (file.exists(rsp_file)) {
  rsp_data <- readRDS(rsp_file)

  # Join RSP data to add status column
  # Join on: indicator, period
  # Note: Drop existing status column first to avoid .x/.y suffix conflicts
  ind_data <- ind_data %>%
    select(-any_of("status")) %>%
    left_join(
      rsp_data %>%
        select(indicator, period, status) %>%
        distinct(),
      by = c("indicator", "period")
    )

} else {
  warning("RSP data file not found: ", rsp_file)
  warning("Continuing without status column. Charts won't show DQ messages.")
  # Add placeholder status column so column structure is consistent
  ind_data <- ind_data %>%
    mutate(status = NA_character_)
}

# Reorder columns for consistency across all outputs
ind_data <- ind_data %>%
  select(
    # Key columns first
    state, state_abb, category, indicator, dimension, dimension_value,
    period, period_meaningful,
    denominator, numerator, performance, state_rank, reporting_states, status,
    # Add census_year if it exists (only for entry rate indicator)
    any_of("census_year"),
    national_standard,
    as_of_date, profile_version, source,
    # Dictionary metadata columns
    indicator_sort, indicator_short, indicator_very_short,
    description, denominator_def, numerator_def,
    direction_rule, direction_desired, direction_legend,
    decimal_precision, scale, format,
    risk_adjustment, exclusions, notes
  )

########################################
# SAVE CSV ----
########################################

# Create run folder in processed structure: data/processed/STATE/PERIOD/DATE/state/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "state")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)

# Save using save_to_folder_run pattern
save_to_folder_run(ind_data, "csv")

########################################
# SAVE RDS FOR SHINY APP ----
########################################

# Use new hierarchical structure: cfsr/data/rds/{state}/{period}/
# RDS is a snapshot of the CSV data (includes rank columns from earlier join)
output_file_prod_period <- build_rds_path(state_code, profile_period, "state")
saveRDS(ind_data, output_file_prod_period)
