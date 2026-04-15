# file_discovery.R - Discover CFSR uploads from Azure Blob (raw container)
# Requires paths.R to be sourced first (sets AZURE_BLOB_* and list_blobs).

#' Discover available states
#'
#' Scans the raw blob container for state prefixes with CFSR uploads
#'
#' @return Character vector of lowercase state codes
#' @export
discover_states <- function() {
  if (!exists("list_blobs")) {
    stop("Blob functions not available. Ensure domains/cfsr/extraction/paths.R is sourced first.")
  }

  all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = "")

  state_codes <- unique(sub("^([a-z]{2})/.*", "\\1", all_blobs))
  state_codes <- state_codes[nchar(state_codes) == 2]

  states_with_cfsr <- character(0)
  for (state in state_codes) {
    cfsr_blobs <- list_blobs(
      AZURE_BLOB_CONTAINER_RAW,
      prefix = paste0(state, "/", state, "/cfsr/uploads/")
    )
    if (length(cfsr_blobs) > 0) {
      states_with_cfsr <- c(states_with_cfsr, state)
      next
    }
    cfsr_blobs <- list_blobs(
      AZURE_BLOB_CONTAINER_RAW,
      prefix = paste0(state, "/cfsr/uploads/")
    )
    if (length(cfsr_blobs) > 0) {
      states_with_cfsr <- c(states_with_cfsr, state)
    }
  }

  sort(tolower(states_with_cfsr))
}

#' Discover available periods for a state
#'
#' @param state Lowercase 2-letter state code
#' @return Character vector of periods in YYYY_MM format
#' @export
discover_periods <- function(state) {
  state <- tolower(state)

  prefix <- paste0(state, "/", state, "/cfsr/uploads/")
  all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = prefix)

  if (length(all_blobs) == 0) {
    prefix <- paste0(state, "/cfsr/uploads/")
    all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = prefix)
  }

  if (length(all_blobs) == 0) {
    warning("No uploads found for state: ", state)
    return(character(0))
  }

  sub_paths <- sub(paste0("^", prefix), "", all_blobs)
  period_parts <- sub("/.*", "", sub_paths)
  periods <- unique(period_parts[grepl("^\\d{4}_\\d{2}$", period_parts)])

  sort(periods, decreasing = TRUE)
}

#' Discover available data sources for a state/period
#'
#' @param state Lowercase 2-letter state code
#' @param period Period in YYYY_MM format
#' @return Named logical vector (national, rsp, observed, state)
#' @export
discover_sources <- function(state, period) {
  state <- tolower(state)

  prefix <- paste0(state, "/", state, "/cfsr/uploads/", period, "/")
  all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = prefix)

  if (length(all_blobs) == 0) {
    prefix <- paste0(state, "/cfsr/uploads/", period, "/")
    all_blobs <- list_blobs(AZURE_BLOB_CONTAINER_RAW, prefix = prefix)
  }

  if (length(all_blobs) == 0) {
    return(c(national = FALSE, rsp = FALSE, observed = FALSE, state = FALSE))
  }

  files <- basename(all_blobs)

  c(
    national = any(grepl("National.*\\.xlsx?$", files, ignore.case = TRUE)),
    rsp = any(grepl("adobe_to_accessible_text\\.txt$", files, ignore.case = TRUE)) ||
      any(grepl("\\.pdf$", files, ignore.case = TRUE)),
    observed = any(grepl("\\.pdf$", files, ignore.case = TRUE)),
    state = any(grepl("Supplemental Context Data.*\\.xlsx?$", files, ignore.case = TRUE) &
      !grepl("^National", files, ignore.case = TRUE))
  )
}
