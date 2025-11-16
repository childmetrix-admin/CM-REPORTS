# Title:          CFSR Profile Configuration
#                 Central configuration and discovery for all profile processing

# Purpose:        Define paths, discover available data, validate combinations

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
source("D:/repo_childmetrix/utilities-core/loader.R")

#####################################
# PATH CONFIGURATION ----
#####################################

# Base paths
CFSR_BASE_DIR <- "D:/repo_childmetrix/cfsr-profile"
CFSR_CODE_DIR <- file.path(CFSR_BASE_DIR, "code")
CFSR_DATA_DIR <- file.path(CFSR_BASE_DIR, "data")
CFSR_SHAREFILE_BASE <- "S:/Shared Folders"

# Function paths
CFSR_FUNCTIONS_DIR <- file.path(CFSR_CODE_DIR, "functions")

# Output paths
CFSR_PROCESSED_DIR <- file.path(CFSR_DATA_DIR, "processed")
CFSR_APP_DATA_DIR <- file.path(CFSR_DATA_DIR, "app_data")

#####################################
# DISCOVERY FUNCTIONS ----
#####################################

#' Discover available states
#'
#' Scans ShareFile for state folders with CFSR uploads
#'
#' @return Character vector of lowercase state codes
#' @export
discover_states <- function() {
  if (!dir.exists(CFSR_SHAREFILE_BASE)) {
    warning("ShareFile not accessible: ", CFSR_SHAREFILE_BASE)
    return(character(0))
  }

  state_dirs <- list.dirs(CFSR_SHAREFILE_BASE, recursive = FALSE, full.names = FALSE)

  # Filter for 2-letter state codes
  states <- state_dirs[nchar(state_dirs) == 2]

  # Only return states that have cfsr/uploads folder
  states_with_cfsr <- character(0)
  for (state in states) {
    cfsr_path <- file.path(CFSR_SHAREFILE_BASE, state, "cfsr/uploads")
    if (dir.exists(cfsr_path)) {
      states_with_cfsr <- c(states_with_cfsr, state)
    }
  }

  return(sort(tolower(states_with_cfsr)))
}

#' Discover available periods for a state
#'
#' Scans ShareFile uploads folder for period folders
#'
#' @param state Lowercase 2-letter state code
#' @return Character vector of periods in YYYY_MM format
#' @export
discover_periods <- function(state) {
  uploads_path <- file.path(CFSR_SHAREFILE_BASE, state, "cfsr/uploads")

  if (!dir.exists(uploads_path)) {
    warning("No uploads folder for state: ", state)
    return(character(0))
  }

  period_dirs <- list.dirs(uploads_path, recursive = FALSE, full.names = FALSE)

  # Filter for YYYY_MM format
  periods <- period_dirs[grepl("^\\d{4}_\\d{2}$", period_dirs)]

  return(sort(periods, decreasing = TRUE))
}

#' Discover available data sources for a state/period
#'
#' Checks which data files are available
#'
#' @param state Lowercase 2-letter state code
#' @param period Period in YYYY_MM format
#' @return Named logical vector (national, rsp, state)
#' @export
discover_sources <- function(state, period) {
  uploads_path <- file.path(CFSR_SHAREFILE_BASE, state, "cfsr/uploads", period)

  if (!dir.exists(uploads_path)) {
    return(c(national = FALSE, rsp = FALSE, state = FALSE))
  }

  files <- list.files(uploads_path, full.names = FALSE, ignore.case = TRUE)

  # Check for each source type
  sources <- c(
    national = any(grepl("National.*\\.xlsx?$", files, ignore.case = TRUE)),
    rsp = any(grepl("adobe_to_accessible_text\\.txt$", files, ignore.case = TRUE)),
    state = any(grepl("State.*\\.xlsx?$", files, ignore.case = TRUE))
  )

  return(sources)
}

#####################################
# VALIDATION FUNCTIONS ----
#####################################

#' Validate state code
#'
#' @param state State code to validate
#' @return TRUE if valid, stops with error if invalid
#' @export
validate_state <- function(state) {
  available <- discover_states()

  if (length(available) == 0) {
    stop("No states found in ShareFile. Check S:/ drive access.")
  }

  if (!tolower(state) %in% available) {
    stop("State '", state, "' not found. Available states: ", paste(available, collapse = ", "))
  }

  return(TRUE)
}

#' Validate period
#'
#' @param period Period in YYYY_MM format
#' @param state Optional state to check period availability
#' @return TRUE if valid, stops with error if invalid
#' @export
validate_period <- function(period, state = NULL) {
  # Check format
  if (!grepl("^\\d{4}_\\d{2}$", period)) {
    stop("Period must be in YYYY_MM format (e.g., '2025_02'), got: ", period)
  }

  # If state provided, check if period exists for that state
  if (!is.null(state)) {
    available <- discover_periods(state)
    if (!period %in% available) {
      stop("Period '", period, "' not found for state '", state, "'. ",
           "Available periods: ", paste(available, collapse = ", "))
    }
  }

  return(TRUE)
}

#' Validate source
#'
#' @param source Source type (national, rsp, state, or all)
#' @return TRUE if valid, stops with error if invalid
#' @export
validate_source <- function(source) {
  valid_sources <- c("national", "rsp", "state", "all")

  if (!tolower(source) %in% valid_sources) {
    stop("Source must be one of: ", paste(valid_sources, collapse = ", "),
         ". Got: ", source)
  }

  return(TRUE)
}

#####################################
# SETUP FUNCTIONS ----
#####################################

#' Set up environment for profile processing
#'
#' @param state Lowercase 2-letter state code
#' @param period Period in YYYY_MM format
#' @return List with configuration settings
#' @export
setup_profile_env <- function(state, period) {
  # Validate inputs
  validate_state(state)
  validate_period(period, state)

  # Create configuration list
  config <- list(
    state = tolower(state),
    period = period,
    sharefile_base = file.path(CFSR_SHAREFILE_BASE, state, "cfsr/uploads", period),
    processed_base = file.path(CFSR_PROCESSED_DIR, state, period),
    app_data_base = file.path(CFSR_APP_DATA_DIR, state),
    run_date = Sys.Date()
  )

  # Set global variables for compatibility with existing scripts
  assign("state_code", config$state, envir = .GlobalEnv)
  assign("profile_period", config$period, envir = .GlobalEnv)

  message("Configuration set for: ", toupper(state), " - ", period)
  message("ShareFile: ", config$sharefile_base)
  message("Output: ", config$processed_base)

  return(config)
}

#####################################
# SUMMARY FUNCTIONS ----
#####################################

#' Print available data summary
#'
#' @export
print_available_data <- function() {
  cat("\n=== CFSR Profile Data Availability ===\n\n")

  states <- discover_states()

  if (length(states) == 0) {
    cat("No states found. Check ShareFile access.\n")
    return(invisible(NULL))
  }

  for (state in states) {
    cat(toupper(state), ":\n")
    periods <- discover_periods(state)

    if (length(periods) == 0) {
      cat("  No periods found\n\n")
      next
    }

    for (period in periods) {
      sources <- discover_sources(state, period)
      available <- names(sources)[sources]

      if (length(available) > 0) {
        cat("  ", period, ": ", paste(available, collapse = ", "), "\n", sep = "")
      }
    }
    cat("\n")
  }

  invisible(NULL)
}

#####################################
# INITIALIZATION ----
#####################################

message("CFSR Profile configuration loaded")
message("Base directory: ", CFSR_BASE_DIR)
message("ShareFile base: ", CFSR_SHAREFILE_BASE)
message("\nRun print_available_data() to see available data")
