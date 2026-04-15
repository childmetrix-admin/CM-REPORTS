# utils.R - Utility functions for the Shiny app
# Supports local RDS files or Azure Blob (CM_DATA_SOURCE=azure) for processed data.

.cm_is_azure_data <- function() {
  identical(Sys.getenv("CM_DATA_SOURCE", "sharefile"), "azure")
}

.cm_azure_list_blob_names <- function(prefix) {
  if (!requireNamespace("AzureStor", quietly = TRUE)) {
    stop("AzureStor package required when CM_DATA_SOURCE=azure")
  }
  ep <- AzureStor::blob_endpoint(
    Sys.getenv("AZURE_BLOB_ENDPOINT"),
    key = Sys.getenv("AZURE_STORAGE_KEY")
  )
  cont <- AzureStor::blob_container(
    ep,
    Sys.getenv("AZURE_BLOB_CONTAINER_PROCESSED", "processed")
  )
  b <- AzureStor::list_blobs(cont, prefix = prefix)
  b$name
}

.cm_azure_read_rds <- function(blob_path) {
  if (!requireNamespace("AzureStor", quietly = TRUE)) {
    stop("AzureStor package required when CM_DATA_SOURCE=azure")
  }
  ep <- AzureStor::blob_endpoint(
    Sys.getenv("AZURE_BLOB_ENDPOINT"),
    key = Sys.getenv("AZURE_STORAGE_KEY")
  )
  cont <- AzureStor::blob_container(
    ep,
    Sys.getenv("AZURE_BLOB_CONTAINER_PROCESSED", "processed")
  )
  local_tmp <- file.path(tempdir(), basename(blob_path))
  AzureStor::download_blob(cont, blob_path, local_tmp, overwrite = TRUE)
  data <- readRDS(local_tmp)
  unlink(local_tmp)
  data
}

#' Get available profiles for a state and profile type
#'
#' @param state Two-letter state code (e.g., "MD", "KY") - ignored for national type
#' @param type Profile type: "national", "rsp", or "state"
#' @return Character vector of available profile periods (e.g., c("2025_02", "2024_08"))
get_available_profiles <- function(state, type = "national") {
  # Convert state to uppercase
  state <- toupper(state)

  # Validate type
  valid_types <- c("national", "rsp", "observed", "state")
  if (!type %in% valid_types) {
    warning("Invalid profile type '", type, "'. Using 'national'.")
    type <- "national"
  }

  # Azure Blob: list processed container (same layout as build_rds_path in paths.R)
  if (.cm_is_azure_data()) {
    if (type == "national") {
      blobs <- .cm_azure_list_blob_names("rds/national/")
      ok <- grepl("^rds/national/cfsr_profile_national_[0-9]{4}_[0-9]{2}\\.rds$", blobs)
      if (!any(ok)) return(character(0))
      periods <- sub(
        "^cfsr_profile_national_([0-9]{4}_[0-9]{2})\\.rds$",
        "\\1",
        basename(blobs[ok])
      )
    } else {
      prefix <- paste0("rds/", tolower(state), "/")
      blobs <- .cm_azure_list_blob_names(prefix)
      rx <- paste0(
        "^rds/", tolower(state), "/[0-9]{4}_[0-9]{2}/",
        state, "_cfsr_profile_", type, "_[0-9]{4}_[0-9]{2}\\.rds$"
      )
      matching <- blobs[grepl(rx, blobs)]
      if (length(matching) == 0) return(character(0))
      periods <- vapply(matching, function(b) {
        bn <- basename(b)
        sub(
          paste0("^", state, "_cfsr_profile_", type, "_"),
          "",
          sub("\\.rds$", "", bn)
        )
      }, character(1))
      periods <- unique(periods)
    }
    return(sort(periods, decreasing = TRUE))
  }

  # Detect monorepo root and build path to data directory
  detect_root <- function() {
    current <- getwd()
    while (current != dirname(current)) {
      if (file.exists(file.path(current, "CLAUDE.md")) ||
          file.exists(file.path(current, ".git"))) {
        return(current)
      }
      current <- dirname(current)
    }
    return(Sys.getenv("CM_REPORTS_ROOT", "/app"))
  }
  data_dir <- file.path(detect_root(), "domains/cfsr/data/rds")

  # New hierarchical structure:
  # - national: domains/cfsr/data/rds/national/cfsr_profile_national_{PERIOD}.rds
  # - state-specific: domains/cfsr/data/rds/{state}/{period}/{STATE}_cfsr_profile_{type}_{period}.rds

  if (type == "national") {
    # National files in national/ subdirectory
    national_dir <- file.path(data_dir, "national")
    if (!dir.exists(national_dir)) return(character(0))

    pattern <- paste0("^cfsr_profile_national_([0-9]{4}_[0-9]{2})\\.rds$")
    all_files <- list.files(national_dir, pattern = pattern)
    if (length(all_files) == 0) return(character(0))
    periods <- gsub("cfsr_profile_national_(.*)\\.rds", "\\1", all_files)
  } else {
    # State-specific files in state subdirectory
    state_dir <- file.path(data_dir, tolower(state))

    # Check if state directory exists
    if (!dir.exists(state_dir)) return(character(0))

    # Get all period subdirectories (e.g., "2025_02", "2024_08")
    period_dirs <- list.dirs(state_dir, full.names = FALSE, recursive = FALSE)
    period_dirs <- period_dirs[grepl("^[0-9]{4}_[0-9]{2}$", period_dirs)]

    if (length(period_dirs) == 0) return(character(0))

    # Filter to periods where the file actually exists
    periods <- character(0)
    for (period in period_dirs) {
      expected_file <- file.path(state_dir, period,
                                paste0(state, "_cfsr_profile_", type, "_", period, ".rds"))
      if (file.exists(expected_file)) {
        periods <- c(periods, period)
      }
    }

    if (length(periods) == 0) return(character(0))
  }

  # Sort in descending order (most recent first)
  periods <- sort(periods, decreasing = TRUE)

  return(periods)
}

