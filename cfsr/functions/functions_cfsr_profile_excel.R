########################################
########################################
# CFSR NATIONAL PERFORMANCE-SPECIFIC FUNCTIONS
########################################
########################################

# National performance-specific functions to extract data from national excel file.
# Shared functions have been moved to functions_cfsr_profile_shared.R

# NOTE: This file now sources shared CFSR functions from functions_cfsr_profile_shared.R
# Shared functions include: setup_cfsr_folders, find_cfsr_file, load_indicator_dictionary,
# get_indicator_name, cfsr_profile_version, cfsr_profile_extract_asof_date,
# rank_states_by_performance

########################################
# PROCESS EXCEL DATA ----
########################################

# Extract relevant rows from the data frame
# -----------------------------------

extract_relevant_rows <- function(data_df, jurisdiction_header = "52 Jurisdictions") {
  # Identify the first row whose second column matches one of the period patterns.
  # The pattern matches:
  # - A 4-digit year (e.g., "2024")
  # - Standard periods: "YYAYYB" or "YYBYYA" (e.g., "19A19B" or "19B20A")
  # - Maltreatment: "YYAB,FYYY" (e.g., "20AB,FY20")
  # - Recurrence: "FYYY-YY" (e.g., "FY20-21")
  period_pattern <- "^(?:[0-9]{4}|[0-9]{2}[AB][0-9]{2}[AB]|[0-9]{2}AB,FY[0-9]{2}|FY[0-9]{2}-[0-9]{2})$"
  period_row_index <- which(grepl(period_pattern, data_df[[2]]))[1]

  # Identify the block of jurisdiction rows (states for national, localities for state files)
  # Find the row with jurisdiction header (e.g., "52 Jurisdictions" or "Locality")
  # Try multiple variations of the header text
  jurisdictions_patterns <- c(
    jurisdiction_header,
    paste0(jurisdiction_header, "  "),  # Extra space
    tolower(jurisdiction_header)   # Lowercase
  )

  jurisdictions_row_index <- NA
  for (pattern in jurisdictions_patterns) {
    idx <- which(trimws(as.character(data_df[[1]])) == pattern)[1]
    if (!is.na(idx)) {
      jurisdictions_row_index <- idx
      break
    }
  }

  # If still not found, try pattern matching for "52" followed by any text
  if (is.na(jurisdictions_row_index)) {
    idx <- which(grepl("^52\\s+", trimws(as.character(data_df[[1]]))))[1]
    if (!is.na(idx)) {
      jurisdictions_row_index <- idx
    }
  }

  if (is.na(jurisdictions_row_index)) {
    # Fallback to old method: look for Alabama and Wyoming
    warning("Could not find '52 Jurisdictions' header. Falling back to Alabama/Wyoming detection.")
    state_start_index <- which(data_df[[1]] == "Alabama")[1]
    state_end_candidates <- which(data_df[[1]] == "Wyoming")
    state_end_index <- state_end_candidates[state_end_candidates > state_start_index][1]

    if (is.na(state_start_index) || is.na(state_end_index)) {
      # Show what's actually in column 1 to help debug
      col1_values <- head(unique(data_df[[1]]), 30)
      stop("Could not find state rows using either '52 Jurisdictions' header or Alabama/Wyoming.\n",
           "First 30 unique values in column 1:\n",
           paste(col1_values, collapse = "\n"))
    }
  } else {
    # First state row is the next row after "52 Jurisdictions" (or similar header)
    state_start_index <- jurisdictions_row_index + 1

    # Find where state list ends by looking for first footnote row
    # (openxlsx doesn't preserve blank rows, so we detect footnotes instead)
    # All footnotes start with "Note" followed by a number (e.g., "Note 1:", "Note 2:")
    candidate_rows <- (state_start_index + 1):nrow(data_df)

    footnote_row_index <- NA
    for (row_idx in candidate_rows) {
      col1_value <- as.character(data_df[[1]][row_idx])

      # Skip if NA or empty
      if (is.na(col1_value) || trimws(col1_value) == "") {
        next
      }

      # Check if this row starts with "Note" followed by a number
      # Pattern: "Note 1:", "Note 2:", etc.
      is_footnote <- grepl("^Note\\s+\\d+:", trimws(col1_value), ignore.case = TRUE)

      if (is_footnote) {
        footnote_row_index <- row_idx
        break
      }
    }

    if (is.na(footnote_row_index)) {
      # No footnotes found - state list extends to end of dataframe
      state_end_index <- nrow(data_df)
    } else {
      # Last state row is one before the first footnote
      # (In the dataframe, openxlsx skips the blank row that's in Excel between states and footnotes)
      state_end_index <- footnote_row_index - 1
    }
  }

  # Combine the row indices: the period row and the block of state rows
  rows_to_keep <- c(period_row_index, seq(from = state_start_index, to = state_end_index))

  # Subset the data frame to keep only the identified rows and return the result
  return(data_df[rows_to_keep, ])
}

