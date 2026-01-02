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

extract_relevant_rows <- function(data_df) {
  # Identify the first row whose second column matches one of the period patterns.
  # The pattern matches:
  # - A 4-digit year (e.g., "2024")
  # - Standard periods: "YYAYYB" or "YYBYYA" (e.g., "19A19B" or "19B20A")
  # - Maltreatment: "YYAB,FYYY" (e.g., "20AB,FY20")
  # - Recurrence: "FYYY-YY" (e.g., "FY20-21")
  period_pattern <- "^(?:[0-9]{4}|[0-9]{2}[AB][0-9]{2}[AB]|[0-9]{2}AB,FY[0-9]{2}|FY[0-9]{2}-[0-9]{2})$"
  period_row_index <- which(grepl(period_pattern, data_df[[2]]))[1]

  # Identify the block of state rows (should always be 52 rows: 50 states, D.C., and PR)
  # Find the first row with "Alabama" in the first column...
  state_start_index <- which(data_df[[1]] == "Alabama")[1]
  # ...and then the first row (after Alabama) with "Wyoming"
  state_end_index <- which(data_df[[1]] == "Wyoming")
  state_end_index <- state_end_index[state_end_index > state_start_index][1]

  # Combine the row indices: the period row and the block of state rows
  rows_to_keep <- c(period_row_index, seq(from = state_start_index, to = state_end_index))

  # Subset the data frame to keep only the identified rows and return the result
  return(data_df[rows_to_keep, ])
}

# Process standard CFSR indicator (den/num/per structure)
########################################

# Handles 5 of 6 indicators: Re-Entry, Perm in 12 (entries),
# Perm in 12 (12-23 mos), Perm in 12 (24+ mos), Placement Stability
#
# (Entry Rate is special - has years/census_year - use process_entry_rate_indicator)
#
# @param sheet_name: Excel worksheet name (e.g., "Reentry to FC")
# @param indicator_name: Full indicator display name for output
# @param keep_cols: Column range to select (default c(1:10))
# @param period_cols: Column indices for period labels (default 2:4)
# @param ver: Profile version list from cfsr_profile_version() (optional - gets from global)
# @param as_of_date: Date from cfsr_profile_extract_asof_date() (optional - gets from global)
#
# @return: Tibble with standardized indicator structure

process_standard_indicator <- function(sheet_name,
                                       indicator_name = NULL,
                                       keep_cols = c(1:10),
                                       period_cols = 2:4,
                                       ver = NULL,
                                       as_of_date = NULL) {

  # Get indicator name from dictionary if not provided
  if (is.null(indicator_name)) {
    indicator_name <- get_indicator_name(sheet_name)
  }

  # Get from global env if not provided
  if (is.null(ver)) ver <- get("ver", envir = .GlobalEnv)
  if (is.null(as_of_date)) as_of_date <- get("as_of_date", envir = .GlobalEnv)

  # 1. Load sheet
  data_df <- find_cfsr_file(
    keyword = "National",
    file_type = "excel",
    sheet_name = sheet_name
  )

  # 2. Select columns and rows
  data_df <- data_df[, keep_cols, drop = FALSE]
  data_df <- extract_relevant_rows(data_df)

  # 3. Extract metadata
  metadata <- data_df[1, ]
  periods <- metadata[period_cols] %>% as.character()

  # Debug: Show what we extracted
  # message("DEBUG - Raw periods extracted from columns ", paste(period_cols, collapse = ", "), ":")
  # message(paste(periods, collapse = " | "))

  # Clean periods: remove NA, empty strings, and trim whitespace
  periods <- trimws(periods)
  # Only filter out actual NA and truly empty strings, not things that look like "NA"
  periods_before <- periods
  periods <- periods[!is.na(periods) & nchar(periods) > 0]

  # message("DEBUG - Periods after cleaning (removed ", length(periods_before) - length(periods), " invalid):")
  # message(paste(periods, collapse = " | "))

  # Validate we have periods
  if (length(periods) == 0) {
    stop("No valid periods found in columns ", paste(period_cols, collapse = ", "),
         ". Raw values were: ", paste(periods_before, collapse = ", "),
         ". Check that the Excel sheet has period labels in the expected columns.")
  }

  data_clean <- data_df[-1, ]

  # 4. Rename columns dynamically based on actual number of periods
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

  # Build column names - only use what we actually have
  new_cols <- c("state", den_cols, num_cols, per_cols)

  # Check for duplicates before assigning
  if (any(duplicated(new_cols))) {
    stop("Duplicate column names detected: ",
         paste(new_cols[duplicated(new_cols)], collapse = ", "),
         ". Periods extracted: ", paste(periods, collapse = ", "))
  }

  colnames(data_clean) <- new_cols

  # 5. Convert to numeric
  data_clean <- data_clean %>%
    mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

  # 6. Reshape wide to long
  # Pattern matches multiple period formats:
  #   - Standard: 19A19B, 19B20A (YYAYYB, YYBZZA)
  #   - Maltreatment: 20AB,FY20 (YYAB,FYYY)
  #   - Recurrence: FY20-21 (FYYY-YY)
  data_long <- data_clean %>%
    pivot_longer(
      cols = starts_with("den") | starts_with("num") | starts_with("per"),
      names_to = c(".value", "period"),
      names_pattern = "(den|num|per)_(.+)"
    ) %>%
    rename(denominator = den, numerator = num, performance = per)

  # 7. Add metadata columns
  final_df <- data_long %>%
    mutate(
      state = ifelse(state == "District of Columbia", "D.C.", state),
      denominator = as.numeric(denominator),
      numerator = as.numeric(numerator),
      performance = as.numeric(performance),
      indicator = indicator_name,
      as_of_date = as_of_date,
      source = ver$source,
      period_meaningful = make_period_meaningful(period),
      profile_version = ver$profile_version
    )

  # 8. Rank states
  final_df <- rank_states_by_performance(final_df)

  # 9. Select final columns (no census_year for standard indicators)
  final_df %>%
    select(state, indicator, period, period_meaningful, denominator, numerator,
           performance, state_rank, reporting_states, as_of_date, profile_version, source)
}

