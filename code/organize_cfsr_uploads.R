# organize_cfsr_uploads.R
# Functions to organize CFSR files from uploads folder into structured directories

library(tools)

#' Extract period from CFSR filename
#'
#' @param filename Character string with filename
#' @return Character string in format "YYYY_MM" or NULL if not found
#' @examples
#' extract_period_from_filename("National - Supplemental Context Data - February 2025.xlsx")
#' # Returns: "2025_02"
extract_period_from_filename <- function(filename) {
  # Match patterns like "February 2025", "August 2024", etc.
  pattern <- "(January|February|March|April|May|June|July|August|September|October|November|December)\\s+(\\d{4})"

  match <- regexpr(pattern, filename, ignore.case = TRUE)
  if (match == -1) {
    return(NULL)
  }

  match_text <- regmatches(filename, match)

  # Extract month and year
  parts <- strsplit(match_text, "\\s+")[[1]]
  month_name <- parts[1]
  year <- parts[2]

  # Convert month name to number
  month_num <- match(tolower(month_name), tolower(month.name))
  if (is.na(month_num)) {
    return(NULL)
  }

  # Format as YYYY_MM
  period <- sprintf("%s_%02d", year, month_num)
  return(period)
}


#' Extract state code from CFSR filename
#'
#' @param filename Character string with filename
#' @return Character string with state code (e.g., "MD", "KY") or NULL
extract_state_from_filename <- function(filename) {
  # Pattern 1: "MD - CFSR" (PDF files)
  # Pattern 2: "Maryland - Supplemental" (state Excel files)
  # Pattern 3: "National" (shared files)

  if (grepl("^National\\s*-", filename, ignore.case = TRUE)) {
    return("_shared")
  }

  # Try to match 2-letter state code at beginning
  state_code_match <- regexpr("^[A-Z]{2}\\s*-", filename)
  if (state_code_match != -1) {
    state_code <- substr(filename, 1, 2)
    return(toupper(state_code))
  }

  # Try to match state name at beginning (need state name lookup)
  # For now, extract first word before " -"
  name_match <- regexpr("^([A-Za-z]+)\\s*-", filename)
  if (name_match != -1) {
    state_name <- regmatches(filename, name_match)
    state_name <- gsub("\\s*-\\s*", "", state_name)
    return(state_name_to_code(state_name))
  }

  return(NULL)
}


#' Convert state name to 2-letter code
#'
#' @param state_name Character string with state name
#' @return Character string with 2-letter state code
state_name_to_code <- function(state_name) {
  # Mapping of common state names to codes
  state_mapping <- c(
    "Alabama" = "AL", "Alaska" = "AK", "Arizona" = "AZ", "Arkansas" = "AR",
    "California" = "CA", "Colorado" = "CO", "Connecticut" = "CT", "Delaware" = "DE",
    "Florida" = "FL", "Georgia" = "GA", "Hawaii" = "HI", "Idaho" = "ID",
    "Illinois" = "IL", "Indiana" = "IN", "Iowa" = "IA", "Kansas" = "KS",
    "Kentucky" = "KY", "Louisiana" = "LA", "Maine" = "ME", "Maryland" = "MD",
    "Massachusetts" = "MA", "Michigan" = "MI", "Minnesota" = "MN", "Mississippi" = "MS",
    "Missouri" = "MO", "Montana" = "MT", "Nebraska" = "NE", "Nevada" = "NV",
    "New Hampshire" = "NH", "New Jersey" = "NJ", "New Mexico" = "NM", "New York" = "NY",
    "North Carolina" = "NC", "North Dakota" = "ND", "Ohio" = "OH", "Oklahoma" = "OK",
    "Oregon" = "OR", "Pennsylvania" = "PA", "Rhode Island" = "RI", "South Carolina" = "SC",
    "South Dakota" = "SD", "Tennessee" = "TN", "Texas" = "TX", "Utah" = "UT",
    "Vermont" = "VT", "Virginia" = "VA", "Washington" = "WA", "West Virginia" = "WV",
    "Wisconsin" = "WI", "Wyoming" = "WY", "District of Columbia" = "DC"
  )

  code <- state_mapping[state_name]
  if (is.na(code)) {
    warning("Unknown state name: ", state_name)
    return(NULL)
  }

  return(unname(code))
}


