#####################################
#####################################
# CFSR Profile - Main Orchestrator ----
#####################################
#####################################

# Purpose: Main entry point for CFSR profile data extraction pipeline.
# Processes state CFSR Data Profile PDFs and Excel files from Azure Blob (raw container),
# extracting observed performance, RSP, and national comparison data.
#
# Inputs: PDFs and Excel under raw blob paths such as {state}/cfsr/uploads/{period}/ (see file_discovery.R)
# Outputs: RDS objects uploaded to the processed blob container (paths from build_rds_path())

#####################################
# NOTES ----
#####################################

# This orchestrator coordinates multiple extraction scripts:
# - profile_pdf_observed.R: Extract observed performance (pg. 4 of PDF)
# - profile_pdf_rsp.R: Extract risk-standardized performance (pg. 2 of PDF)
# - profile_excel_national.R: Extract national comparison data
# - profile_excel_state.R: Extract state-specific Excel data
#
# Each extraction can be run individually or in combination via the 'source' parameter.
# Supports bulk processing across multiple states and periods.

#####################################
# LIBRARIES & CONFIGURATION ----
#####################################

# Load configuration (in same directory)
# Use CFSR_EXTRACTION_DIR if available (set by paths.R), otherwise detect from sys.frame
extraction_dir <- if (exists("CFSR_EXTRACTION_DIR")) {
  CFSR_EXTRACTION_DIR
} else if (!is.null(sys.frame(1)$ofile)) {
  dirname(sys.frame(1)$ofile)
} else {
  # Fallback for Rscript execution
  root <- Sys.getenv("CM_REPORTS_ROOT", "/app")
  file.path(root, "domains/cfsr/extraction")
}
source(file.path(extraction_dir, "config.R"))
source(file.path(extraction_dir, "update_app.R"))

#####################################
# MAIN FUNCTION ----
#####################################

#' Run CFSR profile processing
#'
#' @param state Lowercase 2-letter state code (NULL = all states)
#' @param period Period in YYYY_MM format (NULL = all periods)
#' @param source Data source: "national", "rsp", "observed", "state", or "all" (default: "all")
#' @param verbose Print detailed progress messages (default: TRUE)
#' @return Invisibly returns list of processing results
#' @export
run_profile <- function(state = NULL, period = NULL, source = "all", verbose = TRUE) {

  # If both NULL, process everything
  # Otherwise, at least one must be specified

  # Validate source
  validate_source(source)

  # Determine which combinations to process
  combinations <- get_processing_combinations(state, period)

  if (nrow(combinations) == 0) {
    message("No data found for the specified criteria")
    return(invisible(NULL))
  }

  # Print summary
  if (verbose) {
    cat("\n=== CFSR Profile Processing ===\n")
    cat("Processing", nrow(combinations), "state-period combination(s)\n")
    cat("Sources:", source, "\n\n")
  }

  # Process each combination
  results <- list()

  for (i in 1:nrow(combinations)) {
    combo_state <- combinations$state[i]
    combo_period <- combinations$period[i]

    if (verbose) {
      cat("---\n")
      cat("Processing:", toupper(combo_state), "-", combo_period, "\n")
    }

    # Process this combination
    combo_result <- process_combination(
      state = combo_state,
      period = combo_period,
      source = source,
      verbose = verbose
    )

    results[[paste(combo_state, combo_period, sep = "_")]] <- combo_result

    # Generate PowerPoint presentation if processing was successful
    if (combo_result$success) {
      if (verbose) {
        cat("  Generating PowerPoint presentation...\n")
      }

      tryCatch({
        # Source PPT generation functions
        source(file.path(CFSR_FUNCTIONS_DIR, "functions_cfsr_profile_ppt.R"))

        # Generate presentation
        ppt_path <- generate_cfsr_presentation(combo_state, combo_period)

        if (verbose) {
          cat("  ✓ Presentation saved:", ppt_path, "\n")
        }

        # Add to results
        results[[paste(combo_state, combo_period, sep = "_")]]$presentation <- ppt_path
      }, error = function(e) {
        if (verbose) {
          cat("  ✗ PPT generation failed:", e$message, "\n")
        }
        # Add error to results but don't fail the entire pipeline
        results[[paste(combo_state, combo_period, sep = "_")]]$presentation_error <- e$message
      })

      # Keep app.html period selector in sync
      tryCatch({
        update_app_html_profiles(combo_state, combo_period)
      }, error = function(e) {
        warning("Could not update app.html: ", e$message)
      })
    }
  }

  if (verbose) {
    cat("\n=== Processing Complete ===\n")
    print_results_summary(results)
  }

  return(invisible(results))
}

#####################################
# HELPER FUNCTIONS ----
#####################################

