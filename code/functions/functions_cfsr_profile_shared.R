# ============================================================================
# CFSR SHARED FUNCTIONS - PDF Extraction Helpers
# ============================================================================
#
# Shared functions used across multiple CFSR extraction scripts:
# - profile_rsp.R (Risk-Standardized Performance)
# - profile_observed.R (Observed Performance)
# - profile_national.R (National Comparison Data)
#
# These functions handle PDF coordinate-based text extraction using pdftools.

#' Extract tableau-style table from PDF coordinate data
#'
#' Extracts structured table data from PDF using coordinate-based grid system.
#' Groups text elements by y-coordinate (rows) and x-coordinate (columns).
#'
#' @param data PDF text data from pdftools::pdf_data()
#' @param y_min Minimum y-coordinate for table section
#' @param y_max Maximum y-coordinate for table section
#' @param x_cuts Vector of x-coordinates defining column boundaries
#' @param y_tolerance Tolerance for grouping rows (default: 5)
#' @return Tibble with y_group and column data (col_id 0, 1, 2, ...)
#' @examples
#' extract_tableau_table(raw_data, y_min = 190, y_max = 400, x_cuts = c(135, 250, 310))
extract_tableau_table <- function(data, y_min, y_max, x_cuts, y_tolerance = 5) {
  section_data <- data %>%
    filter(y >= y_min & y <= y_max) %>%
    mutate(y_group = round(y / y_tolerance) * y_tolerance) %>%
    mutate(col_id = findInterval(x, x_cuts))

  grid <- section_data %>%
    group_by(y_group, col_id) %>%
    summarise(cell_text = paste(text, collapse = " "), .groups = "drop") %>%
    pivot_wider(names_from = col_id, values_from = cell_text)

  grid
}

#' Extract column headers from PDF coordinate data
#'
#' Extracts column headers from PDF table using coordinate-based text extraction.
#' Handles both RSP format (with National_Perf column) and Observed format (without).
#'
#' @param data PDF text data from pdftools::pdf_data()
#' @param y_min Minimum y-coordinate for header row
#' @param y_max Maximum y-coordinate for header row
#' @param x_cuts Vector of x-coordinates defining column boundaries
#' @param has_national_perf Logical - does table have National_Perf column? (default: TRUE)
#' @return Named character vector with column headers (0, 1, 2, ...)
#' @details
#' - RSP data (PDF page 2): has_national_perf = TRUE (Indicator, National_Perf, Measure_Type, ...)
#' - Observed data (PDF page 4): has_national_perf = FALSE (Indicator, Measure_Type, ...)
#' @examples
#' # RSP extraction (page 2)
#' extract_headers(raw_data, y_min = 163, y_max = 168, x_cuts = top_x_cuts)
#' # Observed extraction (page 4)
#' extract_headers(raw_data, y_min = 175, y_max = 180, x_cuts = top_x_cuts, has_national_perf = FALSE)
extract_headers <- function(data, y_min, y_max, x_cuts, has_national_perf = TRUE) {
  headers_data <- data %>%
    filter(y >= y_min & y <= y_max) %>%
    mutate(col_id = findInterval(x, x_cuts))

  n_cols <- length(x_cuts)
  header_map <- headers_data %>%
    group_by(col_id) %>%
    summarise(text = paste(text, collapse = ""), .groups = "drop") %>%
    arrange(col_id)

  extracted_cols <- setNames(rep(NA_character_, n_cols + 1), 0:n_cols)
  extracted_cols[as.character(header_map$col_id)] <- header_map$text

  # Page 2 (RSP) has National_Perf column, Page 4 (Observed) does not
  if (has_national_perf) {
    extracted_cols["0"] <- "Indicator"
    extracted_cols["1"] <- "National_Perf"
    extracted_cols["2"] <- "Measure_Type"
  } else {
    extracted_cols["0"] <- "Indicator"
    extracted_cols["1"] <- "Measure_Type"
  }

  extracted_cols
}

# ============================================================================
# CFSR-SPECIFIC FOLDER SETUP AND FILE FINDING
# ============================================================================
#
# These functions provide CFSR project-specific utilities:
# - Multi-state support (MD, KY, etc.)
# - Folder structure: data/uploads/{STATE}/{PERIOD}/
# - Indicator dictionary lookup and metadata extraction
# - State ranking and performance comparison

