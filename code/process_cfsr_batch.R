# process_cfsr_batch.R
# Batch processing functions for CFSR data with status tracking

library(dplyr)
library(tools)

#' Get processing log path
#' @return Character string with log file path
get_log_path <- function() {
  file.path("D:/repo_childmetrix/cfsr-profile/data", "processing_log.csv")
}

#' Initialize or load processing log
#' @return Data frame with processing log
get_processing_log <- function() {
  log_path <- get_log_path()

  if (file.exists(log_path)) {
    log <- read.csv(log_path, stringsAsFactors = FALSE)
    return(log)
  } else {
    # Create new log
    log <- data.frame(
      state_code = character(),
      profile_period = character(),
      upload_date = character(),
      process_date = character(),
      status = character(),
      csv_hash = character(),
      rds_hash = character(),
      error_msg = character(),
      stringsAsFactors = FALSE
    )
    return(log)
  }
}

#' Save processing log
#' @param log Data frame with processing log
save_processing_log <- function(log) {
  log_path <- get_log_path()
  write.csv(log, log_path, row.names = FALSE)
}

#' Update processing log for a state/period
#' @param state_code Character string with state code
#' @param profile_period Character string with period (YYYY_MM)
#' @param status Character string: "pending", "success", "error"
#' @param csv_hash Character string with MD5 hash of CSV (optional)
#' @param rds_hash Character string with MD5 hash of RDS (optional)
#' @param error_msg Character string with error message (optional)
update_processing_log <- function(state_code, profile_period, status,
                                   csv_hash = NA, rds_hash = NA, error_msg = NA) {
  log <- get_processing_log()

  # Check if entry exists
  existing_idx <- which(log$state_code == state_code & log$profile_period == profile_period)

  if (length(existing_idx) > 0) {
    # Update existing entry
    log$process_date[existing_idx] <- Sys.Date()
    log$status[existing_idx] <- status
    log$csv_hash[existing_idx] <- ifelse(is.na(csv_hash), log$csv_hash[existing_idx], csv_hash)
    log$rds_hash[existing_idx] <- ifelse(is.na(rds_hash), log$rds_hash[existing_idx], rds_hash)
    log$error_msg[existing_idx] <- ifelse(is.na(error_msg), "", error_msg)
  } else {
    # Add new entry
    new_entry <- data.frame(
      state_code = state_code,
      profile_period = profile_period,
      upload_date = Sys.Date(),
      process_date = ifelse(status == "pending", NA, Sys.Date()),
      status = status,
      csv_hash = ifelse(is.na(csv_hash), "", csv_hash),
      rds_hash = ifelse(is.na(rds_hash), "", rds_hash),
      error_msg = ifelse(is.na(error_msg), "", error_msg),
      stringsAsFactors = FALSE
    )
    log <- rbind(log, new_entry)
  }

  save_processing_log(log)
  return(log)
}

