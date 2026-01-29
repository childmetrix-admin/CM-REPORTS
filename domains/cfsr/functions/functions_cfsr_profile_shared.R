########################################
########################################
# CFSR SHARED FUNCTIONS
########################################
########################################

# Shared functions used across CFSR profile processing:
# - config.R (orchestration and setup)
# - profile_pdf_rsp.R (Risk-Standardized Performance extraction)
# - profile_pdf_observed.R (Observed Performance extraction)
# - profile_excel_national.R (National Comparison Data extraction)
#
# Organization:
# 1. CONFIG-ONLY FUNCTIONS - Called only by config.R
# 2. SHARED FUNCTIONS - Used by both config.R and profile scripts

########################################
# CONFIG-ONLY FUNCTIONS ----
########################################

# These functions are called only by config.R during initialization

#' Extract metadata from PDF filename
#'
#' Parses state code and profile version from PDF filename
#' Called by config.R's initialize_common_globals() to set pdf_metadata global
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

########################################
# SHARED FUNCTIONS ----
########################################

# These functions are used by both config.R and profile extraction scripts

########################################
# STATE NAME CONVERSION ----
########################################

# State code utilities - Using shared/utils/state_utils.R as single source of truth
# (state_utils.R is sourced via config.R)
#
# Create aliases for backward compatibility with existing code
convert_state_code_to_name <- state_code_to_name
convert_state_name_to_code <- state_name_to_code
CFSR_STATE_CODES <- STATE_CODES

########################################
# DICTIONARY JOIN HELPER ----
########################################

#' Join indicator dictionary metadata to extracted data
#'
#' Loads the CFSR Round 4 indicators dictionary and left joins all metadata
#' columns to the provided data frame. Checks for and warns about missing joins.
#'
#' @param data Data frame with an 'indicator' column
#' @return Data frame with dictionary columns joined
#' @examples
#' rsp_data <- join_indicator_dictionary(rsp_data)
join_indicator_dictionary <- function(data) {
  # Use portable monorepo path (CFSR_EXTRACTION_DIR defined in paths.R)
  dict_path <- file.path(CFSR_EXTRACTION_DIR, "cfsr_round4_indicators_dictionary.csv")

  if (!file.exists(dict_path)) {
    stop("Dictionary not found at: ", dict_path)
  }

  # Load dictionary
  dict <- read.csv(dict_path, stringsAsFactors = FALSE)

  # Join ALL dictionary metadata
  result <- data %>%
    left_join(
      dict %>% select(
        indicator,
        indicator_sort,
        indicator_short,
        indicator_very_short,
        category,
        description,
        denominator_def = denominator,
        numerator_def = numerator,
        national_standard,
        direction_rule,
        direction_desired,
        direction_legend,
        decimal_precision,
        scale,
        format,
        risk_adjustment,
        exclusions,
        notes
      ),
      by = "indicator"
    )

  # Check for missing joins
  missing_joins <- result %>%
    filter(is.na(category)) %>%
    distinct(indicator)

  if (nrow(missing_joins) > 0) {
    warning("The following indicators did not match the dictionary:\n  ",
            paste(missing_joins[["indicator"]], collapse = "\n  "))
  }

  return(result)
}

########################################
# PDF EXTRACTION HELPERS ----
########################################

# Coordinate-based text extraction using pdftools
# Used by profile_pdf_rsp.R and profile_pdf_observed.R

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

########################################
# FILE OPERATIONS ----
########################################