# Extract dimension rows (age, race, etc.)
# -----------------------------------

extract_dimension_rows <- function(data_df, dimension_header_pattern, end_marker_pattern) {
  # Find the dimension header row (e.g., "Age" for age breakdowns)
  # Pattern must match at START of string to avoid false matches (e.g., "what age group" vs "Age at entry")
  dimension_row_index <- NA
  for (row_idx in 1:nrow(data_df)) {
    col1_value <- as.character(data_df[[1]][row_idx])

    if (is.na(col1_value) || trimws(col1_value) == "") {
      next
    }

    # Use ^ anchor to match pattern at start of string only
    pattern_with_anchor <- paste0("^", dimension_header_pattern)
    if (grepl(pattern_with_anchor, trimws(col1_value), ignore.case = TRUE)) {
      dimension_row_index <- row_idx
      break
    }
  }

  if (is.na(dimension_row_index)) {
    # Dimension section not found
    return(NULL)
  }

  # First dimension value row is the next row after the header
  dimension_start_index <- dimension_row_index + 1

  # Find where dimension rows end (row before end marker)
  candidate_rows <- (dimension_start_index + 1):nrow(data_df)

  end_marker_index <- NA
  for (row_idx in candidate_rows) {
    col1_value <- as.character(data_df[[1]][row_idx])

    if (is.na(col1_value) || trimws(col1_value) == "") {
      next
    }

    if (grepl(end_marker_pattern, trimws(col1_value), ignore.case = TRUE)) {
      end_marker_index <- row_idx
      break
    }
  }

  if (is.na(end_marker_index)) {
    # End marker not found - dimension rows extend to end of dataframe
    dimension_end_index <- nrow(data_df)
  } else {
    # Last dimension row is one before the end marker
    dimension_end_index <- end_marker_index - 1
  }

  # Return the dimension header value and the data rows
  dimension_header <- trimws(as.character(data_df[[1]][dimension_row_index]))
  dimension_data <- data_df[dimension_start_index:dimension_end_index, ]

  return(list(
    header = dimension_header,
    data = dimension_data
  ))
}

# Process standard CFSR indicator (den/num/per structure)
########################################

# Handles 5 of 6 indicators: Re-Entry, Perm in 12 (entries),
# Perm in 12 (12-23 mos), Perm in 12 (24+ mos), Placement Stability
#
# (Entry Rate is special - has years/census_year - use process_entry_rate_indicator)
#
# This function extracts both state-level data and age-based demographic breakdowns
# from the same Excel sheet. Age data appears below state data in the sheet.
#
# @param sheet_name: Excel worksheet name (e.g., "Reentry to FC")
# @param indicator_name: Full indicator display name for output
# @param keep_cols: Column range to select (default c(1:10))
# @param period_cols: Column indices for period labels (default 2:4)
# @param ver: Profile version list from cfsr_profile_version() (optional - gets from global)
# @param as_of_date: Date from cfsr_profile_extract_asof_date() (optional - gets from global)
#
# @return: Tibble with standardized indicator structure including dimension columns:
#   - For state rows: dimension = "State", dimension_value = NA, state = [state name]
#   - For age rows: dimension = [header text], dimension_value = [age group], state = "National"
#   - state_rank and reporting_states are only populated for state rows (NA for age rows)

