# file_discovery.R - Data source discovery functions
# Supports both ShareFile (S: drive) and Azure Blob Storage
# Requires paths.R to be sourced first (sets CM_DATA_SOURCE, SHAREFILE_BASE, etc.)

#' Discover available states
#'
#' Scans the configured data source for state folders with CFSR uploads
#'
#' @return Character vector of lowercase state codes
#' @export
discover_states <- function() {
  if (exists("CM_DATA_SOURCE") && CM_DATA_SOURCE == "azure") {
    return(discover_states_azure())
  }
  return(discover_states_sharefile())
}

#' Discover available periods for a state
#'
#' @param state Lowercase 2-letter state code
#' @return Character vector of periods in YYYY_MM format
#' @export
discover_periods <- function(state) {
  if (exists("CM_DATA_SOURCE") && CM_DATA_SOURCE == "azure") {
    return(discover_periods_azure(state))
  }
  return(discover_periods_sharefile(state))
}

#' Discover available data sources for a state/period
#'
#' @param state Lowercase 2-letter state code
#' @param period Period in YYYY_MM format
#' @return Named logical vector (national, rsp, observed, state)
#' @export
discover_sources <- function(state, period) {
  if (exists("CM_DATA_SOURCE") && CM_DATA_SOURCE == "azure") {
    return(discover_sources_azure(state, period))
  }
  return(discover_sources_sharefile(state, period))
}

# =====================================================
# ShareFile implementations (original behavior)
# =====================================================

discover_states_sharefile <- function() {
  if (is.null(SHAREFILE_BASE) || !dir.exists(SHAREFILE_BASE)) {
    warning("ShareFile not accessible: ", SHAREFILE_BASE)
    return(character(0))
  }

  state_dirs <- list.dirs(SHAREFILE_BASE, recursive = FALSE, full.names = FALSE)
  states <- state_dirs[nchar(state_dirs) == 2]

  states_with_cfsr <- character(0)
  for (state in states) {
    cfsr_path <- file.path(SHAREFILE_BASE, state, "cfsr/uploads")
    if (dir.exists(cfsr_path)) {
      states_with_cfsr <- c(states_with_cfsr, state)
    }
  }

  return(sort(tolower(states_with_cfsr)))
}

discover_periods_sharefile <- function(state) {
  uploads_path <- file.path(SHAREFILE_BASE, state, "cfsr/uploads")

  if (!dir.exists(uploads_path)) {
    warning("No uploads folder for state: ", state)
    return(character(0))
  }

  period_dirs <- list.dirs(uploads_path, recursive = FALSE, full.names = FALSE)
  periods <- period_dirs[grepl("^\\d{4}_\\d{2}$", period_dirs)]

  return(sort(periods, decreasing = TRUE))
}

discover_sources_sharefile <- function(state, period) {
  uploads_path <- file.path(SHAREFILE_BASE, state, "cfsr/uploads", period)

  if (!dir.exists(uploads_path)) {
    return(c(national = FALSE, rsp = FALSE, observed = FALSE, state = FALSE))
  }

  files <- list.files(uploads_path, full.names = FALSE, ignore.case = TRUE)

  sources <- c(
    national = any(grepl("National.*\\.xlsx?$", files, ignore.case = TRUE)),
    rsp = any(grepl("adobe_to_accessible_text\\.txt$", files, ignore.case = TRUE)) ||
          any(grepl("\\.pdf$", files, ignore.case = TRUE)),
    observed = any(grepl("\\.pdf$", files, ignore.case = TRUE)),
    state = any(grepl("Supplemental Context Data.*\\.xlsx?$", files, ignore.case = TRUE) &
                !grepl("^National", files, ignore.case = TRUE))
  )

  return(sources)
}

# =====================================================
# Azure Blob Storage implementations
# =====================================================

discover_states_azure <- function() {
  if (!exists("list_blobs")) {
    stop("Azure blob functions not available. Ensure paths.R is sourced first.")
  }

  # List top-level "directories" in the raw container
  # Blob paths: raw/{state}/cfsr/uploads/...
  all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = "")

  # Extract unique 2-letter state codes from blob paths
  state_codes <- unique(sub("^([a-z]{2})/.*", "\\1", all_blobs))
  state_codes <- state_codes[nchar(state_codes) == 2]

  # Verify each state has cfsr/uploads content
  states_with_cfsr <- character(0)
  for (state in state_codes) {
    cfsr_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW,
                             prefix = paste0(state, "/cfsr/uploads/"))
    if (length(cfsr_blobs) > 0) {
      states_with_cfsr <- c(states_with_cfsr, state)
    }
  }

  return(sort(tolower(states_with_cfsr)))
}

discover_periods_azure <- function(state) {
  prefix <- paste0(tolower(state), "/cfsr/uploads/")
  all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = prefix)

  if (length(all_blobs) == 0) {
    warning("No uploads found for state: ", state)
    return(character(0))
  }

  # Extract period directories from blob paths
  # e.g., "md/cfsr/uploads/2026_02/file.pdf" -> "2026_02"
  sub_paths <- sub(paste0("^", prefix), "", all_blobs)
  period_parts <- sub("/.*", "", sub_paths)
  periods <- unique(period_parts[grepl("^\\d{4}_\\d{2}$", period_parts)])

  return(sort(periods, decreasing = TRUE))
}

discover_sources_azure <- function(state, period) {
  prefix <- paste0(tolower(state), "/cfsr/uploads/", period, "/")
  all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = prefix)

  if (length(all_blobs) == 0) {
    return(c(national = FALSE, rsp = FALSE, observed = FALSE, state = FALSE))
  }

  files <- basename(all_blobs)

  sources <- c(
    national = any(grepl("National.*\\.xlsx?$", files, ignore.case = TRUE)),
    rsp = any(grepl("adobe_to_accessible_text\\.txt$", files, ignore.case = TRUE)) ||
          any(grepl("\\.pdf$", files, ignore.case = TRUE)),
    observed = any(grepl("\\.pdf$", files, ignore.case = TRUE)),
    state = any(grepl("Supplemental Context Data.*\\.xlsx?$", files, ignore.case = TRUE) &
                !grepl("^National", files, ignore.case = TRUE))
  )

  return(sources)
}
