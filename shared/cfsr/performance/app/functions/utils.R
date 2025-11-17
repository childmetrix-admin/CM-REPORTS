# utils.R - Utility functions for the Shiny app

#' Get available profiles for a state
#'
#' @param state Two-letter state code (e.g., "MD", "KY")
#' @return Character vector of available profile periods (e.g., c("2025_02", "2024_08"))
get_available_profiles <- function(state) {
  # Convert state to uppercase
  state <- toupper(state)

  # Build file path in shared location
  data_dir <- "data"  # Relative to app directory

  # List all files matching pattern: {STATE}_cfsr_indicators_{PERIOD}.rds
  pattern <- paste0("^", state, "_cfsr_indicators_([0-9]{4}_[0-9]{2})\\.rds$")
  all_files <- list.files(data_dir, pattern = pattern)

  # Extract periods from filenames
  if (length(all_files) == 0) {
    return(character(0))
  }

  periods <- gsub(paste0(state, "_cfsr_indicators_(.*)\\.rds"), "\\1", all_files)

  # Sort in descending order (most recent first)
  periods <- sort(periods, decreasing = TRUE)

  return(periods)
}

#' Load CFSR data based on state and profile parameters
#'
#' @param state Two-letter state code (e.g., "MD", "KY")
#' @param profile Profile period (e.g., "2025_02", "2024_08", or "latest")
#' @return Data frame with CFSR indicators
load_cfsr_data <- function(state, profile = "latest") {
  # Convert state to uppercase
  state <- toupper(state)

  # Build file path in shared location
  data_dir <- "data"  # Relative to app directory

  if (profile == "latest") {
    filename <- paste0(state, "_cfsr_indicators_latest.rds")
  } else {
    filename <- paste0(state, "_cfsr_indicators_", profile, ".rds")
  }

  file_path <- file.path(data_dir, filename)

  # Check if file exists
  if (!file.exists(file_path)) {
    # Try fallback to latest
    fallback_path <- file.path(data_dir, paste0(state, "_cfsr_indicators_latest.rds"))
    if (file.exists(fallback_path)) {
      message("Profile '", profile, "' not found for ", state, ". Using latest.")
      file_path <- fallback_path
    } else {
      stop("Data file not found: ", file_path, "\nAlso checked: ", fallback_path)
    }
  }

  # Load and return data
  message("Loading data from: ", file_path)
  data <- readRDS(file_path)
  return(data)
}

#' Extract state code from URL path
#'
#' @param url_path Full URL path (e.g., "/md/cfsr-indicators")
#' @return Two-letter state code (e.g., "MD") or NULL
extract_state_from_path <- function(url_path) {
  if (is.null(url_path) || url_path == "") return(NULL)

  # Extract first path segment after leading slash
  # Examples: "/md/cfsr-indicators" -> "md"
  #           "/ca/" -> "ca"
  matches <- regmatches(url_path, regexpr("^/([a-zA-Z]{2})", url_path))

  if (length(matches) > 0) {
    state_code <- gsub("^/", "", matches[1])
    return(toupper(state_code))
  }

  return(NULL)
}

#' Convert state code to full state name
#'
#' @param state_code Two-letter state code (e.g., "MD")
#' @param state_codes Named vector of state codes (from global.R)
#' @return Full state name (e.g., "Maryland") or NULL
convert_state_code <- function(state_code, state_codes) {
  if (is.null(state_code)) return(NULL)

  state_code <- toupper(state_code)

  if (state_code %in% names(state_codes)) {
    return(state_codes[[state_code]])
  }

  return(NULL)
}

#' Get state from URL or default to Maryland
#'
#' @param session Shiny session object
#' @param state_codes Named vector of state codes
#' @return Full state name
get_state_from_url <- function(session, state_codes) {
  # First try to get from query string parameter (?state=ky)
  query <- parseQueryString(session$clientData$url_search)
  state_code <- query$state

  # If not in query string, try URL path
  if (is.null(state_code) || state_code == "") {
    url_path <- session$clientData$url_pathname
    state_code <- extract_state_from_path(url_path)
  }

  state_name <- convert_state_code(state_code, state_codes)

  # Default to Maryland if not found
  if (is.null(state_name)) {
    state_name <- "Maryland"
  }

  return(state_name)
}

#' Format performance value for display
#'
#' @param value Numeric value
#' @param decimal_precision Number of decimal places
#' @param scale Scaling factor (e.g., 1000, 100)
#' @return Formatted string
format_performance <- function(value, decimal_precision = 1, scale = 1) {
  if (is.na(value)) return("N/A")

  # Scale is already applied in the data, so just format
  formatted <- format(round(value, decimal_precision), nsmall = decimal_precision)

  return(trimws(formatted))
}

#' Create indicator ID for navigation
#'
#' @param indicator_name Full indicator name
#' @return Sanitized ID (e.g., "entry_rate")
create_indicator_id <- function(indicator_name) {
  id <- tolower(indicator_name)
  id <- gsub("[^a-z0-9]+", "_", id)
  id <- gsub("^_|_$", "", id)
  return(id)
}

#' Get navigation info for an indicator
#'
#' @param current_indicator_name Current indicator name
#' @param app_data Full app data
#' @return List with previous/next tab names and labels
get_indicator_navigation <- function(current_indicator_name, app_data) {
  # Get ordered list of indicators sorted by indicator_sort
  all_indicators <- app_data %>%
    distinct(indicator, indicator_short, indicator_sort) %>%
    arrange(indicator_sort)

  # Map indicator names to tab names (hardcoded based on app.R)
  indicator_to_tab <- c(
    "Foster care entry rate (entries / 1,000 children)" = "entry_rate",
    "Maltreatment in care (victimizations / 100,000 days in care)" = "maltreatment",
    "Permanency in 12 months for children entering care" = "perm12_entries",
    "Permanency in 12 months for children in care 12-23 months" = "perm12_12_23",
    "Permanency in 12 months for children in care 24 months or more" = "perm12_24",
    "Placement stability (moves / 1,000 days in care)" = "placement",
    "Reentry to foster care within 12 months" = "reentry",
    "Maltreatment recurrence within 12 months" = "recurrence"
  )

  # Find current position
  current_idx <- which(all_indicators$indicator == current_indicator_name)

  nav <- list(
    prev_tab = NULL,
    prev_label = NULL,
    next_tab = NULL,
    next_label = NULL
  )

  # Get previous
  if (length(current_idx) > 0 && current_idx > 1) {
    prev_indicator <- all_indicators$indicator[current_idx - 1]
    nav$prev_tab <- indicator_to_tab[[prev_indicator]]
    nav$prev_label <- all_indicators$indicator_short[current_idx - 1]
  }

  # Get next
  if (length(current_idx) > 0 && current_idx < nrow(all_indicators)) {
    next_indicator <- all_indicators$indicator[current_idx + 1]
    nav$next_tab <- indicator_to_tab[[next_indicator]]
    nav$next_label <- all_indicators$indicator_short[current_idx + 1]
  }

  return(nav)
}
