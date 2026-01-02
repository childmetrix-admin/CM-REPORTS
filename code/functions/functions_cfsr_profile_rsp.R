########################################
########################################
# CFSR RSP-SPECIFIC FUNCTIONS
########################################
########################################

# RSP-specific utility functions for Risk-Standardized Performance extraction.
# Functions used by multiple scripts, like RSP and observed, have been moved to
# functions_cfsr_profile_shared.R

########################################
# PROCESS RSP TABLE ----
########################################

# extract_tableau_table() and extract_headers() are in functions_cfsr_profile_shared.R

process_table_rsp <- function(df, column_names) {
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

########################################
# FIX SHADOW ARTIFACTS ----
########################################

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

########################################
# CLEAN UP SAFETY DATA ----
########################################

# Maltreatment row
########################################

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

# Maltreatment recurrence
########################################

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

########################################
# CLEAN UP RSP INTERVAL DATA ----
########################################

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

########################################
# CONVERT PERCENTAGES ----
########################################

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

########################################
# CREATE SEPARATE ROWS FOR RSP UPPER & LOWER
########################################

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

########################################
# EXTRACT PERIOD HEADERS FOR SAFETY INDICATORS (bottom half of page) ----
########################################

#' Extract bottom table (maltreatment) period headers from PDF page 2
#'
#' Handles text fragmentation by concatenating fragments within column boundaries.
#'
#' @param raw_data Cleaned PDF text data from page 2
#' @return Named list with zone_a and zone_b period vectors (length 3 each)
extract_maltreatment_periods_rsp <- function(raw_data) {
  # Extract period header row (y=484, with ±2 tolerance)
  period_text <- raw_data %>%
    filter(y >= 482 & y <= 486) %>%
    filter(x < 700) %>%  # Exclude footnote area on right
    arrange(x)
  
  # Define column boundaries based on observed x-coordinates
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
# CALCULATE RSP STATUS  ----
########################################

#' Calculate RSP performance status (above, below, no diff) based on confidence interval overlap
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

########################################
# RESHAPE FRAME WIDE TO LONG ----
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
