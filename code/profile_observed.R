# Title:          CFSR Profile - Observed Performance Data
#                 Process observed performance data from state-specific CFSR Data Profile PDFs
#
# Purpose:        Extract observed performance metrics (denominator, numerator, observed%)
#                 from state-specific CFSR 4 Data Profile PDFs using pdftools
#
#####################################
# NOTES ----
#####################################
# This file is provided to every state about every 6 months (usually February
# & August). Page 4 shows observed performance trends (without risk adjustment).
# Observed performance shows raw state performance on CFSR indicators,
# complementing the risk-standardized performance (RSP) on page 2.
# INPUT: State-specific CFSR Data Profile PDF
# - Located in ShareFile: S:/Shared Folders/{state}/cfsr/uploads/{period}/
# - Filename pattern: "{STATE} - CFSR 4 Data Profile - {Month} {Year}.pdf"
# OUTPUT: Processed CSV with observed performance data by indicator and period
# - Columns: state, indicator, period, period_meaningful, denominator, numerator,
#            observed_performance, as_of_date, profile_version, source
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
# Load CFSR profile functions (shared functions)
source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_rsp.R")
########################################
# CONFIGURATION ----
########################################
# Establish current period and set up folders and global variables
# Uses CFSR-specific setup for multi-state support
my_setup <- setup_cfsr_folders(profile_period, state_code)
# Set file name elements for save_to_folder_run()
folder_date <- paste0(state_code, "_", profile_period)
commitment <- "cfsr profile"
commitment_description <- "observed"
########################################
# FIND AND READ PDF ----
########################################
# Find the state-specific CFSR Data Profile PDF
pdf_files <- list.files(
  folder_uploads,
  pattern = "\\.pdf$",
  full.names = TRUE,
  ignore.case = TRUE
)
if (length(pdf_files) == 0) {
  stop("No PDF files found in: ", folder_uploads)
}
# Use the first PDF found (should be the state profile)
pdf_path <- pdf_files[1]
message("Processing PDF: ", basename(pdf_path))
# Extract metadata from PDF filename
pdf_metadata <- extract_pdf_metadata(pdf_path)
########################################
# EXTRACT OBSERVED PERFORMANCE DATA FROM PDF ----
########################################
library(pdftools)
library(tidyverse)
library(stringr)
# Read PDF page 4 (contains observed performance tables)
raw_data_original <- pdf_data(pdf_path)[[4]]
# Pre-process: clean text
raw_data <- raw_data_original %>%
  mutate(text = str_replace_all(text, "[^[:graph:]]", "")) %>%
  filter(text != "")
