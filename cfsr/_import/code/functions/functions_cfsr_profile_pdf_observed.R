########################################
########################################
# CFSR OBSERVED PERFORMANCE-SPECIFIC FUNCTIONS
########################################
########################################

# Observed performance-specific utility functions for extraction from page 4.
# Functions used by multiple scripts have been moved to
# functions_cfsr_profile_shared.R

########################################
# PROCESS OBSERVED TABLE ----
########################################

# extract_tableau_table() and extract_headers() are in functions_cfsr_profile_shared.R

process_table_observed <- function(df, column_names) {
  # Similar to process_table_rsp() but adapted for observed performance structure
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

########################################
# EXTRACT PERIOD HEADERS FOR SAFETY INDICATORS (bottom half of page 4) ----
########################################

#' Extract bottom table (maltreatment) period headers from PDF page 4
#'
#' Handles text fragmentation by concatenating fragments within column boundaries.
#'
#' @param raw_data Cleaned PDF text data from page 4
#' @return Named list with zone_a and zone_b period vectors (length 3 each)
extract_maltreatment_periods_observed <- function(raw_data) {
  # Extract period header row (y=403, with ±2 tolerance)
  period_text <- raw_data %>%
    filter(y >= 401 & y <= 405) %>%
    arrange(x)

  # Define column boundaries based on observed x-coordinates
  # Zone A: Maltreatment in care (##AB.FY##)
  zone_a_bounds <- list(
    col1 = c(245, 290),  # 19AB_FY19 at x~253-277
    col2 = c(310, 355),  # 20AB_FY20 at x~320-344
    col3 = c(375, 425)   # 21AB_FY21 at x~387-411
  )

  # Zone B: Recurrence (FY##-##)
  zone_b_bounds <- list(
    col1 = c(455, 500),  # FY19-20 at x~464-487
    col2 = c(520, 565),  # FY20-21 at x~531-554
    col3 = c(585, 635)   # FY21-22 at x~598-621
  )

  # Extract Zone A periods
  zone_a_periods <- sapply(zone_a_bounds, function(bounds) {
    col_text <- period_text %>%
      filter(x >= bounds[1] & x <= bounds[2]) %>%
      pull(text) %>%
      paste(collapse = "")

    # Clean: remove spaces, commas, ensure dot separator
    cleaned <- col_text %>%
      str_remove_all("\\s|,") %>%
      str_replace("([0-9]{2}AB)(FY)", "\\1.\\2")

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
# RESHAPE OBSERVED DATA WIDE TO LONG ----
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