#' Get combinations to process
#'
#' @param state State code or NULL
#' @param period Period or NULL
#' @return Data frame with state and period columns
get_processing_combinations <- function(state, period) {

  # Case 1: Both state and period provided
  if (!is.null(state) && !is.null(period)) {
    validate_state(state)
    validate_period(period, state)
    return(data.frame(state = tolower(state), period = period, stringsAsFactors = FALSE))
  }

  # Case 2: Only state provided - get all periods
  if (!is.null(state) && is.null(period)) {
    validate_state(state)
    periods <- discover_periods(state)

    if (length(periods) == 0) {
      return(data.frame(state = character(0), period = character(0), stringsAsFactors = FALSE))
    }

    return(data.frame(
      state = tolower(state),
      period = periods,
      stringsAsFactors = FALSE
    ))
  }

  # Case 3: Only period provided - get all states
  if (is.null(state) && !is.null(period)) {
    validate_period(period)
    states <- discover_states()

    # Filter to states that have this period
    states_with_period <- character(0)
    for (s in states) {
      if (period %in% discover_periods(s)) {
        states_with_period <- c(states_with_period, s)
      }
    }

    if (length(states_with_period) == 0) {
      return(data.frame(state = character(0), period = character(0), stringsAsFactors = FALSE))
    }

    return(data.frame(
      state = states_with_period,
      period = period,
      stringsAsFactors = FALSE
    ))
  }

  # Case 4: Both NULL - get all states and all periods
  if (is.null(state) && is.null(period)) {
    states <- discover_states()

    if (length(states) == 0) {
      return(data.frame(state = character(0), period = character(0), stringsAsFactors = FALSE))
    }

    # Build all state-period combinations
    all_combos <- data.frame(state = character(0), period = character(0), stringsAsFactors = FALSE)

    for (s in states) {
      periods <- discover_periods(s)
      if (length(periods) > 0) {
        state_combos <- data.frame(
          state = s,
          period = periods,
          stringsAsFactors = FALSE
        )
        all_combos <- rbind(all_combos, state_combos)
      }
    }

    return(all_combos)
  }
}

#' Process a single state-period combination
#'
#' @param state State code
#' @param period Period
#' @param source Source types to process
#' @param verbose Print messages
#' @return List with processing results
process_combination <- function(state, period, source, verbose) {

  # Set up environment
  config <- setup_profile_env(state, period)

  # Discover available sources
  available_sources <- discover_sources(state, period)

  # Determine which sources to process
  if (source == "all") {
    sources_to_process <- names(available_sources)[available_sources]
  } else {
    sources_to_process <- source
  }

  if (length(sources_to_process) == 0) {
    if (verbose) cat("  No data sources available\n")
    return(list(state = state, period = period, sources = character(0), success = FALSE))
  }

  # Process each source
  results <- list()

  for (src in sources_to_process) {
    if (!available_sources[src]) {
      if (verbose) cat("  Skipping", src, "- no data file\n")
      results[[src]] <- list(processed = FALSE, reason = "No data file")
      next
    }

    if (verbose) cat("  Processing", src, "...\n")

    result <- tryCatch({
      process_source(src, state, period, verbose)
    }, error = function(e) {
      if (verbose) cat("    ERROR:", e$message, "\n")
      list(processed = FALSE, error = e$message)
    })

    results[[src]] <- result
  }

  return(list(
    state = state,
    period = period,
    sources = results,
    success = any(sapply(results, function(x) isTRUE(x$processed)))
  ))
}

#' Process a specific data source
#'
#' @param source Source type (national, rsp, observed, state)
#' @param state State code
#' @param period Period
#' @param verbose Print messages
#' @return List with processing result
process_source <- function(source, state, period, verbose) {

  script_path <- switch(source,
    national = file.path(CFSR_EXTRACTION_DIR, "profile_excel_national.R"),
    rsp = file.path(CFSR_EXTRACTION_DIR, "profile_pdf_rsp.R"),
    observed = file.path(CFSR_EXTRACTION_DIR, "profile_pdf_observed.R"),
    state = file.path(CFSR_EXTRACTION_DIR, "profile_excel_state.R"),
    stop("Unknown source: ", source)
  )

  if (!file.exists(script_path)) {
    return(list(processed = FALSE, error = paste("Script not found:", script_path)))
  }

  # Initialize common globals (libraries, folders, PDF discovery)
  initialize_common_globals(state, period, source)

  # Source the script (which expects all globals to be set)
  source(script_path, local = FALSE)

  return(list(processed = TRUE, script = script_path))
}

#' Print summary of processing results
#'
#' @param results List of processing results
print_results_summary <- function(results) {
  cat("\nResults:\n")

  for (combo_name in names(results)) {
    result <- results[[combo_name]]
    status <- if (result$success) "✓" else "✗"
    cat(status, combo_name, "\n")

    for (src in names(result$sources)) {
      src_result <- result$sources[[src]]
      src_status <- if (isTRUE(src_result$processed)) "✓" else "✗"
      cat("  ", src_status, src, "\n")
    }
  }
}

#####################################
# INITIALIZATION ----
#####################################

message("\nCFSR Profile Orchestrator loaded")
message("Run run_profile() to process data")
message("See usage examples at top of this file")