# Show sample of data around expected table area
# Find period headers - search for text matching period patterns (e.g., "19B20A", "20A20B")
########################################
# HELPER FUNCTIONS FOR PDF EXTRACTION ----
########################################
# NOTE: extract_tableau_table() and extract_headers() are reused from profile_rsp.R
# These functions are defined in the script above (lines 101-362 of profile_rsp.R)
# They should ideally be moved to a shared functions file
extract_tableau_table <- function(data, y_min, y_max, x_cuts, y_tolerance = 5) {
  section_data <- data %>%
    filter(y >= y_min & y <= y_max) %>%
    mutate(y_group = round(y / y_tolerance) * y_tolerance) %>%
    mutate(col_id = findInterval(x, x_cuts))
  grid <- section_data %>%
    group_by(y_group, col_id) %>%
    summarise(cell_text = paste(text, collapse = " "), .groups = "drop") %>%
    pivot_wider(names_from = col_id, values_from = cell_text)
  grid
}
process_table_observed <- function(df, column_names) {
  # Similar to process_table() from RSP but adapted for observed performance structure
  # Row types: Denominator / Numerator / Observed performance (instead of RSP / RSP interval / Data used)
  max_index <- length(column_names) - 1
  for (i in 0:max_index) {
    col_str <- as.character(i)
    if (!col_str %in% names(df)) df[[col_str]] <- NA
  }
  data_cols <- as.character(0:max_index)
  df <- df %>%
    select(y_group, all_of(data_cols)) %>%
    set_names(c("y_pos", column_names))
  df_clean <- df %>%
    mutate(Indicator = ifelse(Indicator == "" | is.na(Indicator), NA, Indicator)) %>%
    # Filter to keep only rows with Measure_Type data
    # Measure_Type values contain: "Denomi" (Denominator), "Numer" (Numerator), "Obs" (Observed performance)
    filter(!is.na(Measure_Type)) %>%
    filter(str_detect(Measure_Type, "Denomi|Numer|Obs")) %>%
    # Remove header rows
    filter(!str_detect(Measure_Type, "^Measure")) %>%
    select(-y_pos, -Indicator) %>%
    # Classify Measure_Type based on partial text matches
    mutate(Measure_Type = case_when(
      str_detect(Measure_Type, "Denomi") ~ "Denominator",
      str_detect(Measure_Type, "Numer") ~ "Numerator",
      str_detect(Measure_Type, "Obs") ~ "Observed performance",
      TRUE ~ Measure_Type
    ))
  df_clean
}
extract_headers <- function(data, y_min, y_max, x_cuts, has_national_perf = TRUE) {
  headers_data <- data %>%
    filter(y >= y_min & y <= y_max) %>%
    mutate(col_id = findInterval(x, x_cuts))
  n_cols <- length(x_cuts)
  header_map <- headers_data %>%
    group_by(col_id) %>%
    summarise(text = paste(text, collapse = ""), .groups = "drop") %>%
    arrange(col_id)
  extracted_cols <- setNames(rep(NA_character_, n_cols + 1), 0:n_cols)
  extracted_cols[as.character(header_map$col_id)] <- header_map$text
  # Page 4 (observed) doesn't have National_Perf column
  if (has_national_perf) {
    extracted_cols["0"] <- "Indicator"
    extracted_cols["1"] <- "National_Perf"
    extracted_cols["2"] <- "Measure_Type"
  } else {
    extracted_cols["0"] <- "Indicator"
    extracted_cols["1"] <- "Measure_Type"
  }
  extracted_cols
}
# Convert period strings to meaningful labels for observed performance
# Observed performance uses standard AFCARS/NCANDS period formats
make_period_meaningful_observed <- function(period) {
  if (is.na(period) || period == "" || period == "NA") {
    return(NA_character_)
  }
  # Case 1: Format "YYAYYB" (e.g., "20A20B") => Oct 'prev_year - Sep 'year
  if (grepl("^[0-9]{2}A[0-9]{2}B$", period)) {
    year1 <- as.numeric(substr(period, 1, 2))
    year2 <- as.numeric(substr(period, 4, 5))
    start_year <- (year1 - 1) + 2000
    start_label <- paste0("Oct '", substr(as.character(start_year), 3, 4))
    end_label <- paste0("Sep '", substr(as.character(year2 + 2000), 3, 4))
    return(paste(start_label, "-", end_label))
  }
  # Case 2: Format "YYBYYA" (e.g., "19B20A") => Apr 'year - Mar 'next_year
  if (grepl("^[0-9]{2}B[0-9]{2}A$", period)) {
    year1 <- as.numeric(substr(period, 1, 2))
    year2 <- as.numeric(substr(period, 4, 5))
    start_label <- paste0("Apr '", substr(as.character(year1 + 2000), 3, 4))
    end_label <- paste0("Mar '", substr(as.character(year2 + 2000), 3, 4))
    return(paste(start_label, "-", end_label))
  }
  # Case 3: Fiscal year format "FYYY-YY" (e.g., "FY20-21") => FY20-21 (keep as-is)
  if (grepl("^FY[0-9]{2}-[0-9]{2}$", period)) {
    return(period)
  }
  # Fallback: return as-is if no pattern matches
  return(NA_character_)
}
# Vectorize the function
make_period_meaningful_observed <- Vectorize(make_period_meaningful_observed)
########################################
# EXTRACT TOP TABLE ----
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
########################################
# EXTRACT BOTTOM TABLE ----
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
# Manually define period headers (concatenating fragmented text)
bottom_cols <- c("Indicator", "Measure_Type", "20AB.FY20", "21AB.FY21", "22AB.FY22",
                  "FY20-21", "FY21-22", "FY22-23")
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
# RESHAPE WIDE TO LONG ----
########################################
reshape_observed_wide_to_long <- function(df) {
  # Get period columns (everything except Indicator, Measure_Type)
  # Note: Page 4 doesn't have National_Perf column
  period_cols <- names(df)[!names(df) %in%
    c("Indicator", "Measure_Type")]
  # Pivot to long format
  df_long <- df %>%
    pivot_longer(
      cols = all_of(period_cols),
      names_to = "period",
      values_to = "value"
    ) %>%
    # Convert period format to match RSP: "20AB.FY20" → "20AB_FY20"
    mutate(period = str_replace(period, "\\.", "_"))
  # Pivot wider to get Denominator, Numerator, Observed performance as separate columns
  # Do this BEFORE filtering so we don't lose rows where only one measure type has data
  df_wide <- df_long %>%
    pivot_wider(
      id_cols = c(Indicator, period),
      names_from = Measure_Type,
      values_from = value
    )
  # Rename columns to match target structure
  df_renamed <- df_wide %>%
    rename(
      indicator = Indicator,
      denominator = Denominator,
      numerator = Numerator,
      observed_performance = `Observed performance`
    )
  # Filter: Keep rows where at least one field has non-empty data
  # This preserves "DQ" rows (they have text) while dropping truly empty rows
  df_filtered <- df_renamed %>%
    filter(
      (!is.na(denominator) & str_trim(denominator) != "") |
      (!is.na(numerator) & str_trim(numerator) != "") |
      (!is.na(observed_performance) & str_trim(observed_performance) != "")
    )
  # Convert to numeric, handling special cases
  df_clean <- df_filtered %>%
    mutate(
      # Denominator: remove commas AND spaces, convert to numeric (DQ becomes NA)
      denominator = as.numeric(str_replace_all(str_replace_all(denominator, ",", ""), " ", "")),
      # Numerator: remove commas AND spaces, convert to numeric (DQ becomes NA)
      numerator = as.numeric(str_replace_all(str_replace_all(numerator, ",", ""), " ", "")),
      # Observed performance: handle percentages like "26. 0%" and decimals like "4. 60"
      # Remove spaces first, then handle % if present
      observed_performance = case_when(
        is.na(observed_performance) ~ NA_real_,
        str_detect(observed_performance, "%") ~
          as.numeric(str_replace_all(str_replace_all(observed_performance, " ", ""), "%", "")) / 100,
        TRUE ~ as.numeric(str_replace_all(observed_performance, " ", ""))
      )
    )
  # Return filtered data (DQ-flagged rows preserved, empty rows dropped)
  df_clean
}
# Reshape both tables
top_long <- reshape_observed_wide_to_long(final_top)
# Skip bottom table if empty (deferred for future implementation)
if (nrow(final_bottom) > 0) {
  bottom_long <- reshape_observed_wide_to_long(final_bottom)
} else {
  bottom_long <- data.frame()
}
########################################
# COMBINE AND ADD METADATA ----
########################################
# Combine top and bottom
observed_data <- bind_rows(top_long, bottom_long)
########################################
# JOIN DATA_USED FROM RSP ----
########################################
# Build path to RSP CSV file (should exist since RSP runs before observed)
rsp_file_pattern <- paste0(
  folder_date,
  " - cfsr profile - rsp - ",
  format(Sys.Date(), "%Y-%m-%d"),
  ".csv"
)
rsp_csv_path <- file.path(
  base_data_dir,
  "processed",
  state_code,
  profile_period,
  format(Sys.Date(), "%Y-%m-%d"),
  "rsp",
  rsp_file_pattern
)
########################################
# JOIN STATUS AND DATA_USED FROM RSP ----
########################################
# Load RSP RDS file to get pre-calculated status and data_used
# RDS is more reliable than CSV path construction
output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
rsp_rds_path <- file.path(output_dir_prod,
  paste0(toupper(state_code), "_cfsr_profile_rsp_", profile_period, ".rds"))
