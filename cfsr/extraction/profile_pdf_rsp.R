#####################################
#####################################
# CFSR Profile - Risk-Standardized Performance (RSP) Data ----
#####################################
#####################################

# Process RSP performance (pg. 2) from state CFSR Data Profile PDF
# Create csv (for FYI) and .rds file of data (for RSP shiny app)

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

# OUTPUT: Processed CSV with RSP data by indicator and period
# - Columns: state, indicator, period, period_meaningful, rsp_lower, rsp,
#            rsp_upper, as_of_date, profile_version, source

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
  "../functions/functions_cfsr_profile_pdf_rsp.R"
))
# extract_tableau_table() and extract_headers() are in functions_cfsr_profile_shared.R

# Set source-specific configuration
commitment_description <- "rsp"

########################################
# EXTRACT RSP PERFORMANCE DATA FROM PDF ----
########################################

# Rough extraction
########################################

# Use pdftools to extract text & coordinates from page 2 of PDF
raw_data_original <- suppressMessages(pdf_data(pdf_path))[[2]]

# Remove invisible / non-printable characters (zero-width spaces, etc.),
# empty text elements
raw_data <- raw_data_original %>%
  mutate(text = str_replace_all(text, "[^[:graph:]]", "")) %>%
  filter(text != "")

# Extract and clean up top table (non-safety indicators) ----
########################################

top_x_cuts <- c(135, 165, 255, 300, 360, 420, 490, 570, 630, 690, 750)
top_cols_vec <- extract_headers(raw_data, y_min = 170, y_max = 190,
                                 x_cuts = top_x_cuts)
top_cols <- unname(top_cols_vec)

df_top_raw <- extract_tableau_table(raw_data,
  y_min = 190,
  y_max = 480,
  x_cuts = top_x_cuts
)

df_top_processed <- process_table_rsp(df_top_raw, top_cols) %>%
  fix_shadow_text() %>%
  fix_rsp_interval_bleed()

final_top <- df_top_processed %>%
  mutate(Indicator = rep(c(
    "Permanency in 12 months for children entering care",
    "Permanency in 12 months for children in care 12-23 months",
    "Permanency in 12 months for children in care 24 months or more",
    "Reentry to foster care within 12 months",
    "Placement stability (moves / 1,000 days in care)"
  ), each = 3)) %>%
  convert_percentages() %>%
  expand_rsp_intervals()

# Extract and clean up bottom table (safety indicators) ----
########################################

# Extract period headers from PDF (special function due to complex layout)
maltreatment_periods <- extract_maltreatment_periods_rsp(raw_data)

# Build column names from extracted periods
bottom_cols <- c("Indicator", "National_Perf", "Measure_Type",
                 maltreatment_periods$zone_a,
                 maltreatment_periods$zone_b)

# Zone A: Maltreatment in care
zone_a_cuts <- c(135, 165, 215, 285, 355, 425, 520, 610, 700)

df_zone_a <- extract_tableau_table(raw_data,
  y_min = 490,
  y_max = 565,
  x_cuts = zone_a_cuts,
  y_tolerance = 10
)

clean_a <- process_table_rsp(df_zone_a, bottom_cols) %>%
  fix_shadow_text() %>%
  repair_maltreatment_row()

# Zone B: Maltreatment recurrence
zone_b_cuts <- c(135, 165, 215, 285, 355, 425, 495, 570, 650)

df_zone_b <- extract_tableau_table(raw_data,
  y_min = 570,
  y_max = 615,
  x_cuts = zone_b_cuts,
  y_tolerance = 10
)

clean_b <- process_table_rsp(df_zone_b, bottom_cols) %>%
  fix_shadow_text()

fy_cols <- bottom_cols[7:9]

final_bottom <- bind_rows(clean_a, clean_b) %>%
  fix_recurrence_shift() %>%
  mutate(Indicator = rep(c(
    "Maltreatment in care (victimizations / 100,000 days in care)",
    "Maltreatment recurrence within 12 months"
  ), each = 3)) %>%
  convert_percentages() %>%
  mutate(across(
    all_of(fy_cols),
    ~ ifelse(Indicator == "Maltreatment in care (victimizations / 100,000 days in care)",
             NA, .)
  )) %>%
  # Create separate rsp lower and upper rows
  expand_rsp_intervals()

########################################
# RESHAPE WIDE TO LONG & COMBINE ----
########################################

# Reshape both tables
top_long <- reshape_rsp_wide_to_long(final_top)
bottom_long <- reshape_rsp_wide_to_long(final_bottom)

