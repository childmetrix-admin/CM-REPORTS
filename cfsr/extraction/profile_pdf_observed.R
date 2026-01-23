#####################################
#####################################
# CFSR Profile - Observed Performance Data ----
#####################################
#####################################

# Process observed performance (pg. 4) from state CFSR Data Profile PDF
# Create csv (for FYI) and .rds file of data (for observed shiny app)

#####################################
# NOTES ----
#####################################

# This PDF file is provided to every state about every 6 months (usually February
# & August). It shows the state's performance and trends on the CFSR
# statewide data indicators, both observed (pg 4) and risk-standardized (pg 2).
# Also shows data quality (DQ) checks the state failed.

# INPUT: State-specific CFSR Data Profile PDF
# - Located in ShareFile: S:/Shared Folders/{state}/cfsr/uploads/{period}/
# - Filename pattern: "{STATE} - CFSR 4 Data Profile - {Month} {Year}.pdf"

# OUTPUT: Processed CSV with observed performance data by indicator and period
# - Columns: state, indicator, period, period_meaningful, denominator, numerator,
#            observed_performance, as_of_date, profile_version, source

# IMPORTANT: This script expects state_code and profile_period to be set
# by the orchestrator (run_profile.R) or manually before sourcing.

#####################################
# LIBRARIES & CONFIGURATION ----
#####################################

# IMPORTANT: This script expects the following globals to be set by run_profile.R:
#   - state_code, profile_period (set by setup_profile_env)
#   - folder_uploads, folder_processed, folder_app_data (set by initialize_common_globals)
#   - folder_date, commitment, my_setup (set by initialize_common_globals)
#   - pdf_path, pdf_metadata (set by initialize_common_globals)

source(file.path(
  dirname(sys.frame(1)$ofile),
  "../functions/functions_cfsr_profile_pdf_observed.R"
))
# extract_tableau_table() and extract_headers() are in functions_cfsr_profile_shared.R

# Set source-specific configuration
commitment_description <- "observed"

########################################
# EXTRACT OBSERVED PERFORMANCE DATA FROM PDF ----
########################################

# Rough extraction
########################################

# Use pdftools to extract text & coordinates from page 4 of PDF
raw_data_original <- suppressMessages(pdf_data(pdf_path))[[4]]

# Remove invisible / non-printable characters (zero-width spaces, etc.),
# empty text elements
raw_data <- raw_data_original %>%
  mutate(text = str_replace_all(text, "[^[:graph:]]", "")) %>%
  filter(text != "")

# Extract and clean up top table (non-safety indicators) ----
########################################

# Page 4 x coordinates - different structure from page 2
# Page 4 has NO National_Perf column
# Column structure:
#   Column 0 (x < 135): Indicator name
#   Column 1 (x 135-250): Measure_Type (Denominator/Numerator/Observed performance)
#   Column 2+ (x 250+): Period data columns
# Adjusted x_cuts for page 4 based on actual PDF structure:
# Period headers found at y=178 with x coordinates:
#   20A20B: x=262, 20B21A: x=328, 21A21B: x=393, 21B22A: x=459
#   22A22B: x=526, 22B23A: x=591, 23A23B: x=657, 23B24A: x=723, 24A24B: x=789
# Data values start around x=280 (under first period header)
top_x_cuts <- c(135, 250, 310, 375, 440, 505, 570, 635, 700, 765)
# Extract headers from page 4 (no National_Perf column)
# Headers are at y=178 (found via pattern search for ##A##B format)
top_cols_vec <- extract_headers(raw_data, y_min = 175, y_max = 180,
                                x_cuts = top_x_cuts,
                                has_national_perf = FALSE)
top_cols <- unname(top_cols_vec)
# Extract table data
# Page 4 has tighter vertical spacing - adjust y_min and y_max
# Top table ends around y=380 (Placement Stability), bottom table starts around y=420
# NOTE: Placement stability has larger vertical span (y=357 to y=385), need balance between
# grouping Placement Stability rows together while not merging other indicators
df_top_raw <- extract_tableau_table(raw_data,
                                    y_min = 190,
                                    y_max = 400,  # Reduced to exclude bottom table rows
                                    x_cuts = top_x_cuts,
                                    y_tolerance = 10  # Balance: groups most rows correctly, Placement Stability may need special handling
)
df_top_processed <- process_table_observed(df_top_raw, top_cols)
# Check if we got the expected number of rows
if (nrow(df_top_processed) == 0) {
  stop("No data extracted from top table. Check coordinates and PDF structure.")
}
# Print first few rows for debugging
# Add full indicator names (5 indicators in top table)
# Only assign if we have the expected structure
if (nrow(df_top_processed) %% 3 == 0) {
  n_indicators <- nrow(df_top_processed) / 3
  final_top <- df_top_processed %>%
    mutate(Indicator = rep(c(
      "Permanency in 12 months for children entering care",
      "Permanency in 12 months for children in care 12-23 months",
      "Permanency in 12 months for children in care 24 months or more",
      "Reentry to foster care within 12 months",
      "Placement stability (moves / 1,000 days in care)"
    )[1:n_indicators], each = 3))
} else {
  stop("Top table has ", nrow(df_top_processed), " rows, which is not divisible by 3. ",
       "Expected 15 rows (5 indicators × 3 measure types). ",
       "Check PDF coordinates and extraction logic.")
}

