# Title:          CFSR Profile - Risk-Standardized Performance (RSP) Data
#                 Process RSP data from state-specific CFSR Data Profile PDFs

# Purpose:        Extract Risk-Standardized Performance metrics from
#                 state-specific CFSR 4 Data Profile PDFs using pdftools

#####################################
# NOTES ----
#####################################

# This file is provided to every state about every 6 months (usually February
# & August). It shows the state's performance and trends on the CFSR
# statewide data indicators, both observed and risk-standardized.
# Also shows data quality (DQ) checks the state failed.

# The RSP (Risk-Standardized Performance) metrics adjust for state-specific
# risk factors and provide fairer state-to-state comparisons.

# INPUT: State-specific CFSR Data Profile PDF
# - Located in ShareFile: S:/Shared Folders/{state}/cfsr/uploads/{period}/
# - Filename pattern: "{STATE} - CFSR 4 Data Profile - {Month} {Year}.pdf"

# OUTPUT: Processed CSV with RSP data by indicator and period
# - Columns: state, indicator, period, period_meaningful, rsp_lower, rsp,
#            rsp_upper, as_of_date, profile_version, source

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

# Load CFSR profile functions (RSP-specific)
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
commitment_description <- "rsp"

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
# EXTRACT RSP DATA FROM PDF ----
########################################

library(pdftools)
library(tidyverse)
library(stringr)

# Read PDF page 2 (contains RSP tables)
raw_data_original <- suppressMessages(pdf_data(pdf_path))[[2]]

# Pre-process: clean text
raw_data <- raw_data_original %>%
  mutate(text = str_replace_all(text, "[^[:graph:]]", "")) %>%
  filter(text != "")

########################################
# MALTREATMENT PERIOD EXTRACTION ----
########################################

#' Extract maltreatment period headers from PDF page 2
#'
#' Reads actual period values from the PDF instead of deriving them mathematically.
#' Handles text fragmentation by concatenating fragments within column boundaries.
#'
#' @param raw_data Cleaned PDF text data from page 2
#' @return Named list with zone_a and zone_b period vectors (length 3 each)
extract_maltreatment_periods <- function(raw_data) {
  # Extract period header row (y=484, with ±2 tolerance)
  period_text <- raw_data %>%
    filter(y >= 482 & y <= 486) %>%
    filter(x < 700) %>%  # Exclude footnote area on right
    arrange(x)

  # Define column boundaries based on observed x-coordinates in PDF
  # Zone A: Maltreatment in care (##AB_FY##)
  zone_a_bounds <- list(
    col1 = c(230, 290),  # 20AB_FY20 at x~244-267
    col2 = c(300, 370),  # 21AB_FY21 at x~315-338
    col3 = c(375, 420)   # 22AB_FY22 at x~386-409 (reduced from 440 to avoid footnotes)
  )

  # Zone B: Recurrence (FY##-##)
  zone_b_bounds <- list(
    col1 = c(450, 515),  # FY20-21 at x~467-489
    col2 = c(525, 590),  # FY21-22 at x~538-560
    col3 = c(595, 640)   # FY22-23 at x~608-631 (reduced from 660 to avoid footnotes)
  )

  # Extract Zone A periods
  zone_a_periods <- sapply(zone_a_bounds, function(bounds) {
    col_text <- period_text %>%
      filter(x >= bounds[1] & x <= bounds[2]) %>%
      pull(text) %>%
      paste(collapse = "")

    # Clean: remove spaces, commas, ensure underscore separator
    cleaned <- col_text %>%
      str_remove_all("\\s|,") %>%
      str_replace("([0-9]{2}AB)(FY)", "\\1_\\2")

    cleaned
  })

  # Extract Zone B periods
  zone_b_periods <- sapply(zone_b_bounds, function(bounds) {
    col_text <- period_text %>%
      filter(x >= bounds[1] & x <= bounds[2]) %>%
      pull(text) %>%
      paste(collapse = "")

    # Clean: remove spaces, normalize hyphen
    cleaned <- col_text %>%
      str_remove_all("\\s") %>%
      str_replace("FY([0-9]{2})-?([0-9]{2})", "FY\\1-\\2")

    cleaned
  })

  list(
    zone_a = unname(zone_a_periods),
    zone_b = unname(zone_b_periods)
  )
}

########################################
# STATUS CALCULATION FUNCTION ----
########################################

