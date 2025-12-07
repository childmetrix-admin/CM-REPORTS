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
file_path <- paste0(base_dir, "MD - CFSR 4 Data Profile - February 2025.pdf")
# file_path <- paste0(base_dir, "MD - CFSR 4 Data Profile - August 2024.pdf")

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

      return(x)
    }))
}

# Handles split decimals across columns (18 | .27)
repair_maltreatment_row <- function(df) {
  df %>%
    mutate(
      clean_ind = str_replace_all(replace_na(Indicator, ""), "\\s+", ""),
      is_mal_target = str_detect(clean_ind, "Maltreatmentincare") & Measure_Type == "RSP"
    ) %>%
    mutate(is_mal_target = replace_na(is_mal_target, FALSE)) %>%
    rowwise() %>%
    mutate(
      # Combine E and F
      combined_text = ifelse(is_mal_target,
        paste(replace_na(`21AB_FY21`, ""), replace_na(`22AB_FY22`, "")),
        ""
      ),
      # Heal split ("18 . 27")
      combined_text_clean = str_replace_all(combined_text, "(\\d)\\s*\\.\\s*(\\d)", "\\1.\\2"),
      # Extract
      extracted_nums = list(str_extract_all(combined_text_clean, "\\d+\\.?\\d*")[[1]])
    ) %>%
    mutate(
      `21AB_FY21` = ifelse(is_mal_target & length(extracted_nums) >= 1,
        extracted_nums[1], `21AB_FY21`
      ),
      `22AB_FY22` = ifelse(is_mal_target & length(extracted_nums) >= 2,
        extracted_nums[2], `22AB_FY22`
      )
    ) %>%
    select(-clean_ind, -is_mal_target, -combined_text, -combined_text_clean, -extracted_nums) %>%
    ungroup()
}

fix_recurrence_shift <- function(df) {
  df %>%
    rowwise() %>%
    mutate(
      # Create a temporary clean indicator for matching
      clean_ind = str_replace_all(replace_na(Indicator, ""), "\\s+", ""),

      # --- 1. Fix Row 8 (Recurrence Values): Shift Right ---
      # Match "daysincare" instead of "days in care" to ignore spacing issues
      is_recurrence_rsp = Measure_Type == "RSP" & str_detect(clean_ind, "daysincare"),
      `FY22-23` = ifelse(is_recurrence_rsp, `FY21-22`, `FY22-23`),
      `FY21-22` = ifelse(is_recurrence_rsp, `FY20-21`, `FY21-22`),
      `FY20-21` = ifelse(is_recurrence_rsp, `22AB_FY22`, `FY20-21`),
      `22AB_FY22` = ifelse(is_recurrence_rsp, NA_character_, `22AB_FY22`),

      # --- 2. Fix Row 10 (Recurrence Intervals): Split & Shift ---
      is_rec_interval = Measure_Type == "RSP interval" & str_detect(`FY20-21`, "\\d%"),
      `FY22-23` = ifelse(is_rec_interval, `FY21-22`, `FY22-23`),
      extracted_intervals = list(str_extract_all(`FY20-21`, "\\d+\\.\\d+%\\s*-\\s*\\d+\\.\\d+%")[[1]]),
      `FY20-21` = ifelse(is_rec_interval & length(extracted_intervals) >= 1,
        extracted_intervals[1], `FY20-21`
      ),
      `FY21-22` = ifelse(is_rec_interval & length(extracted_intervals) >= 2,
        extracted_intervals[2], `FY21-22`
      ),

      # --- 3. Fix Row 11 (Data Used): Overwrite Labels ---
      is_rec_data = Measure_Type == "Data used" & str_detect(clean_ind, "maltreatment"), # often labelled "maltreatment" in footer

      `FY20-21` = ifelse(is_rec_data, "FY20-21", `FY20-21`),
      `FY21-22` = ifelse(is_rec_data, "FY21-22", `FY21-22`),
      `FY22-23` = ifelse(is_rec_data, "FY22-23", `FY22-23`),
      `22AB_FY22` = ifelse(is_rec_data, NA_character_, `22AB_FY22`)
    ) %>%
    select(-clean_ind, -is_recurrence_rsp, -is_rec_interval, -is_rec_data, -extracted_intervals) %>%
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
          # Extract only the leading number, ignoring trailing text (e.g., "12.0% s t at i s")
          # Regex: Start of string (possibly after space), digits, optional dot, optional digits
          cleaned <- str_extract(str_trim(x[to_convert]), "^\\d+\\.?\\d*")

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
  convert_percentages()


# 5. BOTTOM TABLE (FINAL POLISH) -----------------------------------------------

bottom_cols <- c(
  "Indicator", "National_Perf", "Measure_Type",
  "20AB_FY20", "21AB_FY21", "22AB_FY22",
  "FY20-21", "FY21-22", "FY22-23"
)

# --- ZONE A: Maltreatment (Rows 1-8) ---
zone_a_cuts <- c(135, 165, 215, 285, 345, 510, 600, 680, 760)

df_zone_a <- extract_tableau_table(raw_data,
  y_min = 490,
  y_max = 565,
  x_cuts = zone_a_cuts,
  y_tolerance = 10
)

clean_a <- process_table(df_zone_a, bottom_cols) %>%
  fix_shadow_text() %>%
  repair_maltreatment_row() %>%
  mutate(
    # --- ROW 4 (E4): Force clean range ---
    `21AB_FY21` = ifelse(str_detect(`21AB_FY21`, "15.*78.*21.*"), "15.78-21.16", `21AB_FY21`),

    # --- ROW 6: Data Used ---
    `21AB_FY21` = ifelse(str_detect(`21AB_FY21`, "21A.*21B.*FY21"), "21A-21B, FY21-22", `21AB_FY21`)
  )


# --- ZONE B: Recurrence (Rows 9+) ---
zone_b_cuts <- c(135, 165, 215, 300, 320, 440, 560, 640, 740)

df_zone_b <- extract_tableau_table(raw_data,
  y_min = 570,
  y_max = 615,
  x_cuts = zone_b_cuts,
  y_tolerance = 10
)

clean_b <- process_table(df_zone_b, bottom_cols) %>%
  fix_shadow_text()

# Combine Zones FIRST, then fix the Recurrence Shift globally
final_bottom <- bind_rows(clean_a, clean_b) %>%
  fix_recurrence_shift() %>%
  mutate(Indicator = rep(c(
    "Maltreatment in care (victimizations / 100,000 days in care)",
    "Maltreatment recurrence within 12 months"
  ), each = 3)) %>%
  convert_percentages() %>%
  mutate(across(
    c("FY20-21", "FY21-22", "FY22-23"),
    ~ ifelse(Indicator == "Maltreatment in care (victimizations / 100,000 days in care)", NA, .)
  ))

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