# Process Entry Rate indicator (special case with years)
########################################

# Entry Rate is unique: has both years (for denominator) and periods (for num/per)
# Output includes census_year column
#
# @param ver: Profile version list from cfsr_profile_version() (optional - gets from global)
# @param as_of_date: Date from cfsr_profile_extract_asof_date() (optional - gets from global)
#
# @return: Tibble with entry rate structure (includes census_year)

process_entry_rate_indicator <- function(ver = NULL, as_of_date = NULL) {

  # Get from global env if not provided
  if (is.null(ver)) ver <- get("ver", envir = .GlobalEnv)
  if (is.null(as_of_date)) as_of_date <- get("as_of_date", envir = .GlobalEnv)

  # 1. Load sheet
  data_df <- find_cfsr_file(
    keyword = "National",
    file_type = "excel",
    sheet_name = "Entry rates"
  )

  # 2. Select columns and rows
  keep_cols <- c(1:16)
  data_df <- data_df[, keep_cols, drop = FALSE]
  data_df <- extract_relevant_rows(data_df)

  # 3. Extract metadata
  metadata <- data_df[1, ]
  years <- metadata[2:6] %>% as.numeric()
  periods <- metadata[7:11] %>% as.character()
  data_clean <- data_df[-1, ]

  # 4. Rename columns
  den_cols <- paste0("den_", years)
  num_cols <- paste0("num_", periods)
  per_cols <- paste0("per_", periods)
  colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

  # 5. Convert to numeric
  data_clean <- data_clean %>%
    mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

  # 6. Reshape child population (denominator by year)
  child_pop_long <- data_clean %>%
    pivot_longer(
      cols = starts_with("den"),
      names_to = "year",
      names_pattern = "den_(\\d{4})"
    ) %>%
    rename(denominator = value)

  # 7. Reshape entry data (numerator/performance by period)
  # Pattern matches multiple period formats (flexible for future changes)
  data_long <- data_clean %>%
    pivot_longer(
      cols = starts_with("num") | starts_with("per"),
      names_to = c(".value", "period"),
      names_pattern = "(num|per)_(.+)"
    ) %>%
    rename(numerator = num, performance = per)

  # 8. Create period-to-year mapping
  period_to_year <- tibble(
    period = periods,
    year = as.character(years)
  )

  # 9. Join all data
  data_long <- data_long %>%
    left_join(period_to_year, by = "period")

  final_df <- data_long %>%
    left_join(child_pop_long, by = c("state", "year"))

  # 10. Add metadata columns
  indicator_name <- get_indicator_name("Entry rates", "Foster care entry rate per 1,000")

  final_df <- final_df %>%
    mutate(
      state = ifelse(state == "District of Columbia", "D.C.", state),
      census_year = as.numeric(year),
      indicator = indicator_name,
      as_of_date = as_of_date,
      source = ver$source,
      period_meaningful = make_period_meaningful(period),
      profile_version = ver$profile_version
    )

  # 11. Rank states
  final_df <- rank_states_by_performance(final_df)

  # 12. Select final columns (includes census_year)
  final_df %>%
    select(state, indicator, period, period_meaningful, denominator, numerator,
           performance, state_rank, reporting_states, census_year, as_of_date, profile_version, source)
}