#' Setup CFSR folders for a specific state and profile period
#'
#' @param profile_period Character string in format "YYYY_MM" (e.g., "2025_02")
#' @param state_code Character string with 2-letter state code (e.g., "MD", "KY")
#' @param assign_globals Logical - assign folder paths to global environment
#' @param base_data_dir Base data directory (default: "D:/repo_childmetrix/cfsr-profile/data")
#' @return List with folder paths
#' @examples
#' setup_cfsr_folders("2025_02", "MD")
#' setup_cfsr_folders("2024_08", "KY", assign_globals = TRUE)
setup_cfsr_folders <- function(profile_period,
                                state_code,
                                assign_globals = TRUE,
                                base_data_dir = "D:/repo_childmetrix/cfsr-profile/data") {

  # Validate inputs
  if (missing(profile_period) || is.null(profile_period)) {
    stop("profile_period is required (e.g., '2025_02')")
  }
  if (missing(state_code) || is.null(state_code)) {
    stop("state_code is required (e.g., 'MD')")
  }

  # Normalize
  profile_period <- toupper(profile_period)
  state_code <- tolower(state_code)  # Use lowercase for consistency with ShareFile

  # Build folder paths (but don't create them yet!)
  # Read uploads directly from ShareFile
  folder_uploads <- file.path("S:/Shared Folders", state_code, "cfsr/uploads", profile_period)
  folder_processed <- file.path(base_data_dir, "processed", state_code, profile_period)
  folder_app_data <- file.path(base_data_dir, "app_data", state_code)

  # Check if uploads folder exists on ShareFile
  if (!dir.exists(folder_uploads)) {
    stop("Uploads folder does not exist: ", folder_uploads,
         "\n\nPlease upload files to ShareFile at:",
         "\n  S:/Shared Folders/", state_code, "/cfsr/uploads/", profile_period, "/",
         "\n\nOr check your state_code and profile_period values.",
         call. = FALSE)
  }

  # Check if folder has CFSR files
  files_in_uploads <- list.files(folder_uploads, pattern = "\\.(xlsx?|pdf)$")
  if (length(files_in_uploads) == 0) {
    stop("Uploads folder exists but contains no CFSR files: ", folder_uploads,
         "\n\nExpected to find files like:",
         "\n  - National - Supplemental Context Data - [Month Year].xlsx",
         "\n  - ", state_code, " - CFSR 4 Data Profile - [Month Year].pdf",
         "\n\nPlease check that files are organized correctly.",
         call. = FALSE)
  }

  # Processed and app_data folders will be created as needed during processing
  # (See cfsr_profile.R where folder_run is created, and prepare_app_data.R)

  # Assign to global environment if requested
  if (assign_globals) {
    assign("state_code", state_code, envir = .GlobalEnv)
    assign("profile_period", profile_period, envir = .GlobalEnv)
    assign("folder_uploads", folder_uploads, envir = .GlobalEnv)
    assign("folder_processed", folder_processed, envir = .GlobalEnv)
    assign("folder_app_data", folder_app_data, envir = .GlobalEnv)
    assign("base_data_dir", base_data_dir, envir = .GlobalEnv)

    # Also set folder_raw for backward compatibility with generic find_file
    assign("folder_raw", folder_uploads, envir = .GlobalEnv)
  }

  # Return list of paths
  list(
    state_code = state_code,
    profile_period = profile_period,
    folder_uploads = folder_uploads,
    folder_processed = folder_processed,
    folder_app_data = folder_app_data,
    base_data_dir = base_data_dir
  )
}