# Extract and clean up bottom table (safety indicators) ----
########################################

# Bottom table period headers are at y=403 in a different format:
# - Maltreatment in care: "20AB, FY20", "21AB, FY21", "22AB, FY22"
# - Recurrence: "FY20- 21", "FY21- 22", "FY22- 23"
# Need to manually construct column headers since they're fragmented
# Define x_cuts for bottom table (6 periods: 3 for each indicator)
# Based on observed x-coordinates of period headers:
# - 20AB.FY20: x~265, 21AB.FY21: x~332, 22AB.FY22: x~399
# - FY20-21: x~475, FY21-22: x~542, FY22-23: x~610
# Split points between column centers

bottom_x_cuts <- c(135, 240, 298, 365, 437, 508, 576)
# Extract period headers from PDF (replaces hardcoded values)
observed_bottom_periods <- extract_maltreatment_periods_observed(raw_data)

# Build column names from extracted periods
bottom_cols <- c("Indicator", "Measure_Type",
                 observed_bottom_periods$zone_a,
                 observed_bottom_periods$zone_b)
# Extract bottom table data (y=410 to y=520)
df_bottom_raw <- extract_tableau_table(raw_data,
  y_min = 410,
  y_max = 520,
  x_cuts = bottom_x_cuts,
  y_tolerance = 10
)
# Process bottom table
df_bottom_processed <- process_table_observed(df_bottom_raw, bottom_cols)
# Add indicator names if we have the expected structure
if (nrow(df_bottom_processed) == 6) {
  final_bottom <- df_bottom_processed %>%
    mutate(Indicator = rep(c(
      "Maltreatment in care (victimizations / 100,000 days in care)",
      "Maltreatment recurrence within 12 months"
    ), each = 3))
} else {
  warning("Bottom table has ", nrow(df_bottom_processed), " rows, expected 6. Using as-is.")
  final_bottom <- df_bottom_processed
}

########################################
# RESHAPE WIDE TO LONG & COMBINE ----
########################################

# Reshape both tables
top_long <- reshape_observed_wide_to_long(final_top)
# Skip bottom table if empty (deferred for future implementation)
if (nrow(final_bottom) > 0) {
  bottom_long <- reshape_observed_wide_to_long(final_bottom)
} else {
  bottom_long <- data.frame()
}
# Combine top and bottom
observed_data <- bind_rows(top_long, bottom_long)

########################################
# ADD METADATA AND JOIN DICTIONARY ----
########################################

# Load RSP RDS file to get pre-calculated status and data_used
output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
rsp_rds_path <- file.path(output_dir_prod,
  paste0(toupper(state_code), "_cfsr_profile_rsp_", profile_period, ".rds"))

# Load RSP data
if (file.exists(rsp_rds_path)) {
  rsp_data <- readRDS(rsp_rds_path)

  # Join on indicator and period to get status and data_used
  observed_data <- observed_data %>%
    left_join(
      rsp_data %>% select(indicator, period, status, data_used),
      by = c("indicator", "period")
    )
} else {
  # Graceful fallback if RSP RDS not found
  observed_data$status <- NA_character_
  observed_data$data_used <- NA_character_
  warning("RSP RDS file not found: ", rsp_rds_path)
  warning("Status and data_used set to NA. Run profile_pdf_rsp.R first.")
}

# Get as_of_date from national file if available, otherwise use profile period
as_of_date <- tryCatch({
  # Try to extract from national file (requires profile_excel_national.R to have run)
  metadata <- cfsr_profile_extract_asof_date(
    find_cfsr_file("National", file_type = "excel", sheet_name = 1)
  )
  metadata$as_of_date
}, error = function(e) {
  # Fallback: derive from profile period (format: YYYY_MM)
  year <- as.numeric(substr(profile_period, 1, 4))
  month <- as.numeric(substr(profile_period, 6, 7))
  as.Date(paste(year, month, "15", sep = "-"))
})

