# period_utils.R - Period format and validation utilities

# Note: validate_period() depends on discover_periods() from file_discovery.R

#' Validate period format
#'
#' Validates that period is in YYYY_MM format and optionally checks
#' if it exists for a given state in ShareFile
#'
#' @param period Period in YYYY_MM format (e.g., "2025_02")
#' @param state Optional state to check period availability
#' @return TRUE if valid, stops with error if invalid
#' @export
validate_period <- function(period, state = NULL) {
  # Check format
  if (!grepl("^\\d{4}_\\d{2}$", period)) {
    stop("Period must be in YYYY_MM format (e.g., '2025_02'), got: ", period,
         call. = FALSE)
  }

  # If state provided, check if period exists for that state
  if (!is.null(state)) {
    # Requires discover_periods() from file_discovery.R
    available <- discover_periods(state)
    if (!period %in% available) {
      stop("Period '", period, "' not found for state '", state, "'. ",
           "Available periods: ", paste(available, collapse = ", "),
           call. = FALSE)
    }
  }

  return(TRUE)
}

#' Validate source type
#'
#' Validates that source is one of the valid CFSR data source types
#'
#' @param source Source type (national, rsp, observed, state, or all)
#' @return TRUE if valid, stops with error if invalid
#' @export
validate_source <- function(source) {
  valid_sources <- c("national", "rsp", "observed", "state", "all")

  if (!tolower(source) %in% valid_sources) {
    stop("Source must be one of: ", paste(valid_sources, collapse = ", "),
         ". Got: ", source,
         call. = FALSE)
  }

  return(TRUE)
}