#' Calculate RSP performance status based on confidence interval overlap
#'
#' @param rsp_lower RSP lower CI bound (decimal for percent, e.g., 0.26 = 26%)
#' @param rsp_upper RSP upper CI bound (same scale as rsp_lower)
#' @param national_standard National standard (display value, e.g., 35.2 = 35.2%)
#' @param direction_rule "lt" (lower is better) or "gt" (higher is better)
#' @param format_type "percent" or "rate"
#' @return Character: "better", "worse", "nodiff", or "dq"
calculate_rsp_status <- function(rsp_lower, rsp_upper, national_standard, direction_rule, format_type) {
  # Handle missing data
  if (is.na(rsp_lower) || is.na(rsp_upper) || is.na(national_standard)) {
    return("dq")
  }

  # Convert RSP bounds to display scale for comparison
  # RSP for percent indicators stored as decimal (0.26 = 26%)
  # National standard stored as display value (35.2 = 35.2%)
  if (format_type == "percent") {
    lower_display <- rsp_lower * 100
    upper_display <- rsp_upper * 100
  } else {
    lower_display <- rsp_lower
    upper_display <- rsp_upper
  }

  # Check if interval overlaps national standard
  overlaps <- lower_display <= national_standard && upper_display >= national_standard

  if (overlaps) {
    return("nodiff")
  }

  # Determine better/worse based on direction
  if (direction_rule == "lt") {
    # Lower is better (safety indicators)
    if (upper_display < national_standard) {
      return("better")
    } else {
      return("worse")
    }
  } else {
    # Higher is better (permanency indicators)
    if (lower_display > national_standard) {
      return("better")
    } else {
      return("worse")
    }
  }
}

# Vectorize for use with dplyr::mutate()
calculate_rsp_status <- Vectorize(calculate_rsp_status)

########################################
# HELPER FUNCTIONS FOR PDF EXTRACTION ----
########################################

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

process_table <- function(df, column_names) {
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
    fill(Indicator, .direction = "down") %>%
    mutate(Indicator = ifelse(is.na(Indicator) & !is.na(lead(Indicator)),
      lead(Indicator),
      Indicator
    )) %>%
    filter(!str_detect(Indicator, "Performance|Data used|^Indicator$")) %>%
    filter(!is.na(Measure_Type)) %>%
    select(-y_pos)

  df_clean
}

fix_shadow_text <- function(df) {
  df %>%
    mutate(across(everything(), function(x) {
      x <- as.character(x)
      x <- str_replace_all(x, "D D Q Q", "DQ")
      x <- str_replace_all(x, "2 2 A - 2 3 B 2 2 A - 2 3 B", "22A-23B")
      x <- str_replace_all(x, "2 2 A - 2 3 B", "22A-23B")
      x <- str_replace_all(x, "F Y", "FY")
      x <- str_replace_all(x, "nt er v al RSP i", "RSP interval")
      x <- str_replace_all(x, "RSP i nt er v al", "RSP interval")
      x <- str_replace_all(x, "Dat a us ed", "Data used")
      x <- str_replace_all(x, "[^ -~]", "")
      x <- str_replace_all(x, "\\.\\s+(\\d)", ".\\1")
      x <- str_replace_all(x, "^16\\s+(?=12)", "")
      x <- str_replace_all(x, "^22\\s+(?=22A)", "")
      x <- str_replace_all(x, "(\\d+[AB]?)\\s*-\\s*(\\d+[AB]?)", "\\1-\\2")
      x
    }))
}

repair_maltreatment_row <- function(df) {
  col_names <- names(df)
  col_4 <- col_names[4]
  col_5 <- col_names[5]

  df %>%
    mutate(
      clean_ind = str_replace_all(replace_na(Indicator, ""), "\\s+", ""),
      is_mal_rsp = str_detect(clean_ind, "Maltreatmentincare") &
        Measure_Type == "RSP"
    ) %>%
    mutate(is_mal_rsp = replace_na(is_mal_rsp, FALSE)) %>%
    rowwise() %>%
    mutate(
      col_5_starts_decimal = is_mal_rsp & !is.na(.data[[col_5]]) &
        str_detect(.data[[col_5]], "^\\s*\\."),
      combined_text = ifelse(col_5_starts_decimal,
        paste(replace_na(.data[[col_4]], ""), replace_na(.data[[col_5]], "")),
        ""),
      healed_value = str_replace_all(combined_text,
        "(\\d)\\s*\\.\\s*(\\d)", "\\1.\\2"),
      extracted_num = ifelse(col_5_starts_decimal,
        str_extract(healed_value, "\\d+\\.\\d+"),
        NA_character_)
    ) %>%
    ungroup() %>%
    mutate(
      !!col_4 := ifelse(!is.na(extracted_num), extracted_num, .data[[col_4]]),
      !!col_5 := ifelse(!is.na(extracted_num), NA_character_, .data[[col_5]])
    ) %>%
    select(-clean_ind, -is_mal_rsp, -col_5_starts_decimal,
           -combined_text, -healed_value, -extracted_num)
}

