# Title:          CFSR Profile - Risk-Standardized Performance (RSP) Data
#                 Process RSP data from state-specific CFSR Data Profile PDFs

# Purpose:        Extract Risk-Standardized Performance metrics from
#                 state-specific CFSR 4 Data Profile PDFs (Adobe text export)

#####################################
# NOTES ----
#####################################

# This file is provided to every state about every 6 months (usually February
# & August). It shows the state's performance and trends on the CFSR
# statewide data indicators, both observed and risk-standardized.
# Also shows data quality (DQ) checks the state failed.

# The RSP (Risk-Standardized Performance) metrics adjust for state-specific
# risk factors and provide fairer state-to-state comparisons.

# INPUT: Adobe-exported text file from state PDF
# - Export PDF to text using Adobe Acrobat: File > Export To > Text (Accessible Text)
# - Save as "adobe_to_accessible_text.txt" in uploads folder

# OUTPUT: Processed CSV with RSP data by indicator and period

# IMPORTANT: This script expects state_code and profile_period to be set
# by the orchestrator (run_profile.R) or manually before sourcing.

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# # Load packages and generic functions
# if (!exists("state_code") || !exists("profile_period")) {
#   message("WARNING: state_code and profile_period not set.")
#   message("Either run via run_profile.R or set manually before sourcing.")
# }
#
# source("D:/repo_childmetrix/utilities-core/loader.R")
#
# # Load CFSR profile functions (RSP data)
# source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_rsp.R")

########################################
# CONFIGURATION ----
########################################

# # Establish current period and set up folders and global variables
# # Uses CFSR-specific setup for multi-state support
# my_setup <- setup_cfsr_folders(profile_period, state_code)
#
# # Base data folder (from ShareFile)
# # base_data_dir <- file.path("S:/Shared Folders", state_code, "cfsr/uploads", profile_period)
#
# # Set file name elements for save_to_folder_run()
# # Include state code in filename for multi-state support
# folder_date <- paste0(state_code, "_", profile_period)
# commitment <- "cfsr profile"
# commitment_description <- "rsp"

########################################
# EXTRACT SHARED METADATA (ONCE) ----
########################################

# Extract metadata common to all sources (profile version and as_of_date)
# metadata <- extract_shared_metadata()

########################################
# EXTRACT RSP DATA FROM PDF ----
########################################

library(pdftools)
library(tidyverse)
library(stringr)

# 1. SETUP ---------------------------------------------------------------------
base_dir <- "D:/repo_childmetrix/cfsr-profile/docs/"
# file_path <- paste0(base_dir, "MD - CFSR 4 Data Profile - February 2024.pdf")
file_path <- paste0(base_dir, "MD - CFSR 4 Data Profile - August 2024.pdf")
# file_path <- paste0(base_dir, "MD - CFSR 4 Data Profile - February 2025.pdf")

raw_data_original <- pdf_data(file_path)[[2]]

# 2. PRE-PROCESS ---------------------------------------------------------------
raw_data <- raw_data_original %>%
  mutate(text = str_replace_all(text, "[^[:graph:]]", "")) %>%
  filter(text != "")

# 3. HELPER FUNCTIONS ----------------------------------------------------------

extract_tableau_table <- function(data, y_min, y_max, x_cuts, y_tolerance = 5) {
  section_data <- data %>%
    filter(y >= y_min & y <= y_max) %>%
    mutate(y_group = round(y / y_tolerance) * y_tolerance) %>%
    mutate(col_id = findInterval(x, x_cuts))

  grid <- section_data %>%
    group_by(y_group, col_id) %>%
    summarise(cell_text = paste(text, collapse = " "), .groups = "drop") %>%
    pivot_wider(names_from = col_id, values_from = cell_text)

  return(grid)
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

  return(df_clean)
}

