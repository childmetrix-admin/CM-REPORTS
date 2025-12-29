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
