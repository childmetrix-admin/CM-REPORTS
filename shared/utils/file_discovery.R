# file_discovery.R - ShareFile discovery functions

# Note: This file assumes SHAREFILE_BASE is defined (sourced from paths.R)

#' Discover available states
#'
#' Scans ShareFile for state folders with CFSR uploads
#'
#' @return Character vector of lowercase state codes
#' @export
discover_states <- function() {
  if (!dir.exists(SHAREFILE_BASE)) {
    warning("ShareFile not accessible: ", SHAREFILE_BASE)
    return(character(0))
  }

  state_dirs <- list.dirs(SHAREFILE_BASE, recursive = FALSE, full.names = FALSE)

  # Filter for 2-letter state codes
  states <- state_dirs[nchar(state_dirs) == 2]

  # Only return states that have cfsr/uploads folder
  states_with_cfsr <- character(0)
  for (state in states) {
    cfsr_path <- file.path(SHAREFILE_BASE, state, "cfsr/uploads")
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
  uploads_path <- file.path(SHAREFILE_BASE, state, "cfsr/uploads")

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
  uploads_path <- file.path(SHAREFILE_BASE, state, "cfsr/uploads", period)

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
    # State: Check for Supplemental Context Data files excluding National
    state = any(grepl("Supplemental Context Data.*\\.xlsx?$", files, ignore.case = TRUE) &
                !grepl("^National", files, ignore.case = TRUE))
  )

  return(sources)
}