#' Load CFSR data based on state, profile type, and period
#'
#' @param state Two-letter state code (e.g., "MD", "KY") - ignored for national type
#' @param profile Profile period (e.g., "2025_02", "2024_08", or "latest")
#' @param type Profile type: "national", "rsp", or "state"
#' @return Data frame with CFSR data
load_cfsr_data <- function(state, profile = "latest", type = "national") {
  # Convert state to uppercase
  state <- toupper(state)

  # Validate type
  valid_types <- c("national", "rsp", "observed", "state")
  if (!type %in% valid_types) {
    warning("Invalid profile type '", type, "'. Using 'national'.")
    type <- "national"
  }

  # Detect monorepo root and build path to data directory
  detect_root <- function() {
    current <- getwd()
    while (current != dirname(current)) {
      if (file.exists(file.path(current, "CLAUDE.md")) ||
          file.exists(file.path(current, ".git"))) {
        return(current)
      }
      current <- dirname(current)
    }
    return(Sys.getenv("CM_REPORTS_ROOT", "/app"))
  }
  data_dir <- file.path(detect_root(), "domains/cfsr/data/rds")

  # If "latest" requested, dynamically find most recent profile
  if (profile == "latest") {
    available <- get_available_profiles(state, type)
    if (length(available) == 0) {
      stop("No profiles available for ", type,
           if (type != "national") paste0(" (", state, ")"))
    }
    profile <- available[1]  # First is most recent (sorted descending)
    message("Using most recent profile: ", profile)
  }

  # New hierarchical structure:
  # - national: domains/cfsr/data/rds/national/cfsr_profile_national_{PERIOD}.rds
  # - state-specific: domains/cfsr/data/rds/{state}/{period}/{STATE}_cfsr_profile_{type}_{period}.rds
  # Azure: same paths relative to processed container (see paths.R build_rds_path)
  if (type == "national") {
    filename <- paste0("cfsr_profile_national_", profile, ".rds")
    blob_path <- paste0("rds/national/", filename)
    national_dir <- file.path(data_dir, "national")
    file_path <- file.path(national_dir, filename)
  } else {
    filename <- paste0(state, "_cfsr_profile_", type, "_", profile, ".rds")
    blob_path <- paste0("rds/", tolower(state), "/", profile, "/", filename)
    state_dir <- file.path(data_dir, tolower(state), profile)
    file_path <- file.path(state_dir, filename)
  }

  if (.cm_is_azure_data()) {
    message("Loading data from blob: ", blob_path)
    return(.cm_azure_read_rds(blob_path))
  }

  # Check if file exists
  if (!file.exists(file_path)) {
    stop("Data file not found: ", file_path)
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