#' Find CFSR file in uploads folder
#'
#' Wrapper around generic find_file() that uses CFSR folder structure
#' Looks in data/uploads/{STATE}/{PERIOD}/ for files
#'
#' @param keyword Search keyword (e.g., "National", "Maryland")
#' @param file_type Type of file: "excel" or "csv"
#' @param sheet_name Excel sheet name (if file_type = "excel")
#' @param col_types Column types for CSV reading
#' @param skip Number of rows to skip
#' @return Data frame with file contents
find_cfsr_file <- function(keyword,
                            file_type = "excel",
                            sheet_name = NULL,
                            col_types = NULL,
                            skip = 0) {

  # Check that CFSR folders are set up
  if (!exists("folder_uploads", envir = .GlobalEnv)) {
    stop("folder_uploads not found. Run setup_cfsr_folders() first.")
  }

  # Get upload folder from global environment
  folder_uploads <- get("folder_uploads", envir = .GlobalEnv)

  if (!dir.exists(folder_uploads)) {
    stop("Uploads folder does not exist: ", folder_uploads)
  }

  # Build file pattern
  file_pattern <- switch(
    tolower(file_type),
    excel = "(?i)\\.(xlsx|xlsm)$",
    csv   = "(?i)\\.csv$",
    stop("Invalid file_type. Supported types are 'excel' and 'csv'.")
  )

  # List files in uploads folder
  files <- list.files(folder_uploads, pattern = file_pattern,
                     full.names = TRUE, recursive = FALSE)
  files <- files[!grepl("~\\$", files)]  # Exclude temp files

  # Find matching file
  master_file <- grep(keyword, files, value = TRUE, ignore.case = TRUE)

  if (length(master_file) == 0) {
    stop("No file found matching keyword '", keyword, "' in: ", folder_uploads)
  }
  if (length(master_file) > 1) {
    warning("Multiple files found matching '", keyword, "'. Using first: ",
            basename(master_file[1]))
    master_file <- master_file[1]
  }

  message("Reading file: ", basename(master_file))

  # Read file
  if (tolower(file_type) == "excel") {
    data_df <- openxlsx::read.xlsx(
      xlsxFile = master_file,
      sheet = if (is.null(sheet_name)) 1 else sheet_name,
      detectDates = TRUE
    )

    if (!is.null(col_types)) {
      for (nm in names(col_types)) {
        if (nm %in% names(data_df)) {
          data_df[[nm]] <- as.character(data_df[[nm]])
        } else {
          warning("Column ", nm, " not found; cannot force to character.")
        }
      }
    }
  } else {
    # CSV
    if (is.null(col_types)) {
      data_df <- readr::read_csv(master_file, skip = skip, show_col_types = FALSE)
    } else {
      data_df <- readr::read_csv(
        master_file,
        skip = skip,
        col_types = readr::cols(.default = readr::col_guess(), !!!col_types)
      )
    }
  }

  return(data_df)
}

# ============================================================================
# INDICATOR DICTIONARY FUNCTIONS
# ============================================================================

#' Load indicator dictionary
#'
#' Loads the CFSR indicator metadata dictionary containing official indicator names
#' Dictionary location: cfsr-profile/code/cfsr_round4_indicators_dictionary.csv
#'
#' @return Named vector where names are sheet names and values are indicator display names
load_indicator_dictionary <- function() {
  # Try to find the dictionary file
  dict_paths <- c(
    "D:/repo_childmetrix/cfsr-profile/code/cfsr_round4_indicators_dictionary.csv",
    file.path(getwd(), "code", "cfsr_round4_indicators_dictionary.csv"),
    file.path(dirname(getwd()), "code", "cfsr_round4_indicators_dictionary.csv")
  )

  dict_file <- NULL
  for (path in dict_paths) {
    if (file.exists(path)) {
      dict_file <- path
      break
    }
  }

  if (is.null(dict_file)) {
    warning("Indicator dictionary not found. Searched:\n  ", paste(dict_paths, collapse = "\n  "))
    return(NULL)
  }

  # Load dictionary
  dict <- read.csv(dict_file, stringsAsFactors = FALSE)

  # Create mapping from sheet name to indicator name
  # Based on the CSV, create a named vector
  indicator_map <- c(
    "Entry rates" = dict$indicator[dict$indicator_short == "Foster care entry rate"],
    "Maltreatment in care" = dict$indicator[dict$indicator_short == "Maltreatment in foster care"],
    "Recurrence of maltreatment" = dict$indicator[dict$indicator_short == "Maltreatment recurrence within 12 months"],
    "Perm in 12 (entries)" = dict$indicator[dict$indicator_short == "Perm in 12 months (entries)"],
    "Perm in 12 (12-23 mos)" = dict$indicator[dict$indicator_short == "Perm in 12 months (12-23 months)"],
    "Perm in 12 (24+ mos)" = dict$indicator[dict$indicator_short == "Perm in 12 months (24 months or more)"],
    "Placement stability" = dict$indicator[dict$indicator_short == "Placement stability"],
    "Reentry to FC" = dict$indicator[dict$indicator_short == "Reentry to foster care within 12 months"]
  )

  return(indicator_map)
}

