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
#' @return Named logical vector (national, rsp, observed, state)
#' @export
discover_sources <- function(state, period) {
  uploads_path <- file.path(CFSR_SHAREFILE_BASE, state, "cfsr/uploads", period)

  if (!dir.exists(uploads_path)) {
    return(c(national = FALSE, rsp = FALSE, observed = FALSE, state = FALSE))
  }

  files <- list.files(uploads_path, full.names = FALSE, ignore.case = TRUE)

  # Check for each source type
  sources <- c(
    national = any(grepl("National.*\\.xlsx?$", files, ignore.case = TRUE)),
    # RSP: Check for accessible text file OR PDF (PDF will be auto-converted)
    rsp = any(grepl("adobe_to_accessible_text\\.txt$", files, ignore.case = TRUE)) ||
          any(grepl("\\.pdf$", files, ignore.case = TRUE)),
    # Observed: Check for PDF (same source as RSP, page 4)
    observed = any(grepl("\\.pdf$", files, ignore.case = TRUE)),
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
#' @param source Source type (national, rsp, observed, state, or all)
#' @return TRUE if valid, stops with error if invalid
#' @export
validate_source <- function(source) {
  valid_sources <- c("national", "rsp", "observed", "state", "all")

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

#' Initialize common global variables for CFSR extraction scripts
#'
#' Centralizes common setup logic shared across profile_rsp.R, profile_observed.R,
#' and profile_national.R. This function handles:
#' - Library loading (utilities-core, shared CFSR functions)
#' - Folder setup (via setup_cfsr_folders)
#' - Global variable assignment (folder_date, commitment, my_setup)
#' - PDF discovery and metadata extraction (RSP and Observed only)
#'
#' This function is called by run_profile.R before sourcing extraction scripts.
#'
#' @param state Lowercase 2-letter state code (e.g., "md")
#' @param period Period in YYYY_MM format (e.g., "2025_02")
#' @param source Source type: "national", "rsp", "observed", or "state"
#' @return Invisible NULL (all outputs assigned to global environment)
#' @export
initialize_common_globals <- function(state, period, source) {

  # Source core utilities (if not already loaded)
  if (!exists("r_load_packages")) {
    source("D:/repo_childmetrix/utilities-core/loader.R")
  }

  # Source shared CFSR functions
  shared_functions <- file.path(CFSR_FUNCTIONS_DIR, "functions_cfsr_profile_shared.R")
  source(shared_functions)

  # Set up CFSR folders (assigns folder paths to global environment)
  my_setup <- setup_cfsr_folders(period, state, assign_globals = TRUE)

  # Set common global variables
  folder_date <- paste0(state, "_", period)
  commitment <- "cfsr profile"

  # Assign configuration to global environment
  assign("folder_date", folder_date, envir = .GlobalEnv)
  assign("commitment", commitment, envir = .GlobalEnv)
  assign("my_setup", my_setup, envir = .GlobalEnv)

  # PDF discovery (only for RSP and Observed sources)
  if (source %in% c("rsp", "observed")) {
    # Get folder_uploads from global environment (set by setup_cfsr_folders)
    folder_uploads <- get("folder_uploads", envir = .GlobalEnv)

    # Discover PDF files
    pdf_files <- list.files(folder_uploads,
                           pattern = "\\.pdf$",
                           full.names = TRUE,
                           ignore.case = TRUE)

    if (length(pdf_files) == 0) {
      stop("No PDF files found in: ", folder_uploads, call. = FALSE)
    }

    # Use first PDF found
    pdf_path <- pdf_files[1]
    message("PDF discovered: ", basename(pdf_path))

    # Extract metadata from PDF filename
    pdf_metadata <- extract_pdf_metadata(pdf_path)

    # Assign to global environment
    assign("pdf_path", pdf_path, envir = .GlobalEnv)
    assign("pdf_metadata", pdf_metadata, envir = .GlobalEnv)
  }

  # National source uses Excel files - no PDF discovery needed

  invisible(NULL)
}

#' Set up CFSR folder structure (legacy, use setup_profile_env instead)
#'
#' This function maintains backward compatibility with existing scripts
#'
#' @param profile_period Period in YYYY_MM format
#' @param state_code Lowercase 2-letter state code
#' @param assign_globals Assign folder paths to global environment (default: TRUE)
#' @param base_data_dir Base data directory (default: CFSR_DATA_DIR)
#' @return List with folder paths
#' @export
setup_cfsr_folders <- function(profile_period,
                               state_code,
                               assign_globals = TRUE,
                               base_data_dir = NULL) {

  # Use default base_data_dir if not provided
  if (is.null(base_data_dir)) {
    base_data_dir <- CFSR_DATA_DIR
  }

  # Validate inputs
  if (missing(profile_period) || is.null(profile_period)) {
    stop("profile_period is required (e.g., '2025_02')")
  }
  if (missing(state_code) || is.null(state_code)) {
    stop("state_code is required (e.g., 'md')")
  }

  # Normalize
  profile_period <- toupper(profile_period)
  state_code <- tolower(state_code)

  # Build folder paths
  folder_uploads <- file.path(CFSR_SHAREFILE_BASE, state_code, "cfsr/uploads", profile_period)
  folder_processed <- file.path(base_data_dir, "processed", state_code, profile_period)
  folder_app_data <- file.path(base_data_dir, "app_data", state_code)
  folder_raw <- folder_uploads  # Alias for backward compatibility

  # Check if uploads folder exists
  if (!dir.exists(folder_uploads)) {
    stop("Uploads folder does not exist: ", folder_uploads,
         "\n\nPlease upload files to ShareFile at:",
         "\n  S:/Shared Folders/", state_code, "/cfsr/uploads/", profile_period, "/",
         "\n\nOr check your state_code and profile_period values.",
         call. = FALSE)
  }

  # Create processed folders if they don't exist
  if (!dir.exists(folder_processed)) {
    dir.create(folder_processed, recursive = TRUE)
    message("Created processed folder: ", folder_processed)
  }

  if (!dir.exists(folder_app_data)) {
    dir.create(folder_app_data, recursive = TRUE)
    message("Created app_data folder: ", folder_app_data)
  }

  # Return configuration list
  config <- list(
    folder_uploads = folder_uploads,
    folder_raw = folder_raw,
    folder_processed = folder_processed,
    folder_app_data = folder_app_data,
    state_code = state_code,
    profile_period = profile_period
  )

  # Optionally assign to global environment
  if (assign_globals) {
    assign("folder_uploads", folder_uploads, envir = .GlobalEnv)
    assign("folder_raw", folder_raw, envir = .GlobalEnv)
    assign("folder_processed", folder_processed, envir = .GlobalEnv)
    assign("folder_app_data", folder_app_data, envir = .GlobalEnv)
    assign("state_code", state_code, envir = .GlobalEnv)
    assign("profile_period", profile_period, envir = .GlobalEnv)
  }

  return(invisible(config))
}

#####################################
# METADATA EXTRACTION ----
#####################################

#' Extract shared metadata for CFSR profile processing
#'
#' This function extracts metadata that is common to both national and RSP processing:
#' - Profile version (Month YYYY)
#' - AFCARS/NCANDS as-of date
#' - Source citation
#'
#' @return List with profile version info and as_of_date
#' @export
extract_shared_metadata <- function() {
  # Load CFSR profile functions if not already loaded
  nat_functions <- file.path(CFSR_FUNCTIONS_DIR, "functions_cfsr_profile_nat.R")
  if (!exists("cfsr_profile_version")) {
    source(nat_functions)
  }

  # Profile version from National Excel file
  ver <- cfsr_profile_version()

  # AFCARS/NCANDS submission date - extract from National file
  data_df_temp <- find_cfsr_file(keyword = "National",
                                 file_type = "excel",
                                 sheet_name = "Entry rates")
  asof <- cfsr_profile_extract_asof_date(data_df_temp)

  # Combine into single metadata object
  metadata <- list(
    profile_version = ver$profile_version,
    profile_month = ver$month,
    profile_year = ver$year,
    as_of_date = asof$as_of_date,
    source = ver$source
  )

  return(metadata)
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