process_standard_indicator <- function(sheet_name,
                                       indicator_name = NULL,
                                       keep_cols = c(1:10),
                                       period_cols = 2:4,
                                       ver = NULL,
                                       as_of_date = NULL,
                                       jurisdiction_header = "52 Jurisdictions",
                                       state_code = NULL) {

  # Get indicator name from dictionary if not provided
  if (is.null(indicator_name)) {
    indicator_name <- get_indicator_name(sheet_name)
  }

  # Get from global env if not provided
  if (is.null(ver)) ver <- get("ver", envir = .GlobalEnv)
  if (is.null(as_of_date)) as_of_date <- get("as_of_date", envir = .GlobalEnv)

  # 1. Load sheet
  data_df_full <- find_cfsr_file(
    keyword = NULL,
    file_type = "excel",
    sheet_name = sheet_name,
    state_code = state_code
  )

  # Keep only needed columns
  data_df_full <- data_df_full[, keep_cols, drop = FALSE]

  # 2. Extract jurisdiction rows (states for national, localities for state files)
  data_df_states <- extract_relevant_rows(data_df_full, jurisdiction_header)

  # 3. Extract age rows (if available)
  # Age section ends when Race section begins
  age_data <- extract_dimension_rows(data_df_full, "Age", "Race")

  # 4. Extract race/ethnicity rows (if available)
  # Race section ends when jurisdiction section begins
  race_data <- extract_dimension_rows(data_df_full, "Race", jurisdiction_header)

  # 5. Extract metadata from state rows
  metadata <- data_df_states[1, ]
  periods <- metadata[period_cols] %>% as.character()

  # Clean periods: remove NA, empty strings, and trim whitespace
  periods <- trimws(periods)
  periods_before <- periods
  periods <- periods[!is.na(periods) & nchar(periods) > 0]

  # Validate we have periods
  if (length(periods) == 0) {
    stop("No valid periods found in columns ", paste(period_cols, collapse = ", "),
         ". Raw values were: ", paste(periods_before, collapse = ", "),
         ". Check that the Excel sheet has period labels in the expected columns.")
  }

  # Helper function to process rows (works for both jurisdiction and demographic data)
  process_rows <- function(data_rows, dimension_name = NULL, dimension_header = NULL) {
    # Skip metadata row (first row)
    data_clean <- data_rows[-1, ]

    # Rename columns dynamically based on actual number of periods
    n_periods <- length(periods)
    den_cols <- paste0("den_", periods)
    num_cols <- paste0("num_", periods)
    per_cols <- paste0("per_", periods)

    # Expected number of columns: 1 (state) + 3 sets of periods
    expected_cols <- 1 + (3 * n_periods)
    actual_cols <- ncol(data_clean)

    if (actual_cols != expected_cols) {
      warning(paste0("Column count mismatch. Expected ", expected_cols,
                     " (1 state + ", n_periods, " periods × 3 metrics), got ", actual_cols))
    }

    # Build column names
    new_cols <- c("state", den_cols, num_cols, per_cols)

    # Check for duplicates before assigning
    if (any(duplicated(new_cols))) {
      stop("Duplicate column names detected: ",
           paste(new_cols[duplicated(new_cols)], collapse = ", "),
           ". Periods extracted: ", paste(periods, collapse = ", "))
    }

    colnames(data_clean) <- new_cols

    # Convert to numeric
    data_clean <- data_clean %>%
      mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

    # Reshape wide to long
    data_long <- data_clean %>%
      pivot_longer(
        cols = starts_with("den") | starts_with("num") | starts_with("per"),
        names_to = c(".value", "period"),
        names_pattern = "(den|num|per)_(.+)"
      ) %>%
      rename(denominator = den, numerator = num, performance = per)

    # Add dimension columns
    if (is.null(dimension_name)) {
      # Jurisdiction rows (states for national files, localities for state files)
      if (jurisdiction_header == "52 Jurisdictions") {
        # National file - state rows
        data_long <- data_long %>%
          mutate(
            dimension = "State",
            dimension_value = NA_character_
            # state column already has state names from Excel
          )
      } else {
        # State file - locality rows
        # Excel has locality names in 'state' column, need to swap
        state_name <- convert_state_code_to_name(toupper(state_code))
        data_long <- data_long %>%
          mutate(
            dimension = "Locality",
            dimension_value = state,  # Excel had locality names
            state = state_name  # Replace with actual state name
          )
      }
    } else {
      # Demographic rows (age, race, etc.)
      if (jurisdiction_header == "52 Jurisdictions") {
        # National file - demographics are at national level
        data_long <- data_long %>%
          mutate(
            dimension = dimension_header,
            dimension_value = state,
            state = "National"
          )
      } else {
        # State file - demographics are at state level
        state_name <- convert_state_code_to_name(toupper(state_code))
        data_long <- data_long %>%
          mutate(
            dimension = dimension_header,
            dimension_value = state,
            state = state_name
          )
      }
    }

    return(data_long)
  }

  # 6. Process state rows
  state_df <- process_rows(data_df_states, dimension_name = NULL)

  # 7. Process age rows (if available)
  age_df <- NULL
  if (!is.null(age_data)) {
    age_df <- process_rows(age_data$data, dimension_name = "age", dimension_header = age_data$header)
  }

  # 8. Process race/ethnicity rows (if available)
  race_df <- NULL
  if (!is.null(race_data)) {
    race_df <- process_rows(race_data$data, dimension_name = "race", dimension_header = race_data$header)
  }

  # 9. Combine all datasets
  combined_df <- bind_rows(state_df, age_df, race_df)

  # 10. Add metadata columns
  final_df <- combined_df %>%
    mutate(
      state = ifelse(state == "District of Columbia", "D.C.", state),
      denominator = as.numeric(denominator),
      numerator = as.numeric(numerator),
      performance = as.numeric(performance),
      indicator = indicator_name,
      # Fix period format: replace comma with underscore, remove whitespace
      # Handles "20AB,FY20" => "20AB_FY20" and "23AB_ FY23" => "23AB_FY23"
      # This ensures period matches the format used in observed/RSP data for proper joins
      period = gsub("\\s+", "", gsub(",", "_", period)),
      as_of_date = as_of_date,
      source = ver$source,
      period_meaningful = make_period_meaningful(period),
      profile_version = ver$profile_version
    )

  # 8. Rank states (only for state-level data)
  # Split into state and non-state data
  state_rows <- final_df %>% filter(dimension == "State")
  non_state_rows <- final_df %>% filter(dimension != "State")

  # Rank only state rows
  if (nrow(state_rows) > 0) {
    state_rows <- rank_states_by_performance(state_rows)
  }

  # For non-state rows, set rank columns to NA
  if (nrow(non_state_rows) > 0) {
    non_state_rows <- non_state_rows %>%
      mutate(
        state_rank = NA_integer_,
        reporting_states = NA_integer_
      )
  }

  # Recombine
  final_df <- bind_rows(state_rows, non_state_rows)

  # 9. Select final columns (no census_year for standard indicators, but includes dimension)
  final_df %>%
    select(state, indicator, dimension, dimension_value, period, period_meaningful,
           denominator, numerator, performance, state_rank, reporting_states,
           as_of_date, profile_version, source)
}

