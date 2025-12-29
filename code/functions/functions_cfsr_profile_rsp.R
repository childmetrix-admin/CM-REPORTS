
# ============================================================================
# CFSR RSP-SPECIFIC FUNCTIONS
# ============================================================================
#
# RSP-specific utility functions for Risk-Standardized Performance extraction.
# Shared functions have been moved to functions_cfsr_profile_shared.R
#
# NOTE: This file now sources shared CFSR functions from functions_cfsr_profile_shared.R
# Shared functions include: setup_cfsr_folders, find_cfsr_file, load_indicator_dictionary,
# get_indicator_name, cfsr_profile_version, cfsr_profile_extract_asof_date,
# extract_pdf_metadata, rank_states_by_performance

# Convert RSP period strings to meaningful labels
# -------------------------------
# RSP data uses different period formats than the National data:
# - Top table: 19B20A, 20A20B, 20B21A (standard AB periods)
# - Bottom table: 19AB_FY19, 20AB_FY20 (AFCARS AB + NCANDS FY combined)
# - Bottom table: FY19-20, FY20-21 (fiscal year spans for recurrence)

make_period_meaningful_rsp <- function(period) {
  if (is.na(period) || period == "" || period == "NA") {
    return(NA_character_)
  }

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
  # RSP bottom table uses underscore separator (different from national which uses comma)
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

  # Case 4: Format "FYYY-YY" (e.g., "FY20-21") => FY20-21 (keep as-is)
  if (grepl("^FY[0-9]{2}-[0-9]{2}$", period)) {
    return(period)
  }

  # Case 5: Format with hyphen ranges like "19B-21B" or "20A-22A" (cohort periods)
  # These appear in the "Data used" row and represent multi-year cohorts
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

  # Fallback: return as-is if no pattern matches
  return(NA_character_)
}

# Vectorize the function
make_period_meaningful_rsp <- Vectorize(make_period_meaningful_rsp)