fix_rsp_interval_bleed <- function(df) {
  # Fix cases where RSP interval value bleeds into Measure_Type column
  # Example: Measure_Type = "RSP interval 43.3%-" instead of just "RSP interval"
  col_names <- names(df)
  first_period_col <- col_names[4]  # First period column (columns: Indicator, National_Perf, Measure_Type, [first_period])

  df %>%
    mutate(
      # Detect if Measure_Type starts with "RSP interval" but has extra content
      has_bleed = str_detect(Measure_Type, "^RSP interval\\s+\\d"),
      # Extract the extra content (interval lower value)
      bleed_value = ifelse(has_bleed,
                           str_extract(Measure_Type, "\\d+\\.?\\d*%?-?\\s*$"),
                           NA_character_),
      # Combine bleed value with first period column content
      !!first_period_col := ifelse(has_bleed & !is.na(bleed_value),
                                    paste0(bleed_value, .data[[first_period_col]]),
                                    .data[[first_period_col]]),
      # Clean Measure_Type to just "RSP interval"
      Measure_Type = ifelse(has_bleed, "RSP interval", Measure_Type)
    ) %>%
    select(-has_bleed, -bleed_value)
}

fix_recurrence_shift <- function(df) {
  col_names <- names(df)
  col_6 <- col_names[6]
  col_7 <- col_names[7]
  col_8 <- col_names[8]
  col_9 <- col_names[9]

  df %>%
    mutate(
      clean_ind = str_replace_all(replace_na(Indicator, ""), "\\s+", ""),
      is_recurrence = str_detect(clean_ind, "recurrence|Maltreatmentrecurrence"),
      is_recurrence_rsp = Measure_Type == "RSP" & is_recurrence,
      is_rec_interval = Measure_Type == "RSP interval" & is_recurrence,
      is_rec_data = Measure_Type == "Data used" & is_recurrence
    ) %>%
    rowwise() %>%
    mutate(
      needs_shift = is_recurrence_rsp & is.na(.data[[col_7]]) &
        !is.na(.data[[col_8]]),
      !!col_9 := ifelse(needs_shift, .data[[col_8]], .data[[col_9]]),
      !!col_8 := ifelse(needs_shift, .data[[col_7]], .data[[col_8]]),
      !!col_7 := ifelse(needs_shift, .data[[col_6]], .data[[col_7]]),
      !!col_6 := ifelse(needs_shift, NA_character_, .data[[col_6]]),
      extracted_intervals = list(
        str_extract_all(.data[[col_7]], "\\d+\\.\\d+%\\s*-\\s*\\d+\\.\\d+%")[[1]]
      ),
      !!col_9 := ifelse(is_rec_interval, .data[[col_8]], .data[[col_9]]),
      !!col_7 := ifelse(is_rec_interval & length(extracted_intervals) >= 1,
        extracted_intervals[1], .data[[col_7]]),
      !!col_8 := ifelse(is_rec_interval & length(extracted_intervals) >= 2,
        extracted_intervals[2], .data[[col_8]]),
      !!col_7 := ifelse(is_rec_data, col_7, .data[[col_7]]),
      !!col_8 := ifelse(is_rec_data, col_8, .data[[col_8]]),
      !!col_9 := ifelse(is_rec_data, col_9, .data[[col_9]]),
      !!col_6 := ifelse(is_rec_data, NA_character_, .data[[col_6]])
    ) %>%
    select(-clean_ind, -is_recurrence, -is_recurrence_rsp, -is_rec_interval,
           -is_rec_data, -needs_shift, -extracted_intervals) %>%
    ungroup()
}

convert_percentages <- function(df) {
  pct_indicators <- c(
    "Permanency in 12 months for children entering care",
    "Permanency in 12 months for children in care 12-23 months",
    "Permanency in 12 months for children in care 24 months or more",
    "Reentry to foster care within 12 months",
    "Maltreatment recurrence within 12 months"
  )

  df %>%
    mutate(across(
      -c(Indicator, Measure_Type),
      ~ {
        x <- .
        is_target_row <- Indicator %in% pct_indicators
        is_rsp <- Measure_Type == "RSP"
        has_pct <- str_detect(x, "%")
        to_convert <- !is.na(x) & is_target_row & is_rsp & has_pct

        if (any(to_convert)) {
          cleaned <- str_extract(x[to_convert], "(\\d+\\.?\\d*)(?=\\s*%)")
          numeric_val <- suppressWarnings(as.numeric(cleaned))
          valid_nums <- !is.na(numeric_val)
          x[to_convert][valid_nums] <- as.character(numeric_val[valid_nums] / 100)
        }
        x
      }
    ))
}