# Process Entry Rate indicator (special case with years)
########################################

# Entry Rate is unique: has both years (for denominator) and periods (for num/per)
# Output includes census_year column
#
# This function extracts both state-level data and age-based demographic breakdowns
# from the same Excel sheet. Age data appears below state data in the sheet.
#
# @param ver: Profile version list from cfsr_profile_version() (optional - gets from global)
# @param as_of_date: Date from cfsr_profile_extract_asof_date() (optional - gets from global)
#
# @return: Tibble with entry rate structure including dimension columns:
#   - For state rows: dimension = "State", dimension_value = NA, state = [state name]
#   - For age rows: dimension = [header text], dimension_value = [age group], state = "National"
#   - state_rank and reporting_states are only populated for state rows (NA for age rows)
#   - Includes census_year column

process_entry_rate_indicator <- function(ver = NULL,
                                          as_of_date = NULL,
                                          jurisdiction_header = "52 Jurisdictions",
                                          state_code = NULL) {

  # Get from global env if not provided
  if (is.null(ver)) ver <- get("ver", envir = .GlobalEnv)
  if (is.null(as_of_date)) as_of_date <- get("as_of_date", envir = .GlobalEnv)

  # 1. Load sheet
  data_df_full <- find_cfsr_file(
    keyword = NULL,
    file_type = "excel",
    sheet_name = "Entry rates",
    state_code = state_code
  )

  # Keep only needed columns
  keep_cols <- c(1:16)
  data_df_full <- data_df_full[, keep_cols, drop = FALSE]

  # 2. Extract jurisdiction rows (states for national, localities for state files)
  data_df_states <- extract_relevant_rows(data_df_full, jurisdiction_header)

  # 3. Extract age rows (if available)
  # Age section ends when Race section begins
  age_data <- extract_dimension_rows(data_df_full, "Age", "Race")

  # 4. Extract race/ethnicity rows (if available)
  # Race section ends when jurisdiction section begins
  race_data <- extract_dimension_rows(data_df_full, "Race", jurisdiction_header)

  # 5. Extract metadata from state rows
  metadata <- data_df_states[1, ]
  years <- metadata[2:6] %>% as.numeric()
  periods <- metadata[7:11] %>% as.character()

  # Helper function to process rows (works for both jurisdiction and demographic data)
  process_rows <- function(data_rows, dimension_name = NULL, dimension_header = NULL) {
    # Skip metadata row (first row)
    data_clean <- data_rows[-1, ]

    # Rename columns
    den_cols <- paste0("den_", years)
    num_cols <- paste0("num_", periods)
    per_cols <- paste0("per_", periods)
    colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

    # Convert to numeric (except state column)
    data_clean <- data_clean %>%
      mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

    # Reshape child population (denominator by year)
    child_pop_long <- data_clean %>%
      pivot_longer(
        cols = starts_with("den"),
        names_to = "year",
        names_pattern = "den_(\\d{4})"
      ) %>%
      rename(denominator = value)

    # Reshape entry data (numerator/performance by period)
    data_long <- data_clean %>%
      pivot_longer(
        cols = starts_with("num") | starts_with("per"),
        names_to = c(".value", "period"),
        names_pattern = "(num|per)_(.+)"
      ) %>%
      rename(numerator = num, performance = per)

    # Create period-to-year mapping
    period_to_year <- tibble(
      period = periods,
      year = as.character(years)
    )

    # Join all data
    data_long <- data_long %>%
      left_join(period_to_year, by = "period") %>%
      left_join(child_pop_long, by = c("state", "year"))

    # Add dimension columns
    if (is.null(dimension_name)) {
      # Jurisdiction rows (states for national files, localities for state files)
      if (jurisdiction_header == "52 Jurisdictions") {
        # National file - state rows
        data_long <- data_long %>%
          mutate(
            dimension = "State",
            dimension_value = NA_character_
            # state column already has state names from Excel
          )
      } else {
        # State file - locality rows
        # Excel has locality names in 'state' column, need to swap
        state_name <- convert_state_code_to_name(toupper(state_code))
        data_long <- data_long %>%
          mutate(
            dimension = "Locality",
            dimension_value = state,  # Excel had locality names
            state = state_name  # Replace with actual state name
          )
      }
    } else {
      # Demographic rows (age, race, etc.)
      if (jurisdiction_header == "52 Jurisdictions") {
        # National file - demographics are at national level
        data_long <- data_long %>%
          mutate(
            dimension = dimension_header,
            dimension_value = state,
            state = "National"
          )
      } else {
        # State file - demographics are at state level
        state_name <- convert_state_code_to_name(toupper(state_code))
        data_long <- data_long %>%
          mutate(
            dimension = dimension_header,
            dimension_value = state,
            state = state_name
          )
      }
    }

    return(data_long)
  }

  # 6. Process state rows
  state_df <- process_rows(data_df_states, dimension_name = NULL)

  # 7. Process age rows (if available)
  age_df <- NULL
  if (!is.null(age_data)) {
    age_df <- process_rows(age_data$data, dimension_name = "age", dimension_header = age_data$header)
  }

  # 8. Process race/ethnicity rows (if available)
  race_df <- NULL
  if (!is.null(race_data)) {
    race_df <- process_rows(race_data$data, dimension_name = "race", dimension_header = race_data$header)
  }

  # 9. Combine all datasets
  combined_df <- bind_rows(state_df, age_df, race_df)

  # 10. Add metadata columns
  indicator_name <- get_indicator_name("Entry rates", "Foster care entry rate per 1,000")

  final_df <- combined_df %>%
    mutate(
      state = ifelse(state == "District of Columbia", "D.C.", state),
      census_year = as.numeric(year),
      indicator = indicator_name,
      # Fix period format: replace comma with underscore, remove whitespace
      # Handles "20AB,FY20" => "20AB_FY20" and "23AB_ FY23" => "23AB_FY23"
      # This ensures period matches the format used in observed/RSP data for proper joins
      period = gsub("\\s+", "", gsub(",", "_", period)),
      as_of_date = as_of_date,
      source = ver$source,
      period_meaningful = make_period_meaningful(period),
      profile_version = ver$profile_version
    )

  # 8. Rank states (only for state-level data)
  # Split into state and non-state data
  state_rows <- final_df %>% filter(dimension == "State")
  non_state_rows <- final_df %>% filter(dimension != "State")

  # Rank only state rows
  if (nrow(state_rows) > 0) {
    state_rows <- rank_states_by_performance(state_rows)
  }

  # For non-state rows, set rank columns to NA
  if (nrow(non_state_rows) > 0) {
    non_state_rows <- non_state_rows %>%
      mutate(
        state_rank = NA_integer_,
        reporting_states = NA_integer_
      )
  }

  # Recombine
  final_df <- bind_rows(state_rows, non_state_rows)

  # 9. Select final columns (includes census_year, dimension, dimension_value)
  final_df %>%
    select(state, indicator, dimension, dimension_value, period, period_meaningful,
           denominator, numerator, performance, state_rank, reporting_states,
           census_year, as_of_date, profile_version, source)
}