#' Organize CFSR files from source directory into structured folders
#'
#' @param source_dir Character string with path to source directory (e.g., "~/Downloads")
#' @param target_base_dir Character string with base target directory (default: "D:/repo_childmetrix/cfsr-profile/data/uploads")
#' @param copy_files Logical - if TRUE, copy files; if FALSE, move files (default: TRUE)
#' @param verbose Logical - if TRUE, print detailed messages (default: TRUE)
#' @return List with summary of organized files
#' @examples
#' organize_all_cfsr_files("C:/Users/heisl/Downloads")
#' organize_all_cfsr_files("D:/repo_childmetrix/cfsr-profile/uploads", copy_files = FALSE)
organize_all_cfsr_files <- function(source_dir,
                                     target_base_dir = "D:/repo_childmetrix/cfsr-profile/data/uploads",
                                     copy_files = TRUE,
                                     verbose = TRUE) {

  if (verbose) {
    cat("\n")
    cat("=" = rep("=", 70), sep = "")
    cat("\nOrganizing CFSR Files\n")
    cat("=" = rep("=", 70), sep = "")
    cat("\n\n")
  }

  # Check source directory exists
  if (!dir.exists(source_dir)) {
    stop("Source directory not found: ", source_dir)
  }

  # Get all files from source directory (non-recursive)
  all_files <- list.files(source_dir, full.names = TRUE, recursive = FALSE)

  # Filter to CFSR-related files (Excel and PDF)
  cfsr_files <- all_files[grepl("\\.(xlsx?|pdf)$", all_files, ignore.case = TRUE)]
  cfsr_files <- cfsr_files[grepl("(Supplemental Context Data|CFSR.*Data Profile)",
                                  basename(cfsr_files), ignore.case = TRUE)]

  if (length(cfsr_files) == 0) {
    if (verbose) cat("No CFSR files found in:", source_dir, "\n")
    return(invisible(list(organized = 0, skipped = 0, errors = 0)))
  }

  if (verbose) {
    cat("Found", length(cfsr_files), "CFSR file(s) in source directory\n\n")
  }

  # Track results
  results <- list(
    organized = 0,
    skipped = 0,
    errors = 0,
    by_state = list(),
    files = list()
  )

  # Process each file
  for (file_path in cfsr_files) {
    filename <- basename(file_path)

    # Extract metadata
    state_code <- extract_state_from_filename(filename)
    period <- extract_period_from_filename(filename)

    if (is.null(state_code) || is.null(period)) {
      if (verbose) {
        cat("[SKIP] Could not parse:", filename, "\n")
        if (is.null(state_code)) cat("       - State code not found\n")
        if (is.null(period)) cat("       - Period not found\n")
      }
      results$skipped <- results$skipped + 1
      next
    }

    # Create target directory
    target_dir <- file.path(target_base_dir, state_code, period)
    if (!dir.exists(target_dir)) {
      dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
    }

    target_path <- file.path(target_dir, filename)

    # Check if file already exists
    if (file.exists(target_path)) {
      # Compare checksums
      source_hash <- md5sum(file_path)
      target_hash <- md5sum(target_path)

      if (source_hash == target_hash) {
        if (verbose) {
          cat("[EXISTS] ", filename, "\n", sep = "")
          cat("         Identical file already exists at: ", target_dir, "\n", sep = "")
        }
        results$skipped <- results$skipped + 1
        next
      } else {
        if (verbose) {
          cat("[WARN] ", filename, "\n", sep = "")
          cat("       File exists but differs - overwriting\n")
        }
      }
    }

    # Copy or move file
    tryCatch({
      if (copy_files) {
        file.copy(file_path, target_path, overwrite = TRUE)
        if (verbose) {
          cat("[COPY] ", filename, "\n", sep = "")
          cat("       ", state_code, " - ", period, " -> ", target_dir, "\n", sep = "")
        }
      } else {
        file.rename(file_path, target_path)
        if (verbose) {
          cat("[MOVE] ", filename, "\n", sep = "")
          cat("       ", state_code, " - ", period, " -> ", target_dir, "\n", sep = "")
        }
      }

      results$organized <- results$organized + 1

      # Track by state
      if (is.null(results$by_state[[state_code]])) {
        results$by_state[[state_code]] <- list(periods = character(), files = 0)
      }
      if (!period %in% results$by_state[[state_code]]$periods) {
        results$by_state[[state_code]]$periods <- c(results$by_state[[state_code]]$periods, period)
      }
      results$by_state[[state_code]]$files <- results$by_state[[state_code]]$files + 1

      # Track file details
      results$files[[length(results$files) + 1]] <- list(
        filename = filename,
        state = state_code,
        period = period,
        path = target_path
      )

    }, error = function(e) {
      if (verbose) {
        cat("[ERROR] ", filename, "\n", sep = "")
        cat("        ", e$message, "\n", sep = "")
      }
      results$errors <<- results$errors + 1
    })
  }

  # Copy National files from _shared to each state folder
  if (verbose) {
    cat("\n")
    cat("-" = rep("-", 70), sep = "")
    cat("\nCopying National files to state folders\n")
    cat("-" = rep("-", 70), sep = "")
    cat("\n\n")
  }

  shared_dir <- file.path(target_base_dir, "_shared")
  if (dir.exists(shared_dir)) {
    # Get all periods with National files
    shared_periods <- list.dirs(shared_dir, full.names = FALSE, recursive = FALSE)

    # Get all state directories (excluding _shared)
    state_dirs <- list.dirs(target_base_dir, full.names = FALSE, recursive = FALSE)
    state_dirs <- state_dirs[state_dirs != "_shared"]

    for (state in state_dirs) {
      for (period in shared_periods) {
        state_period_dir <- file.path(target_base_dir, state, period)

        # Only copy if state has this period
        if (dir.exists(state_period_dir)) {
          shared_period_dir <- file.path(shared_dir, period)
          national_files <- list.files(shared_period_dir, pattern = "^National", full.names = TRUE)

          for (nat_file in national_files) {
            target_nat_path <- file.path(state_period_dir, basename(nat_file))

            if (!file.exists(target_nat_path)) {
              file.copy(nat_file, target_nat_path, overwrite = FALSE)
              if (verbose) {
                cat("[COPY] National file to ", state, "/", period, "\n", sep = "")
              }
            }
          }
        }
      }
    }
  }

  # Print summary
  if (verbose) {
    cat("\n")
    cat("-" = rep("-", 70), sep = "")
    cat("\nSummary\n")
    cat("-" = rep("-", 70), sep = "")
    cat("\n\n")
    cat("Organized:  ", results$organized, " file(s)\n", sep = "")
    cat("Skipped:    ", results$skipped, " file(s)\n", sep = "")
    cat("Errors:     ", results$errors, " file(s)\n", sep = "")
    cat("\n")

    if (length(results$by_state) > 0) {
      cat("By State:\n")
      for (state in names(results$by_state)) {
        periods <- sort(results$by_state[[state]]$periods)
        n_files <- results$by_state[[state]]$files
        display_name <- if (state == "_shared") "Shared/National" else state
        cat(sprintf("  %-20s: %d file(s) across %d period(s): %s\n",
                    display_name, n_files, length(periods), paste(periods, collapse = ", ")))
      }
    }

    cat("\n")
    cat("Files are organized in: ", target_base_dir, "\n", sep = "")
    cat("\n")
    cat("Note: National files copied from _shared/ to each state's period folders\n")
    cat("\nReady to process!\n")
    cat("=" = rep("=", 70), sep = "")
    cat("\n\n")
  }

  return(invisible(results))
}


#' Organize files for a single state
#'
#' @param state_code Character string with 2-letter state code
#' @param source_dir Character string with path to source directory
#' @param target_base_dir Character string with base target directory
#' @param copy_files Logical - if TRUE, copy files; if FALSE, move files
#' @param verbose Logical - if TRUE, print detailed messages
#' @return List with summary
organize_cfsr_files <- function(state_code,
                                 source_dir,
                                 target_base_dir = "D:/repo_childmetrix/cfsr-profile/data/uploads",
                                 copy_files = TRUE,
                                 verbose = TRUE) {

  # For single state, we filter files in organize_all_cfsr_files
  # by checking if filename matches the state
  all_results <- organize_all_cfsr_files(source_dir, target_base_dir, copy_files, verbose = FALSE)

  # Filter to just this state
  state_files <- Filter(function(f) f$state == state_code, all_results$files)

  if (verbose) {
    cat("\nOrganized", length(state_files), "file(s) for", state_code, "\n")
  }

  return(invisible(list(
    organized = length(state_files),
    files = state_files
  )))
}