# Try to load RSP data
if (file.exists(rsp_rds_path)) {
  rsp_data <- readRDS(rsp_rds_path)
  message("Loading RSP data from: ", rsp_rds_path)
  message("RSP data has ", nrow(rsp_data), " rows")
  # Join on indicator and period to get status and data_used
  observed_data <- observed_data %>%
    left_join(
      rsp_data %>% select(indicator, period, status, data_used),
      by = c("indicator", "period")
    )
  # Report join results for transparency
  n_matched <- sum(!is.na(observed_data$status))
  n_unmatched <- sum(is.na(observed_data$status))
  message("  ✓ Joined status and data_used from RSP RDS")
  message("    Matched: ", n_matched, " rows")
  message("    Unmatched (status=NA): ", n_unmatched, " rows")
  # Show which indicator-period combinations have no RSP match
  # (Expected for some periods, e.g., FY periods in Maltreatment indicators)
  if (n_unmatched > 0) {
    unmatched_summary <- observed_data %>%
      filter(is.na(status)) %>%
      distinct(indicator, period) %>%
      arrange(indicator, period)
    message("    Unmatched indicator-period combinations:")
    print(unmatched_summary)
  }
} else {
  # Graceful fallback if RSP RDS not found
  observed_data$status <- NA_character_
  observed_data$data_used <- NA_character_
  warning("RSP RDS file not found: ", rsp_rds_path)
  warning("Status and data_used set to NA. Run profile_rsp.R first.")
}
# Get as_of_date from national file if available, otherwise use profile period
as_of_date <- tryCatch({
  # Try to extract from national file (requires profile_national.R to have run)
  # This function is defined in functions_cfsr_profile_rsp.R
  metadata <- cfsr_profile_extract_asof_date(
    find_cfsr_file("National", file_type = "excel", sheet_name = 1)
  )
  metadata$as_of_date
}, error = function(e) {
  # Fallback: derive from profile period
  # Profile period format: YYYY_MM
  year <- as.numeric(substr(profile_period, 1, 4))
  month <- as.numeric(substr(profile_period, 6, 7))
  as.Date(paste(year, month, "15", sep = "-"))
})
# Add metadata columns
observed_data <- observed_data %>%
  mutate(
    state = pdf_metadata$state,
    period_meaningful = make_period_meaningful_rsp(period),
    as_of_date = as_of_date,
    profile_version = pdf_metadata$profile_version,
    source = pdf_metadata$source
  ) %>%
  # Reorder columns to match target structure
  select(
    state,
    indicator,
    period,
    period_meaningful,
    denominator,
    numerator,
    observed_performance,
    status,        # Added: RSP status (better/worse/nodiff/dq)
    data_used,
    as_of_date,
    profile_version,
    source
  )