fix_shadow_text <- function(df) {
  df %>%
    mutate(across(everything(), function(x) {
      x <- as.character(x)
      # General Cleanup
      x <- str_replace_all(x, "D D Q Q", "DQ")
      x <- str_replace_all(x, "2 2 A - 2 3 B 2 2 A - 2 3 B", "22A-23B")
      x <- str_replace_all(x, "2 2 A - 2 3 B", "22A-23B")
      x <- str_replace_all(x, "F Y", "FY")
      x <- str_replace_all(x, "nt er v al RSP i", "RSP interval")
      x <- str_replace_all(x, "RSP i nt er v al", "RSP interval")
      x <- str_replace_all(x, "Dat a us ed", "Data used")

      # 1. Nuclear Cleaning (remove non-ASCII)
      x <- str_replace_all(x, "[^ -~]", "")

      # 2. Heal split decimals ("18. 27" -> "18.27")
      x <- str_replace_all(x, "\\.\\s+(\\d)", ".\\1")

      # 3. FIX GHOST ARTIFACTS (Rows 4 and 6)
      # F4: Remove "16" if it appears before "12" (e.g., "16 12- 16.81")
      x <- str_replace_all(x, "^16\\s+(?=12)", "")
      # F6: Remove "22" if it appears before "22A" (e.g., "22 22A- 22B")
      x <- str_replace_all(x, "^22\\s+(?=22A)", "")

      # 4. Fix spacing around hyphens in period codes (e.g., "20A- 20B" -> "20A-20B", "FY20- 21" -> "FY20-21")
      x <- str_replace_all(x, "(\\d+[AB]?)\\s*-\\s*(\\d+[AB]?)", "\\1-\\2")

      return(x)
    }))
}

# Handles split decimals across columns (18 | .27)
# Uses dynamic column positions: columns 4 and 5 (0-indexed: 3 and 4) after Indicator, National_Perf, Measure_Type
repair_maltreatment_row <- function(df) {

  # This function ONLY repairs split decimals (e.g., "18" in col_4, ".27" in col_5)
  # It should NOT run if there's no actual split pattern detected

  col_names <- names(df)
  col_4 <- col_names[4]  # e.g., "20AB_FY20"
  col_5 <- col_names[5]  # e.g., "21AB_FY21"

  df %>%
    mutate(
      clean_ind = str_replace_all(replace_na(Indicator, ""), "\\s+", ""),
      is_mal_rsp = str_detect(clean_ind, "Maltreatmentincare") & Measure_Type == "RSP"
    ) %>%
    mutate(is_mal_rsp = replace_na(is_mal_rsp, FALSE)) %>%
    rowwise() %>%
    mutate(
      # Only repair if col_5 starts with a decimal point (indicates split)
      # e.g., col_4 = "18", col_5 = ".27" or ". 27"
      col_5_starts_decimal = is_mal_rsp & !is.na(.data[[col_5]]) & str_detect(.data[[col_5]], "^\\s*\\."),

      # If split detected, combine and heal
      combined_text = ifelse(col_5_starts_decimal,
        paste(replace_na(.data[[col_4]], ""), replace_na(.data[[col_5]], "")),
        ""),
      # Heal split ("18 . 27" -> "18.27")
      healed_value = str_replace_all(combined_text, "(\\d)\\s*\\.\\s*(\\d)", "\\1.\\2"),
      # Extract the healed number
      extracted_num = ifelse(col_5_starts_decimal,
        str_extract(healed_value, "\\d+\\.\\d+"),
        NA_character_)
    ) %>%
    ungroup() %>%
    mutate(
      # Only update col_4 with healed value if split was detected
      !!col_4 := ifelse(!is.na(extracted_num), extracted_num, .data[[col_4]]),
      # Clear col_5 if it was just the decimal part
      !!col_5 := ifelse(!is.na(extracted_num), NA_character_, .data[[col_5]])
    ) %>%
    select(-clean_ind, -is_mal_rsp, -col_5_starts_decimal, -combined_text, -healed_value, -extracted_num)
}