#' Get indicator name from dictionary by sheet name
#'
#' Looks up the official indicator name from the dictionary
#' Falls back to provided name if dictionary not available
#'
#' @param sheet_name Excel sheet name
#' @param fallback_name Name to use if dictionary lookup fails
#' @return Official indicator name
get_indicator_name <- function(sheet_name, fallback_name = NULL) {
  # Try to get from global environment if already loaded
  if (!exists("indicator_dict", envir = .GlobalEnv)) {
    indicator_dict <- load_indicator_dictionary()
    if (!is.null(indicator_dict)) {
      assign("indicator_dict", indicator_dict, envir = .GlobalEnv)
    }
  } else {
    indicator_dict <- get("indicator_dict", envir = .GlobalEnv)
  }

  # Lookup the name
  if (!is.null(indicator_dict) && sheet_name %in% names(indicator_dict)) {
    return(indicator_dict[[sheet_name]])
  }

  # Fallback
  if (!is.null(fallback_name)) {
    return(fallback_name)
  }

  # Last resort: use sheet name
  warning("No indicator name found for sheet '", sheet_name, "'. Using sheet name as indicator name.")
  return(sheet_name)
}

# ============================================================================
# METADATA EXTRACTION FUNCTIONS
# ============================================================================

#' Extract profile month/year from file name
#'
#' Reads the first Excel file in folder_raw whose name contains "National"
#' and parses "Month YYYY" from the file name.
#'
#' @param file_path Path to National Excel file (optional - uses folder_raw if NULL)
#' @param data_df Data frame (unused - kept for backward compatibility)
#' @return List with file_path, profile_version, month, year, source
#' @examples
#' # Example file name: "National - Supplemental Context Data - February 2025.xlsx"
#' cfsr_profile_version()
cfsr_profile_version <- function(file_path = NULL, data_df = NULL) {
  if (!is.null(file_path)) {
    f <- file_path
  } else {
    if (!exists("folder_raw")) stop("folder_raw is not defined.")
    if (!dir.exists(folder_raw)) stop("folder_raw does not exist: ", folder_raw)
    files <- list.files(folder_raw, pattern = "National.*\\.xlsx$", full.names = TRUE)
    if (length(files) == 0) stop("No 'National*.xlsx' file found in: ", folder_raw)
    f <- files[1]
  }

  fname <- basename(f)

  # Capture FULL "Month YYYY" (wrap both month and year in the same capture group)
  month_year <- sub(
    ".*\\b((January|February|March|April|May|June|July|August|September|October|November|December)\\s+[0-9]{4})\\b.*",
    "\\1",
    fname
  )
  if (identical(month_year, fname)) stop("Couldn't find 'Month YYYY' in file name: ", fname)

  parts <- strsplit(month_year, " ")[[1]]
  month <- parts[1]
  year  <- parts[2]

  source <- paste0(
    "Children's Bureau. (", year, ", ", month, "). National - supplemental context data - ",
    month, " ", year, " [Data file]. U.S. Department of Health & Human Services, ",
    "Administration for Children and Families, Administration on Children, Youth and Families."
  )

  list(
    file_path = f,
    profile_version = month_year,  # e.g., "February 2025"
    month = month,
    year = year,
    source = source
  )
}

#' Extract AFCARS/NCANDS "as of" date
#'
#' Extract the AFCARS/NCANDS "as of" date from the first column text
#' Expects a row like: "AFCARS and NCANDS submissions as of 08-15-2024 ..."
#'
#' @param data_df Data frame with AFCARS/NCANDS header row
#' @return List with row_index, header_text, date_string, as_of_date
cfsr_profile_extract_asof_date <- function(data_df) {
  stopifnot(is.data.frame(data_df), ncol(data_df) >= 1)

  i <- which(grepl("^AFCARS and NCANDS submissions as of", data_df[[1]]))[1]
  if (is.na(i)) stop("No row starting with 'AFCARS and NCANDS submissions as of' found in first column.")

  header_text <- as.character(data_df[i, 1])
  date_string <- sub(".*submissions as of (\\d+-\\d+-\\d+).*", "\\1", header_text)
  as_of_date  <- as.Date(date_string, format = "%m-%d-%Y")

  if (is.na(as_of_date)) {
    stop("Found the header row, but could not parse a date like MM-DD-YYYY from it. Got: '", date_string, "'.")
  }

  # make it global
  assign("as_of_date", as_of_date, envir = .GlobalEnv)

  list(
    row_index = i,
    header_text = header_text,
    date_string = date_string,
    as_of_date = as_of_date
  )
}