expand_rsp_intervals <- function(df) {
  pct_indicators <- c(
    "Permanency in 12 months for children entering care",
    "Permanency in 12 months for children in care 12-23 months",
    "Permanency in 12 months for children in care 24 months or more",
    "Reentry to foster care within 12 months",
    "Maltreatment recurrence within 12 months"
  )

  non_interval <- df %>% filter(Measure_Type != "RSP interval")
  interval_rows <- df %>% filter(Measure_Type == "RSP interval")

  lower_rows <- interval_rows %>%
    mutate(Measure_Type = "RSP Lower") %>%
    mutate(across(-c(Indicator, Measure_Type, National_Perf), ~ {
      x <- .
      extracted <- str_match(x, "(\\d+\\.?\\d*%?)\\s*-")[, 2]
      is_pct_ind <- Indicator %in% pct_indicators
      clean_num <- str_remove(extracted, "%")
      numeric_val <- suppressWarnings(as.numeric(clean_num))
      final_val <- ifelse(is_pct_ind & !is.na(numeric_val),
        numeric_val / 100, numeric_val)
      as.character(final_val)
    }))

  upper_rows <- interval_rows %>%
    mutate(Measure_Type = "RSP Upper") %>%
    mutate(across(-c(Indicator, Measure_Type, National_Perf), ~ {
      x <- .
      extracted <- str_match(x, "-\\s*(\\d+\\.?\\d*%?)")[, 2]
      is_pct_ind <- Indicator %in% pct_indicators
      clean_num <- str_remove(extracted, "%")
      numeric_val <- suppressWarnings(as.numeric(clean_num))
      final_val <- ifelse(is_pct_ind & !is.na(numeric_val),
        numeric_val / 100, numeric_val)
      as.character(final_val)
    }))

  bind_rows(non_interval, lower_rows, upper_rows) %>%
    mutate(
      National_Perf = {
        clean_val <- str_trim(str_remove(National_Perf, "%"))
        numeric_val <- suppressWarnings(as.numeric(clean_val))
        is_pct_ind <- Indicator %in% pct_indicators
        final_val <- ifelse(is_pct_ind & !is.na(numeric_val),
          numeric_val / 100, numeric_val)
        as.character(final_val)
      }
    ) %>%
    arrange(Indicator, Measure_Type)
}

extract_headers <- function(data, y_min, y_max, x_cuts) {
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

  extracted_cols["0"] <- "Indicator"
  extracted_cols["1"] <- "National_Perf"
  extracted_cols["2"] <- "Measure_Type"

  extracted_cols
}

########################################
# EXTRACT TOP TABLE ----
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

df_top_processed <- process_table(df_top_raw, top_cols) %>%
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

########################################
# EXTRACT BOTTOM TABLE ----
########################################

# Extract period headers from PDF (replaces mathematical derivation)
maltreatment_periods <- extract_maltreatment_periods(raw_data)

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

clean_a <- process_table(df_zone_a, bottom_cols) %>%
  fix_shadow_text() %>%
  repair_maltreatment_row()

# Data_used values are already extracted from PDF (no mathematical derivation needed)

# Zone B: Maltreatment recurrence
zone_b_cuts <- c(135, 165, 215, 285, 355, 425, 495, 570, 650)

df_zone_b <- extract_tableau_table(raw_data,
  y_min = 570,
  y_max = 615,
  x_cuts = zone_b_cuts,
  y_tolerance = 10
)

clean_b <- process_table(df_zone_b, bottom_cols) %>%
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
  expand_rsp_intervals()

########################################
# RESHAPE WIDE TO LONG ----
########################################

reshape_rsp_wide_to_long <- function(df) {
  # Get period columns (everything except Indicator, National_Perf, Measure_Type)
  period_cols <- names(df)[!names(df) %in%
    c("Indicator", "National_Perf", "Measure_Type")]

  # Pivot to long format
  df_long <- df %>%
    pivot_longer(
      cols = all_of(period_cols),
      names_to = "period",
      values_to = "value"
    ) %>%
    filter(!is.na(value) & value != "")

  # Pivot wider to get RSP, RSP Lower, RSP Upper, Data used as separate columns
  df_wide <- df_long %>%
    pivot_wider(
      id_cols = c(Indicator, period),
      names_from = Measure_Type,
      values_from = value
    )

  # Handle case where Data used column might not exist
  if (!"Data used" %in% names(df_wide)) {
    df_wide$`Data used` <- NA_character_
  }

  # Rename columns to match target structure
  df_wide %>%
    rename(
      indicator = Indicator,
      rsp = RSP,
      rsp_lower = `RSP Lower`,
      rsp_upper = `RSP Upper`,
      data_used = `Data used`
    ) %>%
    mutate(
      rsp = as.numeric(rsp),
      rsp_lower = as.numeric(rsp_lower),
      rsp_upper = as.numeric(rsp_upper)
    )
}