# Combine top and bottom
rsp_data <- bind_rows(top_long, bottom_long)

########################################
# ADD METADATA ----
########################################

# Get as_of_date from national file if available, otherwise use profile period
as_of_date <- tryCatch({
  metadata <- extract_shared_metadata()
  metadata$as_of_date
}, error = function(e) {
  # Fallback: derive from profile period (format: YYYY_MM)
  year <- as.numeric(substr(profile_period, 1, 4))
  month <- as.numeric(substr(profile_period, 6, 7))
  as.Date(paste(year, month, "15", sep = "-"))
})

# Add basic metadata columns
rsp_data <- rsp_data %>%
  mutate(
    state_abb = pdf_metadata$state,  # 2-letter code from PDF filename (MD, KY, etc.)
    state = convert_state_code_to_name(state_abb),  # Full name (Maryland, Kentucky, etc.)
    period_meaningful = make_period_meaningful(period),
    as_of_date = as_of_date,
    profile_version = pdf_metadata$profile_version,
    source = pdf_metadata$source
  )

# Load dictionary and join all metadata (for both status calculation and display)
dict_path <- file.path(
  dirname(sys.frame(1)$ofile),
  "cfsr_round4_indicators_dictionary.csv"
)
if (!file.exists(dict_path)) {
  stop("Dictionary not found at: ", dict_path)
}

dict <- read.csv(dict_path, stringsAsFactors = FALSE)

# Join ALL dictionary metadata
rsp_data <- rsp_data %>%
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
missing_joins <- rsp_data %>%
  filter(is.na(category)) %>%
  distinct(indicator)

if (nrow(missing_joins) > 0) {
  warning("The following indicators did not match the dictionary:")
  print(missing_joins[["indicator"]])
}

########################################
# CALCULATE RSP STATUS (above, below, no diff) ----
########################################

# Vectorize function to work with dplyr::mutate()
calculate_rsp_status <- Vectorize(calculate_rsp_status)

# Calculate RSP status for each row
rsp_data <- rsp_data %>%
  mutate(
    status = calculate_rsp_status(
      rsp_lower = rsp_lower,
      rsp_upper = rsp_upper,
      national_standard = national_standard,
      direction_rule = direction_rule,
      format_type = format
    )
  )

########################################
# VALIDATION ----
########################################

# Check for NA values in critical fields
validation_results <- list(
  period_na = sum(is.na(rsp_data[['period']])),
  period_meaningful_na = sum(is.na(rsp_data[['period_meaningful']])),
  status_na = sum(is.na(rsp_data[['status']])),
  data_used_na = sum(is.na(rsp_data[['data_used']]))
)

total_na <- sum(unlist(validation_results))

if (total_na > 0) {
  message("\n\u26A0  VALIDATION WARNINGS:")
  if (validation_results[['period_na']] > 0) {
    message("  - period: ", validation_results[['period_na']], " NA values")
  }
  if (validation_results[['period_meaningful_na']] > 0) {
    message("  - period_meaningful: ", validation_results[['period_meaningful_na']], " NA values")
  }
  if (validation_results[['status_na']] > 0) {
    message("  - status: ", validation_results[['status_na']], " NA values")
  }
  if (validation_results[['data_used_na']] > 0) {
    message("  - data_used: ", validation_results[['data_used_na']], " NA values")
  }
} else {
  message("\u2713 All critical fields populated (no NA values)")
}

# Save validation results for orchestrator
assign("validation_results", validation_results, envir = .GlobalEnv)

# Reorder columns for consistency across all outputs (CSV and RDS)
rsp_data <- rsp_data %>%
  select(
    # Key columns first
    state, state_abb, category, indicator, period, period_meaningful,
    rsp, rsp_lower, rsp_upper, national_standard, status, data_used,
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

# Create run folder in processed structure: data/processed/STATE/PERIOD/DATE/rsp/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "rsp")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)

# Save using save_to_folder_run pattern
save_to_folder_run(rsp_data, "csv")

########################################
# SAVE RDS FOR SHINY APP ----
########################################

# PROD: Period-specific file with state prefix (shared app location)
output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
if (!dir.exists(output_dir_prod)) {
  dir.create(output_dir_prod, recursive = TRUE)
}

output_file_prod_period <- file.path(output_dir_prod,
  paste0(toupper(state_code), "_cfsr_profile_rsp_", profile_period, ".rds"))
saveRDS(rsp_data, output_file_prod_period)