#' Scan uploads directory for pending work
#' @param uploads_dir Base uploads directory path
#' @return Data frame with state_code, profile_period, needs_processing
scan_pending_work <- function(uploads_dir = "D:/repo_childmetrix/cfsr-profile/data/uploads") {
  if (!dir.exists(uploads_dir)) {
    warning("Uploads directory not found: ", uploads_dir)
    return(data.frame(state_code = character(), profile_period = character(),
                     needs_processing = logical()))
  }

  # Get all state directories (exclude _shared)
  state_dirs <- list.dirs(uploads_dir, full.names = FALSE, recursive = FALSE)
  state_dirs <- state_dirs[state_dirs != "_shared"]

  if (length(state_dirs) == 0) {
    return(data.frame(state_code = character(), profile_period = character(),
                     needs_processing = logical()))
  }

  # Get processing log
  log <- get_processing_log()

  # Scan each state/period combination
  results <- list()
  for (state in state_dirs) {
    state_path <- file.path(uploads_dir, state)
    period_dirs <- list.dirs(state_path, full.names = FALSE, recursive = FALSE)

    for (period in period_dirs) {
      # Check if this state/period has been processed
      log_entry <- log[log$state_code == state & log$profile_period == period, ]

      needs_processing <- TRUE
      if (nrow(log_entry) > 0) {
        # Already processed - check if files changed
        if (log_entry$status == "success") {
          needs_processing <- FALSE
          # Could add file hash check here in future
        }
      }

      results[[length(results) + 1]] <- data.frame(
        state_code = state,
        profile_period = period,
        needs_processing = needs_processing,
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(results) == 0) {
    return(data.frame(state_code = character(), profile_period = character(),
                     needs_processing = logical()))
  }

  do.call(rbind, results)
}

#' Preview what will be processed
#' @param force_reprocess Logical - if TRUE, reprocess even if already done
#' @param states Character vector of state codes to filter (optional)
#' @param periods Character vector of periods to filter (optional)
#' @return Data frame with pending work
preview_processing_queue <- function(force_reprocess = FALSE, states = NULL, periods = NULL) {
  pending <- scan_pending_work()

  if (nrow(pending) == 0) {
    cat("\nNo pending work found.\n\n")
    return(invisible(pending))
  }

  # Apply filters
  if (!is.null(states)) {
    pending <- pending[pending$state_code %in% states, ]
  }
  if (!is.null(periods)) {
    pending <- pending[pending$profile_period %in% periods, ]
  }

  if (force_reprocess) {
    pending$needs_processing <- TRUE
  }

  # Separate into new and already processed
  to_process <- pending[pending$needs_processing, ]
  already_done <- pending[!pending$needs_processing, ]

  cat("\n")
  cat("=" = rep("=", 70), sep = "")
  cat("\nProcessing Queue Preview\n")
  cat("=" = rep("=", 70), sep = "")
  cat("\n\n")

  if (nrow(to_process) > 0) {
    cat("Pending processing:\n")
    for (i in 1:nrow(to_process)) {
      cat(sprintf("  %s - %s  [NEW - never processed]\n",
                  to_process$state_code[i], to_process$profile_period[i]))
    }
    cat("\n")
  }

  if (nrow(already_done) > 0) {
    cat("Already processed (will be skipped):\n")
    for (i in 1:nrow(already_done)) {
      cat(sprintf("  %s - %s\n", already_done$state_code[i], already_done$profile_period[i]))
    }
    cat("\n")
  }

  if (force_reprocess && nrow(already_done) > 0) {
    cat("Note: force_reprocess=TRUE will reprocess all items above\n\n")
  }

  cat("Total to process: ", nrow(to_process), "\n")
  cat("=" = rep("=", 70), sep = "")
  cat("\n\n")

  return(invisible(pending))
}

#' Process all CFSR data in batch
#' @param force_reprocess Logical - if TRUE, reprocess even if already done
#' @param states Character vector of state codes to filter (optional)
#' @param periods Character vector of periods to filter (optional)
#' @param dry_run Logical - if TRUE, don't actually process, just show what would happen
#' @param verbose Logical - if TRUE, print detailed messages
#' @return List with summary of processing results
process_all_cfsr_data <- function(force_reprocess = FALSE,
                                   states = NULL,
                                   periods = NULL,
                                   dry_run = FALSE,
                                   verbose = TRUE) {

  if (verbose) {
    cat("\n")
    cat("=" = rep("=", 70), sep = "")
    if (dry_run) {
      cat("\nBatch Processing - DRY RUN (No changes will be made)\n")
    } else {
      cat("\nBatch Processing CFSR Data\n")
    }
    cat("=" = rep("=", 70), sep = "")
    cat("\n\n")
  }

  # Get pending work
  pending <- scan_pending_work()

  if (nrow(pending) == 0) {
    if (verbose) cat("No work found to process.\n\n")
    return(invisible(list(processed = 0, skipped = 0, errors = 0)))
  }

  # Apply filters
  if (!is.null(states)) {
    pending <- pending[pending$state_code %in% states, ]
  }
  if (!is.null(periods)) {
    pending <- pending[pending$profile_period %in% periods, ]
  }

  if (force_reprocess) {
    pending$needs_processing <- TRUE
  }

  to_process <- pending[pending$needs_processing, ]

  if (nrow(to_process) == 0) {
    if (verbose) {
      cat("All selected items already processed.\n")
      cat("Use force_reprocess=TRUE to reprocess.\n\n")
    }
    return(invisible(list(processed = 0, skipped = nrow(pending), errors = 0)))
  }

  if (dry_run) {
    if (verbose) {
      cat("Would process ", nrow(to_process), " state/period combination(s):\n\n", sep = "")
      for (i in 1:nrow(to_process)) {
        cat(sprintf("  [%d/%d] %s - %s\n",
                    i, nrow(to_process),
                    to_process$state_code[i], to_process$profile_period[i]))
      }
      cat("\n")
    }
    return(invisible(list(processed = 0, skipped = 0, errors = 0, would_process = to_process)))
  }

  # Process each item
  results <- list(processed = 0, skipped = 0, errors = 0, details = list())

  for (i in 1:nrow(to_process)) {
    state <- to_process$state_code[i]
    period <- to_process$profile_period[i]

    if (verbose) {
      cat("\n")
      cat(sprintf("[%d/%d] Processing %s - %s...\n", i, nrow(to_process), state, period))
    }

    # Mark as pending in log
    update_processing_log(state, period, "pending")

    # Process this state/period
    tryCatch({
      process_single_cfsr(state, period, verbose = verbose)

      # Mark as success
      update_processing_log(state, period, "success")
      results$processed <- results$processed + 1

      if (verbose) {
        cat(sprintf("  ✓ Complete\n"))
      }

    }, error = function(e) {
      # Mark as error
      update_processing_log(state, period, "error", error_msg = e$message)
      results$errors <<- results$errors + 1

      if (verbose) {
        cat(sprintf("  ✗ Error: %s\n", e$message))
      }
    })
  }

  # Print summary
  if (verbose) {
    cat("\n")
    cat("-" = rep("-", 70), sep = "")
    cat("\nSummary\n")
    cat("-" = rep("-", 70), sep = "")
    cat("\n\n")
    cat("Processed:  ", results$processed, "\n", sep = "")
    cat("Skipped:    ", results$skipped, "\n", sep = "")
    cat("Errors:     ", results$errors, "\n", sep = "")
    cat("\n")
    cat("=" = rep("=", 70), sep = "")
    cat("\n\n")
  }

  return(invisible(results))
}

#' Process a single state/period combination
#' @param state_code Character string with state code
#' @param profile_period Character string with period (YYYY_MM)
#' @param verbose Logical - if TRUE, print messages
process_single_cfsr <- function(state_code, profile_period, verbose = TRUE) {
  # This function will be the updated cfsr-profile.R logic
  # For now, we'll create a placeholder that sources the main script

  if (verbose) {
    cat("  Loading cfsr-profile.R...\n")
  }

  # Set global variables for the script
  assign("state_code", state_code, envir = .GlobalEnv)
  assign("profile_period", profile_period, envir = .GlobalEnv)

  # Source the main processing script
  source("D:/repo_childmetrix/cfsr-profile/code/cfsr-profile.R", local = FALSE)

  if (verbose) {
    cat("  Processing complete\n")
  }
}
