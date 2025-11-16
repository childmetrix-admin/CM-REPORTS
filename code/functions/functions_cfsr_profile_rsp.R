# ============================================================================
# CFSR-SPECIFIC FOLDER SETUP AND FILE FINDING
# ============================================================================
#
# These functions override the generic versions for CFSR project needs:
# - Multi-state support (MD, KY, etc.)
# - New folder structure: data/uploads/{STATE}/{PERIOD}/
# - Process from uploads, save to state-specific processed folders

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
                                base_data_dir = "D:/repo_childmetrix/cfsr-profile-pdf/data") {

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

# Load indicator dictionary
# ----------------------------
#
# Loads the CFSR indicator metadata dictionary containing official indicator names
# Dictionary location: cfsr-profile/code/cfsr_round4_indicators_dictionary.csv
#
# @return: Named vector where names are sheet names and values are indicator display names

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

# Get indicator name from dictionary by sheet name
# ----------------------------
#
# Looks up the official indicator name from the dictionary
# Falls back to provided name if dictionary not available
#
# @param sheet_name: Excel sheet name
# @param fallback_name: Name to use if dictionary lookup fails
# @return: Official indicator name

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

# Extract profile month/year from file name
# ----------------------------

# Reads the first Excel file in folder_raw whose name contains "National"
# and parses "Month YYYY" from the file name.
#
# Example file name:
#   "National - Supplemental Context Data - February 2025.xlsx"

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

# Extract AFCARS/NCANDS "as of" date
# ----------------------------

# Extract the AFCARS/NCANDS "as of" date from the first column text
# Expects a row like: "AFCARS and NCANDS submissions as of 08-15-2024 ..."
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

# Convert a period string (e.g., 19A19B) to a meaningful period label
# -------------------------------

make_period_meaningful <- function(period) {
  if (grepl("^[0-9]{2}A[0-9]{2}B$", period)) {
    # Case 1: Format "YYAYYB" (e.g., "19A19B") => Oct 'prev_year - Sep 'year
    year1 <- as.numeric(substr(period, 1, 2))
    year2 <- as.numeric(substr(period, 4, 5))
    start_year <- (year1 - 1) + 2000
    start_label <- paste0("Oct '", substr(as.character(start_year), 3, 4))
    end_label <- paste0("Sep '", substr(as.character(year2 + 2000), 3, 4))
    return(paste(start_label, "-", end_label))
  } else if (grepl("^[0-9]{2}B[0-9]{2}A$", period)) {
    # Case 2: Format "YYBYYA" (e.g., "19B20A") => Apr 'year - Mar 'next_year
    year1 <- as.numeric(substr(period, 1, 2))
    year2 <- as.numeric(substr(period, 4, 5))
    start_label <- paste0("Apr '", substr(as.character(year1 + 2000), 3, 4))
    end_label <- paste0("Mar '", substr(as.character(year2 + 2000), 3, 4))
    return(paste(start_label, "-", end_label))
  } else if (grepl("^[0-9]{2}AB,FY[0-9]{2}$", period)) {
    # Case 3: Format "YYAB,FYYY" (e.g., "20AB,FY20") => Oct 'prev_year - Sep 'year, FY year
    # AFCARS AB (two 6-month submissions) + NCANDS FY
    # String positions: "20AB,FY20"
    #                    12345678 9
    year <- as.numeric(substr(period, 1, 2))
    fy_year <- as.numeric(substr(period, 8, 9))  # Fixed: was 7,8 should be 8,9
    start_year <- (year - 1) + 2000
    end_year <- year + 2000
    fy_full <- fy_year + 2000
    return(paste0("Oct '", substr(as.character(start_year), 3, 4),
                  " - Sep '", substr(as.character(end_year), 3, 4),
                  ", FY ", fy_full))
  } else if (grepl("^FY[0-9]{2}-[0-9]{2}$", period)) {
    # Case 4: Format "FYYY-YY" (e.g., "FY20-21") => FY year1 - year2
    # Two NCANDS FY submissions
    year1 <- as.numeric(substr(period, 3, 4))
    year2 <- as.numeric(substr(period, 6, 7))
    fy1_full <- year1 + 2000
    fy2_full <- year2 + 2000
    return(paste0("FY ", fy1_full, " - ", fy2_full))
  } else {
    return(NA_character_)
  }
}

# Vectorize the function so that it can be applied over a vector of period values
make_period_meaningful <- Vectorize(make_period_meaningful)

# Rank states by performance for all periods
# -------------------------------

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

# ============================================================================
# PDF EXTRACTION FUNCTIONS
# ============================================================================

#' Extract CFSR Profile from Adobe-Exported Text File
#'
#' Reads RSP data from a text file exported from Adobe Acrobat (File > Export To > Text)
#'
#' @param txt_path Path to exported text file
#' @return Dataframe with indicator data
#' @examples
#' data <- extract_cfsr_profile_txt("path/to/exported.txt")
extract_cfsr_profile_txt <- function(txt_path) {

  library(tidyverse)

  # Read the text file with encoding handling
  lines <- readLines(txt_path, encoding = "UTF-8", warn = FALSE)
  # Remove special characters
  lines <- iconv(lines, from = "UTF-8", to = "ASCII", sub = "")
  # Trim whitespace
  lines <- str_trim(lines)

  message("Read ", length(lines), " lines from text file")

  # Helper function to extract data starting from an RSP marker
  extract_indicator_block <- function(start_idx, ind_name) {

    # Find the RSP line
    rsp_idx <- start_idx
    if (lines[rsp_idx] != "RSP") {
      warning("Expected RSP at line ", rsp_idx, " for ", ind_name)
      return(NULL)
    }

    # Collect RSP values (lines after "RSP" until we hit something else)
    rsp_values <- c()
    i <- rsp_idx + 1
    while (i <= length(lines) && str_detect(lines[i], "^(DQ\\*?|\\d+\\.\\d+%?)$")) {
      rsp_values <- c(rsp_values, lines[i])
      i <- i + 1
    }

    # Find National Performance (has % with arrow symbol)
    np_idx <- which(str_detect(lines, "^\\d+\\.\\d+%") & i > rsp_idx)[1]
    national_perf <- if (!is.na(np_idx)) str_extract(lines[np_idx], "\\d+\\.\\d+%?") else NA_character_

    # Find RSPinterval
    interval_idx <- which(lines == "RSPinterval" & seq_along(lines) > rsp_idx)[1]
    intervals <- c()
    if (!is.na(interval_idx)) {
      i <- interval_idx + 1
      while (i <= length(lines) && str_detect(lines[i], "^\\d+\\.\\d+-\\d+\\.\\d+%?")) {
        intervals <- c(intervals, str_extract(lines[i], "\\d+\\.\\d+-\\d+\\.\\d+%?"))
        i <- i + 1
      }
    }

    # Find Dataused
    data_idx <- which(lines == "Dataused" & seq_along(lines) > rsp_idx)[1]
    periods <- c()
    if (!is.na(data_idx)) {
      i <- data_idx + 1
      while (i <= length(lines) && str_detect(lines[i], "[0-9]{2}[AB]-[0-9]{2}[AB]|FY[0-9]{2}-[0-9]{2}|[0-9]{2}[AB]-[0-9]{2}[AB],FY")) {
        periods <- c(periods, lines[i])
        i <- i + 1
      }
    }

    # Build dataframe - ensure all vectors are same length
    n_values <- length(rsp_values)

    # Pad periods to match rsp_values length
    if (length(periods) < n_values) {
      periods <- c(periods, rep(NA_character_, n_values - length(periods)))
    } else if (length(periods) > n_values) {
      periods <- periods[1:n_values]
    }

    # Pad intervals to match rsp_values length
    if (length(intervals) < n_values) {
      intervals <- c(intervals, rep(NA_character_, n_values - length(intervals)))
    } else if (length(intervals) > n_values) {
      intervals <- intervals[1:n_values]
    }

    tibble(
      indicator = ind_name,
      national_performance = national_perf,
      period = periods,
      rsp_value = rsp_values,
      rsp_interval = intervals
    )
  }

  # Find all RSP markers
  rsp_indices <- which(lines == "RSP")

  message("Found ", length(rsp_indices), " RSP markers")

  # Extract each indicator
  # Based on the accessible text structure:
  # RSP markers are at specific indices for each of 7 indicators
  all_data <- bind_rows(
    extract_indicator_block(rsp_indices[1], "Permanency in 12 months (entries)"),
    extract_indicator_block(rsp_indices[2], "Permanency in 12 months (12-23 mos)"),
    extract_indicator_block(rsp_indices[3], "Permanency in 12 months (24+ mos)"),
    extract_indicator_block(rsp_indices[4], "Reentry to foster care"),
    extract_indicator_block(rsp_indices[5], "Placement stability"),
    extract_indicator_block(rsp_indices[6], "Maltreatment in care"),
    extract_indicator_block(rsp_indices[7], "Recurrence of maltreatment")
  )

  # Clean up the data
  all_data <- all_data %>%
    filter(!is.na(period)) %>%
    mutate(
      # Flag DQ issues
      data_quality_issue = str_detect(rsp_value, "DQ"),
      # Convert to numeric (remove % signs)
      rsp_numeric = ifelse(data_quality_issue, NA_real_, as.numeric(str_remove(rsp_value, "%"))),
      np_numeric = as.numeric(str_remove(national_performance, "%")),
      # Extract interval bounds
      interval_lower = as.numeric(str_extract(rsp_interval, "^\\d+\\.\\d+")),
      interval_upper = as.numeric(str_extract(rsp_interval, "\\d+\\.\\d+$"))
    )

  return(all_data)
}

#' Extract CFSR Profile PDF Data to Dataframe (Legacy - use extract_cfsr_profile_txt instead)
#'
#' Extracts Risk-Standardized Performance data from CFSR Data Profile PDFs
#' NOTE: PDF text extraction is unreliable. Prefer using extract_cfsr_profile_txt()
#' with Adobe-exported text files instead.
#'
#' @param pdf_path Path to CFSR PDF file
#' @param page Page number to extract (default: 2 for RSP table)
#' @return Dataframe with indicator data
#' @examples
#' data <- extract_cfsr_profile_pdf("path/to/pdf.pdf", page = 2)
extract_cfsr_profile_pdf <- function(pdf_path, page = 2) {
  
  library(pdftools)
  library(tidyverse)

  # Read PDF using pdf_data for better structure
  pdf_data_list <- pdf_data(pdf_path)
  page_data <- pdf_data_list[[page]]

  # Reconstruct text by sorting by y-position (top to bottom) then x-position (left to right)
  # Group words by y-position (with tolerance for same line)
  page_data <- page_data %>%
    mutate(line_group = cut(y, breaks = seq(0, max(y) + 10, by = 3), labels = FALSE)) %>%
    arrange(line_group, x)

  # Combine words into lines
  lines <- page_data %>%
    group_by(line_group) %>%
    summarize(text = paste(text, collapse = " "), .groups = "drop") %>%
    pull(text)

  # Combine all into single text
  text <- paste(lines, collapse = "\n")

  # Debug: show first few lines and search for indicators
  message("First 10 reconstructed lines of PDF page ", page, ":")
  message(paste(head(lines, 10), collapse = "\n"))
  message("\n--- Total lines: ", length(lines), " ---")
  message("\n--- Lines containing 'Permanency': ---")
  perm_lines <- grep("Permanency", lines, ignore.case = TRUE, value = TRUE)
  if (length(perm_lines) > 0) message(paste(head(perm_lines, 3), collapse = "\n"))
  message("\n--- Lines containing 'Maltreatment': ---")
  mal_lines <- grep("Maltreatment", lines, ignore.case = TRUE, value = TRUE)
  if (length(mal_lines) > 0) message(paste(head(mal_lines, 3), collapse = "\n"))
  
  # Define indicator patterns to find in PDF
  indicators <- tribble(
    ~indicator_name, ~pattern, ~direction,
        "Permanency in 12 months (entries)", "Permanency.*in.*12.*months.*.entries.", "up",
    "Permanency in 12 months (12-23 mos)", "Permanency.*in.*12.*months.*12-23.*mos.", "up",
    "Permanency in 12 months (24+ mos)", "Permanency.*in.*12.*months.*24.*mos.", "up",
    "Reentry to foster care", "Reentry.*to.*foster.*care", "down",
    "Placement stability", "Placement.*stability", "down",
    "Maltreatment in care", "Maltreatment.*in.*care", "down",
    "Recurrence of maltreatment", "Recurrence.*of.*maltreatment", "down"
  )
  
  # Extract data for each indicator
  all_data <- map_df(1:nrow(indicators), function(i) {
    
    ind_name <- indicators$indicator_name[i]
    ind_pattern <- indicators$pattern[i]
    ind_direction <- indicators$direction[i]
    
    message("Extracting: ", ind_name)
    
    # Find indicator header line
    ind_idx <- which(str_detect(lines, ind_pattern))[1]
    
    if (is.na(ind_idx)) {
      warning("Could not find indicator: ", ind_name)
      return(NULL)
    }
    
    # Get the block of lines for this indicator (usually 4-5 lines)
    block <- lines[ind_idx:min(ind_idx + 4, length(lines))]
    
    # Find RSP line (contains actual values)
    rsp_idx <- which(str_detect(block, "^\\s*RSP"))[1]
    
    if (is.na(rsp_idx)) {
      warning("Could not find RSP line for: ", ind_name)
      return(NULL)
    }
    
    rsp_line <- block[rsp_idx]
    interval_line <- block[rsp_idx + 1]  # RSP interval is next line
    data_used_line <- block[rsp_idx + 2] # Data used is line after that
    
    # Extract all values from RSP line
    # Look for percentages, decimals, or "DQ"
    values <- str_extract_all(rsp_line, "\\d+\\.\\d+%?|DQ\\*?")[[1]]
    
    # Extract intervals (ranges like "26.0%-31.2%")
    intervals <- str_extract_all(interval_line, "\\d+\\.\\d+%-\\d+\\.\\d+%")[[1]]
    
    # Extract data period labels (like "20A-22A", "FY20-21")
    data_periods <- str_extract_all(data_used_line, 
                                    "[0-9]{2}[AB]-[0-9]{2}[AB]|FY[0-9]{2}-[0-9]{2}")[[1]]
    
    # Also extract National Performance from first value
    np_match <- str_extract(block[1], "\\d+\\.\\d+%?")
    
    # Build dataframe
    # First value is often National Performance
    tibble(
      indicator = ind_name,
      direction = ind_direction,
      national_performance = np_match,
      period = if (length(data_periods) > 0) data_periods else NA_character_,
      rsp_value = if (length(values) > 1) values[-1] else values,  # Skip first if it's NP
      rsp_interval = if (length(intervals) > 0) intervals else NA_character_
    ) %>%
      # Make sure period and rsp_value are same length
      filter(!is.na(period))
    
  })

  # Check if we got any data
  if (nrow(all_data) == 0 || ncol(all_data) == 0) {
    warning("No data extracted from PDF. Check indicator patterns and PDF structure.")
    return(tibble(
      indicator = character(),
      direction = character(),
      national_performance = character(),
      period = character(),
      rsp_value = character(),
      rsp_interval = character(),
      rsp_numeric = numeric(),
      np_numeric = numeric(),
      data_quality_issue = logical(),
      interval_lower = numeric(),
      interval_upper = numeric()
    ))
  }

  # Clean up the data
  all_data <- all_data %>%
    mutate(
      # Remove % signs for numeric conversion
      rsp_numeric = as.numeric(str_remove(rsp_value, "%")),
      np_numeric = as.numeric(str_remove(national_performance, "%")),
      # Flag DQ issues
      data_quality_issue = str_detect(rsp_value, "DQ"),
      # Extract interval bounds
      interval_lower = as.numeric(str_extract(rsp_interval, "^\\d+\\.\\d+")),
      interval_upper = as.numeric(str_extract(rsp_interval, "\\d+\\.\\d+$"))
    )

  return(all_data)
}