fix_recurrence_shift <- function(df) {
  # Get dynamic column names by position
  # Columns: 1=Indicator, 2=National_Perf, 3=Measure_Type, 4-6=AB_FY cols, 7-9=FY cols
  col_names <- names(df)
  col_6 <- col_names[6]  # Last AB_FY column (e.g., "21AB_FY21")
  col_7 <- col_names[7]  # First FY column (e.g., "FY19-20")
  col_8 <- col_names[8]  # Second FY column (e.g., "FY20-21")
  col_9 <- col_names[9]  # Third FY column (e.g., "FY21-22")

  df %>%
    mutate(
      # Create a temporary clean indicator for matching
      clean_ind = str_replace_all(replace_na(Indicator, ""), "\\s+", ""),
      # Detect Maltreatment recurrence rows (NOT maltreatment in care which has "daysincare")
      is_recurrence = str_detect(clean_ind, "recurrence|Maltreatmentrecurrence"),
      is_recurrence_rsp = Measure_Type == "RSP" & is_recurrence,
      is_rec_interval = Measure_Type == "RSP interval" & is_recurrence,
      is_rec_data = Measure_Type == "Data used" & is_recurrence
    ) %>%
    rowwise() %>%
    mutate(
      # --- 1. Fix Recurrence RSP Row: Check if values are shifted left ---
      # If col_7 is NA but col_8 has a value, we need to shift right
      needs_shift = is_recurrence_rsp & is.na(.data[[col_7]]) & !is.na(.data[[col_8]]),

      # Shift values right when needed: col_9 <- col_8, col_8 <- col_7, col_7 <- col_6
      !!col_9 := ifelse(needs_shift, .data[[col_8]], .data[[col_9]]),
      !!col_8 := ifelse(needs_shift, .data[[col_7]], .data[[col_8]]),
      !!col_7 := ifelse(needs_shift, .data[[col_6]], .data[[col_7]]),
      !!col_6 := ifelse(needs_shift, NA_character_, .data[[col_6]]),

      # --- 2. Fix Recurrence Intervals: Split & Shift ---
      extracted_intervals = list(str_extract_all(.data[[col_7]], "\\d+\\.\\d+%\\s*-\\s*\\d+\\.\\d+%")[[1]]),
      !!col_9 := ifelse(is_rec_interval, .data[[col_8]], .data[[col_9]]),
      !!col_7 := ifelse(is_rec_interval & length(extracted_intervals) >= 1,
        extracted_intervals[1], .data[[col_7]]
      ),
      !!col_8 := ifelse(is_rec_interval & length(extracted_intervals) >= 2,
        extracted_intervals[2], .data[[col_8]]
      ),

      # --- 3. Fix Data Used Row: Overwrite Labels using actual column names ---
      !!col_7 := ifelse(is_rec_data, col_7, .data[[col_7]]),
      !!col_8 := ifelse(is_rec_data, col_8, .data[[col_8]]),
      !!col_9 := ifelse(is_rec_data, col_9, .data[[col_9]]),
      !!col_6 := ifelse(is_rec_data, NA_character_, .data[[col_6]])
    ) %>%
    select(-clean_ind, -is_recurrence, -is_recurrence_rsp, -is_rec_interval, -is_rec_data, -needs_shift, -extracted_intervals) %>%
    ungroup()
}



convert_percentages <- function(df) {
  # Indicators that need percentage conversion
  pct_indicators <- c(
    "Permanency in 12 months for children entering care",
    "Permanency in 12 months for children in care 12-23 months",
    "Permanency in 12 months for children in care 24 months or more",
    "Reentry to foster care within 12 months",
    "Maltreatment recurrence within 12 months"
  )

  df %>%
    mutate(across(
      # Target all columns except metadata/grouping ones
      -c(Indicator, Measure_Type),
      ~ {
        # x is the column vector
        x <- .
        # Logic: If row's Indicator is in list AND value has %, convert
        # safely handle NAs
        is_target_row <- Indicator %in% pct_indicators
        is_rsp <- Measure_Type == "RSP"
        has_pct <- str_detect(x, "%")

        # Only modify if target row, is RSP type, has %, and not NA
        to_convert <- !is.na(x) & is_target_row & is_rsp & has_pct

        if (any(to_convert)) {
          # Robust Extraction:
          # Find number associated with %, ignoring leading footnotes (e.g., "3 12.0%" -> 12.0)
          # Regex: Digits/dots that are followed by optional space and %
          cleaned <- str_extract(x[to_convert], "(\\d+\\.?\\d*)(?=\\s*%)")

          numeric_val <- suppressWarnings(as.numeric(cleaned))

          # Only update where valid number produced
          valid_nums <- !is.na(numeric_val)

          # Format back to string (e.g. 0.285)
          x[to_convert][valid_nums] <- as.character(numeric_val[valid_nums] / 100)
        }
        x
      }
    ))
}