#' Extract metadata from PDF filename
#'
#' Parses state code and profile version from PDF filename
#'
#' @param pdf_path Path to PDF file
#' @return List with file_path, state, profile_version, month, year, source
#' @examples
#' # Example: "MD - CFSR 4 Data Profile - August 2024.pdf"
#' extract_pdf_metadata(pdf_path)
extract_pdf_metadata <- function(pdf_path) {
  fname <- basename(pdf_path)

  # Extract state code (first 2 characters before " - ")
  state <- toupper(substr(fname, 1, 2))

  # Extract Month YYYY from filename
  month_year <- sub(
    ".*\\b((January|February|March|April|May|June|July|August|September|October|November|December)\\s+[0-9]{4})\\b.*",
    "\\1",
    fname
  )

  if (identical(month_year, fname)) {
    stop("Couldn't find 'Month YYYY' in PDF file name: ", fname)
  }

  parts <- strsplit(month_year, " ")[[1]]
  month <- parts[1]
  year <- parts[2]

  # Build source citation for PDF
  # Format: Children's Bureau. (YYYY, MMM). [STATE] - CFSR 4 Data Profile - MMM YYYY [pdf file]. ...
  month_abbrev <- substr(month, 1, 3)
  source <- paste0(
    "Children's Bureau. (", year, ", ", month_abbrev, "). ",
    state, " - CFSR 4 Data Profile - ", month_abbrev, " ", year, " [pdf file]. ",
    "U.S. Department of Health & Human Services, Administration for Children and Families, ",
    "Administration on Children, Youth and Families."
  )

  list(
    file_path = pdf_path,
    state = state,
    profile_version = month_year,
    month = month,
    year = year,
    source = source
  )
}

# ============================================================================
# STATE RANKING FUNCTIONS
# ============================================================================

#' Rank states by performance for all periods
#'
#' Ranks states within each period based on indicator direction (up/down)
#' Uses indicator dictionary to determine if higher or lower is better
#'
#' @param df Data frame with columns: state, indicator, period, performance
#' @return Data frame with added columns: state_rank, reporting_states
rank_states_by_performance <- function(df) {

  # Load dictionary to get direction_desired for this indicator
  # Try multiple possible paths
  possible_paths <- c(
    "D:/repo_childmetrix/cfsr-profile/code/cfsr_round4_indicators_dictionary.csv",
    "code/cfsr_round4_indicators_dictionary.csv",
    file.path(getwd(), "code", "cfsr_round4_indicators_dictionary.csv"),
    file.path(dirname(getwd()), "code", "cfsr_round4_indicators_dictionary.csv")
  )

  dict_path <- NULL
  for (path in possible_paths) {
    if (file.exists(path)) {
      dict_path <- path
      break
    }
  }

  if (!is.null(dict_path)) {
    dict <- read.csv(dict_path, stringsAsFactors = FALSE)

    # Get the indicator name from the dataframe
    indicator_name <- df$indicator[1]

    # Look up direction_desired for this indicator
    direction <- dict$direction_desired[dict$indicator == indicator_name]

    # If direction not found, default to "down" (lower is better - safer default)
    if (length(direction) == 0 || is.na(direction)) {
      direction <- "down"
      warning("Direction not found for indicator: ", indicator_name, ". Defaulting to 'down'.")
    }
  } else {
    # If dictionary file not found, default to "down" (lower is better - safer default)
    direction <- "down"
    warning("Dictionary file not found at expected locations. Defaulting to 'down' direction for ranking.")
  }

  # Rank within each period and calculate reporting_states
  df %>%
    # Group by period so that ranking happens within each period
    group_by(period) %>%
    mutate(
      # Rank based on direction for ALL periods
      # "up" = higher is better, so rank descending (-performance)
      # "down" = lower is better, so rank ascending (performance)
      state_rank = if (direction == "up") {
        rank(-performance, ties.method = "min", na.last = "keep")
      } else {
        rank(performance, ties.method = "min", na.last = "keep")
      },
      # Count reporting states (non-NA ranks) for this period
      reporting_states = sum(!is.na(state_rank))
    ) %>%
    ungroup()
}