########################################
# SAVE PROCESSED DATA ----
########################################
# Create run folder in processed structure: data/processed/STATE/PERIOD/DATE/observed/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "observed")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
  message("Created run folder: ", folder_run)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)
# Save using save_to_folder_run pattern
save_to_folder_run(observed_data, "csv")
message("Processed ", nrow(observed_data), " rows for ", pdf_metadata$state)
message("Profile version: ", pdf_metadata$profile_version)
message("CSV saved to: ", folder_run)
########################################
# PREPARE RDS FOR SHINY APP ----
########################################
message("\n--- Preparing RDS for Shiny App ---")
# Load dictionary for metadata joins
dict_path <- "D:/repo_childmetrix/cfsr-profile/code/cfsr_round4_indicators_dictionary.csv"
if (!file.exists(dict_path)) {
  warning("Dictionary not found at: ", dict_path, " - skipping RDS preparation")
} else {
  dict <- read.csv(dict_path, stringsAsFactors = FALSE)
  message("Loaded dictionary with ", nrow(dict), " indicators")
  # Join dictionary metadata to observed data
  observed_app_data <- observed_data %>%
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
  missing_joins <- observed_app_data %>%
    filter(is.na(category)) %>%
    distinct(indicator)
  if (nrow(missing_joins) > 0) {
    warning("The following indicators did not match the dictionary:")
    print(missing_joins$indicator)
  }
  # --- Save RDS Files ---
  message("\n--- Saving RDS Files ---")
  # PROD: Period-specific file with state prefix (shared app location)
  output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
  if (!dir.exists(output_dir_prod)) {
    dir.create(output_dir_prod, recursive = TRUE)
  }
  output_file_prod_period <- file.path(output_dir_prod,
    paste0(toupper(state_code), "_cfsr_profile_observed_", profile_period, ".rds"))
  saveRDS(observed_app_data, output_file_prod_period)
  message("Saved to PROD: ", output_file_prod_period)
}
########################################
# SUMMARY ----
########################################
message("State: ", state_code)
message("Profile period: ", profile_period)
message("Total rows: ", nrow(observed_data))
message("Unique indicators: ", length(unique(observed_data$indicator)))
message("Profile version: ", pdf_metadata$profile_version)
message("\nData ready for Shiny app!")
message("  - Switch profiles via URL parameter: ?state=", tolower(state_code),
        "&profile=", profile_period)