expand_rsp_intervals <- function(df) {
  # Separation logic:
  # 1. Keep non-interval rows as is.
  # 2. Filter interval rows, duplicate and transform.

  # Indicators that need percentage conversion (divide by 100)
  pct_indicators <- c(
    "Permanency in 12 months for children entering care",
    "Permanency in 12 months for children in care 12-23 months",
    "Permanency in 12 months for children in care 24 months or more",
    "Reentry to foster care within 12 months",
    "Maltreatment recurrence within 12 months"
  )

  non_interval <- df %>% filter(Measure_Type != "RSP interval")

  interval_rows <- df %>% filter(Measure_Type == "RSP interval")

  # Process Lower Bound
  lower_rows <- interval_rows %>%
    mutate(Measure_Type = "RSP Lower") %>%
    mutate(across(-c(Indicator, Measure_Type, National_Perf), ~ {
      x <- .
      # Capture Lower Bound: Value BEFORE the hyphen
      # Regex: Capture group 1 (digits/pct) followed by space/hyphen
      extracted <- str_match(x, "(\\d+\\.?\\d*%?)\\s*-")[, 2]

      # Clean percentages if applicable
      is_pct_ind <- Indicator %in% pct_indicators
      clean_num <- str_remove(extracted, "%")
      numeric_val <- suppressWarnings(as.numeric(clean_num))

      # Convert if percentage indicator
      final_val <- ifelse(is_pct_ind & !is.na(numeric_val), numeric_val / 100, numeric_val)
      as.character(final_val)
    }))

  # Process Upper Bound
  upper_rows <- interval_rows %>%
    mutate(Measure_Type = "RSP Upper") %>%
    mutate(across(-c(Indicator, Measure_Type, National_Perf), ~ {
      x <- .
      # Capture Upper Bound: Value AFTER the hyphen
      # Regex: Hyphen/space followed by Capture group 1 (digits/pct)
      extracted <- str_match(x, "-\\s*(\\d+\\.?\\d*%?)")[, 2]

      # Clean percentages if applicable
      is_pct_ind <- Indicator %in% pct_indicators
      clean_num <- str_remove(extracted, "%")
      numeric_val <- suppressWarnings(as.numeric(clean_num))

      # Convert if percentage indicator
      final_val <- ifelse(is_pct_ind & !is.na(numeric_val), numeric_val / 100, numeric_val)
      as.character(final_val)
    }))

  # Combine and convert National_Perf for percentage indicators
  bind_rows(non_interval, lower_rows, upper_rows) %>%
    mutate(
      National_Perf = {
        # Extract numeric value, removing % and trailing spaces
        clean_val <- str_trim(str_remove(National_Perf, "%"))
        numeric_val <- suppressWarnings(as.numeric(clean_val))
        # Convert to decimal if percentage indicator
        is_pct_ind <- Indicator %in% pct_indicators
        final_val <- ifelse(is_pct_ind & !is.na(numeric_val), numeric_val / 100, numeric_val)
        as.character(final_val)
      }
    ) %>%
    arrange(Indicator, Measure_Type)
}

extract_headers <- function(data, y_min, y_max, x_cuts) {
  # Filter for header text
  headers_data <- data %>%
    filter(y >= y_min & y <= y_max) %>%
    mutate(col_id = findInterval(x, x_cuts))

  # Initialize vector for all columns (0 to length(x_cuts))
  # 0 = before first cut
  # 1 = between first and second
  # ...
  n_cols <- length(x_cuts) # Intervals are 0..n_cols

  header_map <- headers_data %>%
    group_by(col_id) %>%
    summarise(text = paste(text, collapse = ""), .groups = "drop") %>% # No space, as headers like "20A20B" usually solid
    arrange(col_id)

  # Fill in gaps
  # We expect columns 0, 1, 2 hardcoded (Indicator, Nat Perf, Meas Type)
  # But for the dynamic ones (3 onwards), we need the text.

  extracted_cols <- setNames(rep(NA_character_, n_cols + 1), 0:n_cols)
  extracted_cols[as.character(header_map$col_id)] <- header_map$text

  # Hardcode known first columns if they are messy in PDF
  extracted_cols["0"] <- "Indicator"
  extracted_cols["1"] <- "National_Perf"
  extracted_cols["2"] <- "Measure_Type"

  return(extracted_cols)
}

# 4. TOP TABLE (LOCKED) --------------------------------------------------------

