# update_app.R - Keep app.html period selectors in sync with extracted data
#
# Called automatically by run_profile.R after successful extraction.
# Updates the cfsrProfiles array in app.html for the given state so
# the period selector stays current without manual edits.

#' Convert period code to human-readable label
#'
#' @param period Character. Period in YYYY_MM format (e.g., "2025_08")
#' @return Character. Human-readable label (e.g., "August 2025")
period_to_label <- function(period) {
  parts <- strsplit(period, "_")[[1]]
  year  <- parts[1]
  month <- month.name[as.integer(parts[2])]
  paste(month, year)
}

#' Update cfsrProfiles in app.html for a state
#'
#' Reads app.html, adds the given period to the state's cfsrProfiles array
#' if not already present, sorts descending, and writes the file back.
#'
#' @param state Character. Lowercase state code (e.g., "md")
#' @param period Character. Period in YYYY_MM format (e.g., "2025_08")
#' @return Invisible logical. TRUE if file was updated, FALSE if skipped/failed.
#'
#' @examples
#' update_app_html_profiles("md", "2025_08")
update_app_html_profiles <- function(state, period) {
  app_html_path <- file.path(MONOREPO_ROOT, "app.html")

  if (!file.exists(app_html_path)) {
    warning("app.html not found at: ", app_html_path)
    return(invisible(FALSE))
  }

  state_lower <- tolower(state)
  lines <- readLines(app_html_path, warn = FALSE)

  # Find the line containing this state's key in STATE_CONFIGS
  state_key_pattern <- paste0("'", state_lower, "':\\s*\\{")
  state_line <- which(grepl(state_key_pattern, lines))

  if (length(state_line) == 0) {
    warning("State '", state_lower, "' not found in app.html STATE_CONFIGS")
    return(invisible(FALSE))
  }

  state_line <- state_line[1]

  # Find cfsrProfiles: [ after the state key line
  profiles_open <- which(
    grepl("cfsrProfiles:\\s*\\[", lines) & seq_along(lines) > state_line
  )

  if (length(profiles_open) == 0) {
    warning("cfsrProfiles not found for state '", state_lower, "' in app.html")
    return(invisible(FALSE))
  }

  profiles_open <- profiles_open[1]

  # Find the closing ] (first line that is only whitespace + ] after the open)
  profiles_close <- which(
    grepl("^\\s*\\]", lines) & seq_along(lines) > profiles_open
  )
  profiles_close <- profiles_close[1]

  # Extract existing entry lines
  entry_lines <- lines[(profiles_open + 1):(profiles_close - 1)]
  entry_lines <- entry_lines[grepl("\\{value:", entry_lines)]

  # Check if period already present
  if (any(grepl(paste0("value: '", period, "'"), entry_lines))) {
    message("app.html already contains period '", period, "' for state '", state_lower, "' - no update needed")
    return(invisible(TRUE))
  }

  # Capture indentation from existing entries (or default to 12 spaces)
  indent <- if (length(entry_lines) > 0) {
    sub("^(\\s*).*", "\\1", entry_lines[1])
  } else {
    "            "
  }

  # Build new entry line (no trailing comma yet - we'll add them uniformly below)
  new_label <- period_to_label(period)
  new_entry <- paste0(indent, "{value: '", period, "', label: '", new_label, "'}")

  # Strip trailing commas from all entries for uniform handling
  all_entries <- c(
    gsub(",\\s*$", "", entry_lines),
    new_entry
  )

  # Sort descending by period value (extracted from value: 'YYYY_MM')
  period_values <- gsub(".*value: '([^']+)'.*", "\\1", all_entries)
  all_entries   <- all_entries[order(period_values, decreasing = TRUE)]

  # Re-add trailing commas to all but the last entry
  n <- length(all_entries)
  if (n > 1) {
    all_entries[seq_len(n - 1)] <- paste0(all_entries[seq_len(n - 1)], ",")
  }

  # Reconstruct file
  new_lines <- c(
    lines[seq_len(profiles_open)],
    all_entries,
    lines[profiles_close:length(lines)]
  )

  writeLines(new_lines, app_html_path)
  message("app.html updated: added '", period, "' (", new_label, ") for state '", state_lower, "'")
  return(invisible(TRUE))
}