# Add basic metadata columns
observed_data <- observed_data %>%
  mutate(
    state_abb = pdf_metadata$state,  # 2-letter code from PDF filename (MD, KY, etc.)
    state = convert_state_code_to_name(state_abb),  # Full name (Maryland, Kentucky, etc.)
    period_meaningful = make_period_meaningful(period),
    as_of_date = as_of_date,
    profile_version = pdf_metadata$profile_version,
    source = pdf_metadata$source
  )

# Load dictionary and join all metadata (for both display and calculations)
dict_path <- file.path(
  dirname(sys.frame(1)$ofile),
  "cfsr_round4_indicators_dictionary.csv"
)
if (!file.exists(dict_path)) {
  stop("Dictionary not found at: ", dict_path)
}

dict <- read.csv(dict_path, stringsAsFactors = FALSE)

# Join ALL dictionary metadata
observed_data <- observed_data %>%
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

# Check for missing joins
missing_joins <- observed_data %>%
  filter(is.na(category)) %>%
  distinct(indicator)

if (nrow(missing_joins) > 0) {
  warning("The following indicators did not match the dictionary:")
  print(missing_joins[["indicator"]])
}

########################################
# VALIDATION ----
########################################

# Check for NA values in critical fields
validation_results_obs <- list(
  period_na = sum(is.na(observed_data[['period']])),
  period_meaningful_na = sum(is.na(observed_data[['period_meaningful']])),
  status_na = sum(is.na(observed_data[['status']])),
  data_used_na = sum(is.na(observed_data[['data_used']]))
)

total_na_obs <- sum(unlist(validation_results_obs))

if (total_na_obs > 0) {
  message("\n\u26A0  VALIDATION WARNINGS:")
  if (validation_results_obs[['period_na']] > 0) {
    message("  - period: ", validation_results_obs[['period_na']], " NA values")
  }
  if (validation_results_obs[['period_meaningful_na']] > 0) {
    message("  - period_meaningful: ", validation_results_obs[['period_meaningful_na']], " NA values")
  }
  if (validation_results_obs[['status_na']] > 0) {
    message("  - status: ", validation_results_obs[['status_na']], " NA values (expected if RSP join failed)")
  }
  if (validation_results_obs[['data_used_na']] > 0) {
    message("  - data_used: ", validation_results_obs[['data_used_na']], " NA values (expected if RSP join failed)")
  }
} else {
  message("\u2713 All critical fields populated (no NA values)")
}

# Save validation results for orchestrator
assign("validation_results_obs", validation_results_obs, envir = .GlobalEnv)

########################################
# ADD RANK COLUMNS FROM NATIONAL DATA ----
########################################

# Load national data to add state_rank and reporting_states columns
output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
national_file <- file.path(output_dir_prod,
  paste0("cfsr_profile_national_", profile_period, ".rds"))

if (file.exists(national_file)) {
  national_data <- readRDS(national_file)

  # Join national data to add state_rank and reporting_states
  # Join on: indicator, period, state_abb
  observed_data <- observed_data %>%
    left_join(
      national_data %>%
        select(indicator, period, state_abb, state_rank, reporting_states),
      by = c("indicator", "period", "state_abb")
    )

} else {
  warning("National data file not found: ", national_file)
  warning("Continuing without rank columns. Run profile_excel_national.R first to add ranks.")
  # Add placeholder columns so column structure is consistent
  observed_data$state_rank <- NA_integer_
  observed_data$reporting_states <- NA_integer_
}

# Reorder columns for consistency across all outputs (CSV and RDS)
observed_data <- observed_data %>%
  select(
    # Key columns first
    state, state_abb, category, indicator, period, period_meaningful,
    denominator, numerator, observed_performance,
    national_standard, status,
    # Rank columns from national data (after status)
    state_rank, reporting_states,
    data_used,
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

# Create run folder in processed structure: data/processed/STATE/PERIOD/DATE/observed/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "observed")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)

# Save using save_to_folder_run pattern
save_to_folder_run(observed_data, "csv")

########################################
# SAVE RDS FOR SHINY APP ----
########################################

# PROD: Period-specific file with state prefix (shared app location)
# RDS is a snapshot of the CSV data (includes rank columns from earlier join)
output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
if (!dir.exists(output_dir_prod)) {
  dir.create(output_dir_prod, recursive = TRUE)
}

output_file_prod_period <- file.path(output_dir_prod,
  paste0(toupper(state_code), "_cfsr_profile_observed_", profile_period, ".rds"))
saveRDS(observed_data, output_file_prod_period)