top_x_cuts <- c(135, 165, 255, 300, 360, 420, 490, 570, 630, 690, 750)

# Extract headers dynamically (approx y range for headers above table)
# Data starts at 190, so headers likely 170-190
top_cols_vec <- extract_headers(raw_data, y_min = 170, y_max = 190, x_cuts = top_x_cuts)
top_cols <- unname(top_cols_vec)

df_top_raw <- extract_tableau_table(raw_data,
  y_min = 190,
  y_max = 480,
  x_cuts = top_x_cuts
)

# top_cols is now dynamic
# "Indicator" "National_Perf" "Measure_Type" "20A20B" ...

final_top <- process_table(df_top_raw, top_cols) %>%
  fix_shadow_text() %>%
  mutate(Indicator = rep(c(
    "Permanency in 12 months for children entering care",
    "Permanency in 12 months for children in care 12-23 months",
    "Permanency in 12 months for children in care 24 months or more",
    "Reentry to foster care within 12 months",
    "Placement stability (moves / 1,000 days in care)"
  ), each = 3)) %>%
  convert_percentages() %>%
  expand_rsp_intervals()


# 5. BOTTOM TABLE (FINAL POLISH) -----------------------------------------------

# --- ZONE A: Maltreatment (Rows 1-8) ---
# x_cuts define column boundaries for data extraction
# Columns: 0=Indicator, 1=National_Perf, 2=Measure_Type, 3-5=AB_FY cols, 6-8=FY cols
# Original cuts that work for numeric data; Data used row will be cleaned separately
zone_a_cuts <- c(135, 165, 215, 285, 355, 425, 520, 610, 700)

# Generate bottom_cols dynamically based on the top table headers
# The bottom table follows a predictable pattern derived from top table periods
# Top table has period pairs like "19A19B", "19B20A", etc.
# Bottom table AB_FY columns use consecutive years starting from the first
# Bottom table FY columns use fiscal years spanning those years
generate_bottom_cols <- function(top_cols) {
  # Extract period columns from top (skip Indicator, National_Perf, Measure_Type)
  top_periods <- top_cols[4:length(top_cols)]

  # Get the starting year from first period (e.g., "19A19B" -> 19)
  start_year <- as.numeric(str_extract(top_periods[1], "^\\d+"))

  # Generate 3 consecutive years for AB_FY columns
  years <- start_year:(start_year + 2)

  # Build AB_FY columns (e.g., "19AB_FY19", "20AB_FY20", "21AB_FY21")
  ab_fy_cols <- paste0(years, "AB_FY", years)

  # Build FY columns spanning adjacent years (e.g., "FY19-20", "FY20-21", "FY21-22")
  fy_cols <- paste0("FY", years, "-", years + 1)

  c("Indicator", "National_Perf", "Measure_Type", ab_fy_cols, fy_cols)
}

bottom_cols <- generate_bottom_cols(top_cols)

df_zone_a <- extract_tableau_table(raw_data,
  y_min = 490,
  y_max = 565,
  x_cuts = zone_a_cuts,
  y_tolerance = 10
)

clean_a <- process_table(df_zone_a, bottom_cols) %>%
  fix_shadow_text() %>%
  repair_maltreatment_row()

# Fix "Data used" row for Maltreatment in care - values are predictable based on column names
# The AB_FY columns contain "YYA-YYB, FYYY-YY+1" format
fix_maltreatment_data_used <- function(df, col_names) {
  # Get the years from column names (e.g., "19AB_FY19" -> 19)
  years <- as.numeric(str_extract(col_names[4:6], "^\\d+"))

  # Build expected "Data used" values for AB_FY columns
  data_used_values <- paste0(years, "A-", years, "B, FY", years, "-", years + 1)

  df %>%
    mutate(
      # Fix columns 4, 5, 6 (the AB_FY columns) for Data used row
      !!col_names[4] := ifelse(Measure_Type == "Data used", data_used_values[1], .data[[col_names[4]]]),
      !!col_names[5] := ifelse(Measure_Type == "Data used", data_used_values[2], .data[[col_names[5]]]),
      !!col_names[6] := ifelse(Measure_Type == "Data used", data_used_values[3], .data[[col_names[6]]])
    )
}

clean_a <- fix_maltreatment_data_used(clean_a, bottom_cols)