# Reshape both tables
top_long <- reshape_rsp_wide_to_long(final_top)
bottom_long <- reshape_rsp_wide_to_long(final_bottom)

########################################
# COMBINE AND ADD METADATA ----
########################################

# Combine top and bottom
rsp_data <- bind_rows(top_long, bottom_long)

# Get as_of_date from national file if available, otherwise use profile period
# Try to use extract_shared_metadata() if national file exists
as_of_date <- tryCatch({
  metadata <- extract_shared_metadata()
  metadata$as_of_date
}, error = function(e) {
  # Fallback: derive from profile period
  # Profile period format: YYYY_MM
  year <- as.numeric(substr(profile_period, 1, 4))
  month <- as.numeric(substr(profile_period, 6, 7))
  as.Date(paste(year, month, "15", sep = "-"))
})

# Add metadata columns
rsp_data <- rsp_data %>%
  mutate(
    state = pdf_metadata$state,
    period_meaningful = make_period_meaningful_rsp(period),
    as_of_date = as_of_date,
    profile_version = pdf_metadata$profile_version,
    source = pdf_metadata$source
  ) %>%
  # Reorder columns to match target structure
  # Column order: rsp, rsp_lower, rsp_upper, data_used
  select(
    state,
    indicator,
    period,
    period_meaningful,
    rsp,
    rsp_lower,
    rsp_upper,
    data_used,
    as_of_date,
    profile_version,
    source
  )

########################################
# SAVE PROCESSED DATA ----
########################################

# Create run folder in processed structure: data/processed/STATE/PERIOD/DATE/rsp/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "rsp")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
  message("Created run folder: ", folder_run)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)

# Save using save_to_folder_run pattern
save_to_folder_run(rsp_data, "csv")

message("\n=== RSP CSV processing complete ===")
message("Processed ", nrow(rsp_data), " rows for ", pdf_metadata$state)
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

  # Join dictionary metadata to RSP data
  rsp_app_data <- rsp_data %>%
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
 missing_joins <- rsp_app_data %>%
    filter(is.na(category)) %>%
    distinct(indicator)

  if (nrow(missing_joins) > 0) {
    warning("The following indicators did not match the dictionary:")
    print(missing_joins$indicator)
  }

  ########################################
  # CALCULATE RSP STATUS ----
  ########################################

  # Calculate RSP status for each row based on confidence interval overlap
  rsp_app_data <- rsp_app_data %>%
    mutate(
      status = calculate_rsp_status(
        rsp_lower = rsp_lower,
        rsp_upper = rsp_upper,
        national_standard = national_standard,
        direction_rule = direction_rule,
        format_type = format
      )
    )

  message("Calculated RSP status for ", nrow(rsp_app_data), " rows")

  # Verify status distribution (helpful for debugging)
  status_counts <- table(rsp_app_data$status, useNA = "ifany")
  message("Status distribution: ", paste(names(status_counts), "=", status_counts, collapse = ", "))

  # --- Save RDS Files ---
  # Note: No _latest.rds files needed - app dynamically finds most recent profile
  # Only save to PROD location (cm-reports) - DEV location (cfsr-profile/data/app_data) no longer used
  message("\n--- Saving RDS Files ---")

  # PROD: Period-specific file with state prefix (shared app location)
  output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"
  if (!dir.exists(output_dir_prod)) {
    dir.create(output_dir_prod, recursive = TRUE)
  }

  output_file_prod_period <- file.path(output_dir_prod,
    paste0(toupper(state_code), "_cfsr_profile_rsp_", profile_period, ".rds"))
  saveRDS(rsp_app_data, output_file_prod_period)
  message("Saved to PROD: ", output_file_prod_period)
}

########################################
# SUMMARY ----
########################################

message("\n=== RSP Processing Complete ===")
message("State: ", state_code)
message("Profile period: ", profile_period)
message("Total rows: ", nrow(rsp_data))
message("Unique indicators: ", length(unique(rsp_data$indicator)))
message("Profile version: ", pdf_metadata$profile_version)
message("\nData ready for Shiny app!")
message("  - Switch profiles via URL parameter: ?state=", tolower(state_code),
        "&profile=", profile_period)