# File discovery and loading functions
# Used by config.R and profile extraction scripts

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
find_cfsr_file <- function(keyword = NULL,
                            file_type = "excel",
                            sheet_name = NULL,
                            col_types = NULL,
                            skip = 0,
                            state_code = NULL) {

  # Check that CFSR folders are set up
  if (!exists("folder_uploads", envir = .GlobalEnv)) {
    stop("folder_uploads not found. Run setup_cfsr_folders() first.")
  }

  # Get upload folder from global environment
  folder_uploads <- get("folder_uploads", envir = .GlobalEnv)

  if (!dir.exists(folder_uploads)) {
    stop("Uploads folder does not exist: ", folder_uploads)
  }

  # Build keyword dynamically if state_code provided
  if (is.null(keyword) && !is.null(state_code)) {
    keyword <- convert_state_code_to_name(toupper(state_code))
  } else if (is.null(keyword)) {
    keyword <- "National"  # Default to National if neither keyword nor state_code provided
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

########################################
# INDICATOR DICTIONARY FUNCTIONS ----
########################################

# Dictionary loading and lookup
# Used by functions_cfsr_profile_nat.R

#' Load indicator dictionary
#'
#' Loads the CFSR indicator metadata dictionary containing official indicator names
#' Dictionary location: cfsr-profile/code/cfsr_round4_indicators_dictionary.csv
#'
#' @return Named vector where names are sheet names and values are indicator display names
load_indicator_dictionary <- function() {
  # Use portable monorepo path (CFSR_EXTRACTION_DIR defined in paths.R)
  dict_file <- file.path(CFSR_EXTRACTION_DIR, "cfsr_round4_indicators_dictionary.csv")

  if (!file.exists(dict_file)) {
    warning("Indicator dictionary not found at: ", dict_file)
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

########################################
# METADATA EXTRACTION FUNCTIONS ----
########################################

# Profile version and date extraction
# Used by config.R and profile extraction scripts

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
cfsr_profile_version <- function(file_path = NULL, data_df = NULL, state_code = NULL) {
  if (!is.null(file_path)) {
    f <- file_path
  } else {
    if (!exists("folder_raw")) stop("folder_raw is not defined.")
    if (!dir.exists(folder_raw)) stop("folder_raw does not exist: ", folder_raw)

    # Build pattern based on state_code
    if (!is.null(state_code)) {
      state_name <- convert_state_code_to_name(toupper(state_code))
      pattern <- paste0(state_name, ".*\\.xlsx$")
    } else {
      pattern <- "National.*\\.xlsx$"
    }

    files <- list.files(folder_raw, pattern = pattern, full.names = TRUE)
    if (length(files) == 0) stop("No file matching pattern '", pattern, "' found in: ", folder_raw)
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

  # Build source citation - use state name for state files, "National" for national file
  if (!is.null(state_code)) {
    state_name <- convert_state_code_to_name(toupper(state_code))
    data_type <- paste0(state_name, " - supplemental context data")
  } else {
    data_type <- "National - supplemental context data"
  }

  source <- paste0(
    "Children's Bureau. (", year, ", ", month, "). ", data_type, " - ",
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

########################################
# STATE RANKING FUNCTIONS ----
########################################

# State performance ranking
# Used by functions_cfsr_profile_nat.R

#' Rank states by performance for all periods
#'
#' Ranks states within each period based on indicator direction (up/down)
#' Uses indicator dictionary to determine if higher or lower is better
#'
#' @param df Data frame with columns: state, indicator, period, performance
#' @return Data frame with added columns: state_rank, reporting_states
rank_states_by_performance <- function(df) {

  # Load dictionary to get direction_desired for this indicator
  # Use portable monorepo path (CFSR_EXTRACTION_DIR defined in paths.R)
  dict_path <- file.path(CFSR_EXTRACTION_DIR, "cfsr_round4_indicators_dictionary.csv")

  if (file.exists(dict_path)) {
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
    warning("Dictionary file not found at: ", dict_path, ". Defaulting to 'down' direction for ranking.")
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

########################################
# PERIOD FORMATTING ----
########################################

# Period string conversion to human-readable labels
# Used by all profile extraction scripts

#' Convert CFSR period strings to meaningful date labels
#'
#' Converts various CFSR period format codes to human-readable date labels.
#' Handles period formats from both RSP and Observed data extraction,
#' including standard AFCARS periods, maltreatment periods, and cohort ranges.
#'
#' @param period Character vector of period codes to format
#'
#' @return Character vector of formatted period labels
#'
#' @details
#' Handles 6 distinct period format patterns:
#'
#' **Case 1: YYAYYB** (e.g., "20A20B")
#' - Oct 'prev_year - Sep 'year
#' - Example: "20A20B" → "Oct '19 - Sep '20"
#'
#' **Case 2: YYBYYA** (e.g., "19B20A")
#' - Apr 'year - Mar 'next_year
#' - Example: "19B20A" → "Apr '19 - Mar '20"
#'
#' **Case 3: YYAB_FYYY** (e.g., "20AB_FY20")
#' - Oct 'prev_year - Sep 'year, FYYY
#' - AFCARS AB (two 6-month submissions) + NCANDS FY
#' - RSP/Observed use underscore separator
#' - Example: "20AB_FY20" → "Oct '19 - Sep '20, FY20"
#'
#' **Case 3a: YYAB,FYYY** (e.g., "20AB,FY20")
#' - Oct 'prev_year - Sep 'year, FYYY
#' - AFCARS AB (two 6-month submissions) + NCANDS FY
#' - National data uses comma separator
#' - Example: "20AB,FY20" → "Oct '19 - Sep '20, FY20"
#'
#' **Case 4: FYYY-YY** (e.g., "FY20-21")
#' - Fiscal year spans (kept as-is)
#' - Two NCANDS FY submissions
#' - Example: "FY20-21" → "FY20-21"
#'
#' **Case 5: YYA-YYA or YYB-YYB** (e.g., "19B-21B")
#' - Multi-year cohort periods
#' - Appears in RSP "Data used" row
#' - Example: "19B-21B" → "Apr '19 - Sep '21"
#'
#' @examples
#' make_period_meaningful(c("20A20B", "19B20A", "20AB_FY20", "20AB,FY20", "FY20-21", "19B-21B"))
#' # Returns: "Oct '19 - Sep '20", "Apr '19 - Mar '20", "Oct '19 - Sep '20, FY20",
#' #          "Oct '19 - Sep '20, FY20", "FY20-21", "Apr '19 - Sep '21"
#'
#' @note This function is vectorized for element-wise application over character vectors
make_period_meaningful <- function(period) {
  if (is.na(period) || period == "" || period == "NA") {
    return(NA_character_)
  }

  # Clean period: trim whitespace and remove internal spaces
  # Handles cases like "23AB_ FY23" (space after underscore) from Excel extraction
  period <- trimws(period)
  period <- gsub("\\s+", "", period)  # Remove all whitespace

  # Case 1: Format "YYAYYB" (e.g., "20A20B") => Oct 'prev_year - Sep 'year
  if (grepl("^[0-9]{2}A[0-9]{2}B$", period)) {
    year1 <- as.numeric(substr(period, 1, 2))
    year2 <- as.numeric(substr(period, 4, 5))
    start_year <- (year1 - 1) + 2000
    start_label <- paste0("Oct '", substr(as.character(start_year), 3, 4))
    end_label <- paste0("Sep '", substr(as.character(year2 + 2000), 3, 4))
    return(paste(start_label, "-", end_label))
  }

  # Case 2: Format "YYBYYA" (e.g., "19B20A") => Apr 'year - Mar 'next_year
  if (grepl("^[0-9]{2}B[0-9]{2}A$", period)) {
    year1 <- as.numeric(substr(period, 1, 2))
    year2 <- as.numeric(substr(period, 4, 5))
    start_label <- paste0("Apr '", substr(as.character(year1 + 2000), 3, 4))
    end_label <- paste0("Mar '", substr(as.character(year2 + 2000), 3, 4))
    return(paste(start_label, "-", end_label))
  }

  # Case 3: Format "YYAB_FYYY" (e.g., "20AB_FY20") => Oct 'prev_year - Sep 'year, FY20
  # RSP/Observed use underscore separator (different from National which uses comma)
  # String positions: "20AB_FY20"
  #                    123456789
  if (grepl("^[0-9]{2}AB_FY[0-9]{2}$", period)) {
    year <- as.numeric(substr(period, 1, 2))
    fy_year <- substr(period, 8, 9)  # Keep as 2-digit string
    start_year <- (year - 1) + 2000
    end_year <- year + 2000
    return(paste0("Oct '", substr(as.character(start_year), 3, 4),
                  " - Sep '", substr(as.character(end_year), 3, 4),
                  ", FY", fy_year))
  }

  # Case 3a: Format "YYAB,FYYY" (e.g., "20AB,FY20") => Oct 'prev_year - Sep 'year, FY20
  # National data uses comma separator (different from RSP/Observed which use underscore)
  # String positions: "20AB,FY20"
  #                    123456789
  if (grepl("^[0-9]{2}AB,FY[0-9]{2}$", period)) {
    year <- as.numeric(substr(period, 1, 2))
    fy_year <- substr(period, 8, 9)  # Keep as 2-digit string
    start_year <- (year - 1) + 2000
    end_year <- year + 2000
    return(paste0("Oct '", substr(as.character(start_year), 3, 4),
                  " - Sep '", substr(as.character(end_year), 3, 4),
                  ", FY", fy_year))
  }

  # Case 4: Format "FYYY-YY" (e.g., "FY20-21") => FY20-21 (keep as-is)
  if (grepl("^FY[0-9]{2}-[0-9]{2}$", period)) {
    return(period)
  }

  # Case 5: Format with hyphen ranges like "19B-21B" or "20A-22A" (cohort periods)
  # These appear in the RSP "Data used" row and represent multi-year cohorts
  if (grepl("^[0-9]{2}[AB]-[0-9]{2}[AB]$", period)) {
    # Extract start and end
    start_part <- substr(period, 1, 3)  # e.g., "19B"
    end_part <- substr(period, 5, 7)    # e.g., "21B"

    start_year <- as.numeric(substr(start_part, 1, 2)) + 2000
    start_half <- substr(start_part, 3, 3)
    end_year <- as.numeric(substr(end_part, 1, 2)) + 2000
    end_half <- substr(end_part, 3, 3)

    # A = Oct-Mar, B = Apr-Sep
    start_month <- if (start_half == "A") "Oct" else "Apr"
    end_month <- if (end_half == "A") "Mar" else "Sep"

    # Adjust start year for A period (Oct of previous year)
    if (start_half == "A") start_year <- start_year - 1

    return(paste0(start_month, " '", substr(as.character(start_year), 3, 4),
                  " - ", end_month, " '", substr(as.character(end_year), 3, 4)))
  }

  # Fallback: return NA if no pattern matches
  return(NA_character_)
}

# Vectorize the function for element-wise application
make_period_meaningful <- Vectorize(make_period_meaningful)

#' Standardize dimension values for national and state data
#'
#' Applies consistent recoding to dimension_value column:
#' - Locality dimension: Strips " County" suffix (except "Baltimore County"), capitalizes "Baltimore City"
#' - Race/ethnicity dimension: Standardizes race/ethnicity names
#'
#' @param data Data frame with dimension and dimension_value columns
#' @return Data frame with standardized dimension_value column
standardize_dimension_values <- function(data) {
  data %>%
    mutate(dimension_value = case_when(
      # Apply to Locality dimension (county names)
      grepl("^Locality$", dimension, ignore.case = TRUE) ~ case_when(
        dimension_value == "Baltimore city" ~ "Baltimore City",  # Capitalize City
        dimension_value == "Baltimore County" ~ "Baltimore County",  # Exception: keep as-is
        TRUE ~ str_replace(dimension_value, " County$", "")  # Strip " County" suffix
      ),
      # Apply to race/ethnicity dimension
      grepl("Race", dimension, ignore.case = TRUE) ~ case_when(
        dimension_value == "American Indian/Alaska Native-Non Hispanic" ~ "American Indian/Alaska Native",
        dimension_value == "Asian-Non Hispanic" ~ "Asian",
        dimension_value == "Black or African American-Non Hispanic" ~ "Black or African American",
        dimension_value == "Hispanic" ~ "Hispanic (of any race)",
        dimension_value == "Native Hawaiian/Other Pacific Islander-Non Hispanic" ~ "Native Hawaiian/Other Pacific Islander",
        dimension_value == "Two or More-Non Hispanic" ~ "Two or More",
        dimension_value == "White-Non Hispanic" ~ "White",
        TRUE ~ dimension_value  # Keep unchanged (Unknown/Unable to Determine, Missing Race/Ethnicity Data)
      ),
      TRUE ~ dimension_value  # Other dimensions, keep unchanged
    ))
}