# --- ZONE B: Recurrence (Rows 9+) ---
# Adjusted cuts to capture all 3 FY column values
# Last cut extended to 760 to ensure rightmost value is captured
zone_b_cuts <- c(135, 165, 215, 285, 355, 425, 495, 570, 650)

df_zone_b <- extract_tableau_table(raw_data,
  y_min = 570,
  y_max = 615,
  x_cuts = zone_b_cuts,
  y_tolerance = 10
)

clean_b <- process_table(df_zone_b, bottom_cols) %>%
  fix_shadow_text()

# Fix Maltreatment recurrence RSP row - values often shifted left, need to shift right
fix_recurrence_rsp <- function(df, col_names) {
  col_7 <- col_names[7]
  col_8 <- col_names[8]
  col_9 <- col_names[9]

  df %>%
    mutate(
      # Detect if RSP row has NA in first FY column but values in 8 and 9
      is_rsp_shifted = Measure_Type == "RSP" & is.na(.data[[col_7]]) & !is.na(.data[[col_8]]),
      # Shift values right: 9 <- 8, 8 <- 7 (which is NA, so find actual value)
      # Actually need to look at what's in columns and shift appropriately
    )
}

# Instead, let's just directly set the expected RSP values for recurrence
# Since the extraction is unreliable, we can check if the row looks wrong and skip the fix
# Or better: widen zone_b to capture all 3 values properly

# Combine Zones FIRST, then fix the Recurrence Shift globally
# Get FY column names dynamically (columns 7-9)
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
    ~ ifelse(Indicator == "Maltreatment in care (victimizations / 100,000 days in care)", NA, .)
  )) %>%
  expand_rsp_intervals()

# 6. SAVE
write_csv(final_top, paste0(base_dir, "cfsr_indicators_top.csv"))
write_csv(final_bottom, paste0(base_dir, "cfsr_indicators_bottom.csv"))

message("Extraction Complete. F4/F6 artifacts removed. F8 shifted.")

########################################
# PROCESS RSP DATA ----
########################################

# # Add metadata columns to match national data structure
# rsp_data <- rsp_raw %>%
#   mutate(
#     state = toupper(state_code),
#     profile_ver = metadata$profile_version,
#     profile_month = metadata$profile_month,
#     profile_year = metadata$profile_year,
#     as_of_date = metadata$as_of_date,
#     source = metadata$source,
#     data_type = "rsp"  # Distinguish from observed (national) data
#   )
#
# # Reorder columns for consistency
# rsp_data <- rsp_data %>%
#   select(
#     state,
#     indicator,
#     period,
#     rsp_value,
#     rsp_numeric,
#     rsp_interval,
#     interval_lower,
#     interval_upper,
#     national_performance,
#     np_numeric,
#     data_quality_issue,
#     profile_ver,
#     profile_month,
#     profile_year,
#     as_of_date,
#     source,
#     data_type
#   )
#
# ########################################
# # SAVE PROCESSED DATA ----
# ########################################
#
# # Create run folder matching national structure: data/processed/STATE/PERIOD/YYYY-MM-DD/rsp/
# run_date <- Sys.Date()
# folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "rsp")
# if (!dir.exists(folder_run)) {
#   dir.create(folder_run, recursive = TRUE)
#   message("Created run folder: ", folder_run)
# }
# assign("folder_run", folder_run, envir = .GlobalEnv)
# assign("run_date", run_date, envir = .GlobalEnv)
#
# save_to_folder_run(rsp_data, "csv")
#
# message("\n✓ RSP data processing complete")

########################################
# AUTO-RUN PREPARE_APP_DATA (FUTURE) ----
########################################

# TODO: Create prepare_app_data_rsp.R to generate RDS files for Shiny app
# Similar to national processing, but for RSP-specific visualizations

# message("\n=== Data processing complete ===")
# message("Now preparing data for Shiny app...\n")
#
# prepare_script <- "D:/repo_childmetrix/cfsr-profile/shiny_app/prepare_app_data_rsp.R"
# if (file.exists(prepare_script)) {
#   source(prepare_script)
#   message("\n=== All done! ===")
#   message("Data ready for Shiny app at profile period: ", profile_period)
# } else {
#   warning("Could not find prepare_app_data_rsp.R at: ", prepare_script)
# }
