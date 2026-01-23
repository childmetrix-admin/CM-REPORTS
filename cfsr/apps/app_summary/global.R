# global.R - Data loading and transformation for CFSR Summary App
# Loads observed performance data and generates comprehensive summary table

library(shiny)
library(dplyr)
library(tidyr)
library(htmltools)

# Install reactable packages if needed
if (!require("reactable", quietly = TRUE)) {
  install.packages("reactable")
  library(reactable)
} else {
  library(reactable)
}

if (!require("reactablefmtr", quietly = TRUE)) {
  install.packages("reactablefmtr")
  library(reactablefmtr)
} else {
  library(reactablefmtr)
}

# Install sparkline package for inline sparklines
if (!require("sparkline", quietly = TRUE)) {
  install.packages("sparkline")
  library(sparkline)
} else {
  library(sparkline)
}

# Define %||% operator (null coalescing)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || x == "") y else x

#####################################
# CONFIGURATION ----
#####################################

# Data directory - dynamically detected from monorepo root
# Detect monorepo root by finding CLAUDE.md or .git
detect_monorepo_root <- function() {
  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "CLAUDE.md")) ||
        file.exists(file.path(current, ".git"))) {
      return(current)
    }
    current <- dirname(current)
  }
  # Fallback to environment variable
  root <- Sys.getenv("CM_REPORTS_ROOT", "d:/repo_childmetrix/cm-reports")
  return(root)
}
monorepo_root <- detect_monorepo_root()
data_dir <- file.path(monorepo_root, "cfsr/data/rds")

# State code mapping
state_codes <- c(
  "AL" = "Alabama", "AK" = "Alaska", "AZ" = "Arizona", "AR" = "Arkansas",
  "CA" = "California", "CO" = "Colorado", "CT" = "Connecticut", "DE" = "Delaware",
  "FL" = "Florida", "GA" = "Georgia", "HI" = "Hawaii", "ID" = "Idaho",
  "IL" = "Illinois", "IN" = "Indiana", "IA" = "Iowa", "KS" = "Kansas",
  "KY" = "Kentucky", "LA" = "Louisiana", "ME" = "Maine", "MD" = "Maryland",
  "MA" = "Massachusetts", "MI" = "Michigan", "MN" = "Minnesota", "MS" = "Mississippi",
  "MO" = "Missouri", "MT" = "Montana", "NE" = "Nebraska", "NV" = "Nevada",
  "NH" = "New Hampshire", "NJ" = "New Jersey", "NM" = "New Mexico", "NY" = "New York",
  "NC" = "North Carolina", "ND" = "North Dakota", "OH" = "Ohio", "OK" = "Oklahoma",
  "OR" = "Oregon", "PA" = "Pennsylvania", "RI" = "Rhode Island", "SC" = "South Carolina",
  "SD" = "South Dakota", "TN" = "Tennessee", "TX" = "Texas", "UT" = "Utah",
  "VT" = "Vermont", "VA" = "Virginia", "WA" = "Washington", "WV" = "West Virginia",
  "WI" = "Wisconsin", "WY" = "Wyoming", "DC" = "D.C.", "PR" = "Puerto Rico"
)

#####################################
# DATA LOADING FUNCTIONS ----
#####################################

#' Get available observed profiles for a state
#' @param state State code (e.g., "MD", "KY")
#' @return Character vector of available profile periods (e.g., c("2025_02", "2024_08"))
get_available_observed_profiles <- function(state) {
  state <- toupper(state)
  pattern <- paste0("^", state, "_cfsr_profile_observed_([0-9]{4}_[0-9]{2})\\.rds$")
  all_files <- list.files(data_dir, pattern = pattern)
  if (length(all_files) == 0) return(character(0))
  periods <- gsub(paste0(state, "_cfsr_profile_observed_(.*)\\.rds"), "\\1", all_files)
  sort(periods, decreasing = TRUE)
}

#' Load observed data for a state and profile period
#' @param state State code (e.g., "MD", "KY")
#' @param profile Profile period (e.g., "2025_02") or "latest" for most recent
#' @return Data frame with observed performance data including status column
load_observed_data <- function(state, profile = "latest") {
  state <- toupper(state)

  # If "latest" requested, find most recent profile
  if (profile == "latest") {
    available <- get_available_observed_profiles(state)
    if (length(available) == 0) {
      stop("No observed profiles available for ", state)
    }
    profile <- available[1]
  }

  filename <- paste0(state, "_cfsr_profile_observed_", profile, ".rds")
  file_path <- file.path(data_dir, filename)

  if (!file.exists(file_path)) {
    stop("Observed data file not found: ", file_path)
  }

  readRDS(file_path)
}

#####################################
# DATA TRANSFORMATION FUNCTIONS ----
#####################################

#' Generate comprehensive summary table from observed data
#' @param observed_data Data frame from load_observed_data()
#' @return Data frame with 10 columns ready for reactable display
generate_summary_table <- function(observed_data) {

  # Filter to 7 observed indicators (exclude Entry Rate, sort = 3)
  obs_filtered <- observed_data %>%
    filter(indicator_sort %in% c(1, 2, 4, 5, 6, 7, 8))

  # Check if data is empty
  if (nrow(obs_filtered) == 0) {
    return(NULL)
  }

  # Calculate period ranks for each indicator
  indicator_metrics <- obs_filtered %>%
    group_by(indicator) %>%
    arrange(desc(period)) %>%
    mutate(
      period_rank = row_number(),
      is_most_recent = period_rank == 1,
      is_second_recent = period_rank == 2,
      is_earliest = period_rank == max(period_rank)
    ) %>%
    ungroup()

  # Extract most recent period data
  summary_table <- indicator_metrics %>%
    filter(is_most_recent) %>%
    select(
      indicator,
      indicator_sort,
      indicator_very_short,
      observed_performance,
      national_standard,
      denominator,
      numerator,
      status,
      period_meaningful,
      format,
      scale,
      decimal_precision
    )

  # Join 2nd most recent performance for recent change calculation
  summary_table <- summary_table %>%
    left_join(
      indicator_metrics %>%
        filter(is_second_recent) %>%
        select(indicator, perf_2nd = observed_performance),
      by = "indicator"
    )

  # Join earliest performance for long-term change calculation
  summary_table <- summary_table %>%
    left_join(
      indicator_metrics %>%
        filter(is_earliest) %>%
        select(indicator, perf_earliest = observed_performance),
      by = "indicator"
    )

  # Calculate percent changes
  summary_table <- summary_table %>%
    mutate(
      # Recent change: most recent vs 2nd most recent
      recent_change = case_when(
        is.na(observed_performance) | is.na(perf_2nd) ~ NA_real_,
        perf_2nd == 0 ~ NA_real_,  # Avoid division by zero
        TRUE ~ ((observed_performance - perf_2nd) / perf_2nd) * 100
      ),

      # Long-term change: most recent vs earliest
      longterm_change = case_when(
        is.na(observed_performance) | is.na(perf_earliest) ~ NA_real_,
        perf_earliest == 0 ~ NA_real_,  # Avoid division by zero
        TRUE ~ ((observed_performance - perf_earliest) / perf_earliest) * 100
      )
    )

  # Format values for display
  summary_table <- summary_table %>%
    mutate(
      # Format observed performance
      # Percent indicators: multiply by 100 (stored as decimal: 0.35 = 35%)
      # Rate indicators: use raw value
      observed_performance_display = case_when(
        is.na(observed_performance) ~ "DQ",
        format == "percent" ~ paste0(round(observed_performance * 100, 1), "%"),
        TRUE ~ as.character(round(observed_performance, decimal_precision))
      ),

      # Format national standard
      # CRITICAL: Do NOT multiply - already in display format
      # Percent: 35.2 = 35.2%, Rate: 9.07 = 9.07
      national_standard_display = case_when(
        is.na(national_standard) | national_standard == "" ~ "—",
        format == "percent" ~ paste0(round(as.numeric(national_standard), 1), "%"),
        TRUE ~ as.character(round(as.numeric(national_standard), decimal_precision))
      ),

      # Format numerator and denominator
      denominator_display = ifelse(is.na(denominator), "DQ",
                                   format(denominator, big.mark = ",")),
      numerator_display = ifelse(is.na(numerator), "DQ",
                                 format(numerator, big.mark = ",")),

      # Format percent changes with +/- sign
      recent_change_display = ifelse(is.na(recent_change), "DQ",
                                     paste0(ifelse(recent_change > 0, "+", ""),
                                           round(recent_change, 1), "%")),
      longterm_change_display = ifelse(is.na(longterm_change), "DQ",
                                       paste0(ifelse(longterm_change > 0, "+", ""),
                                             round(longterm_change, 1), "%"))
    )

  # Generate sparkline data (all periods in chronological order)
  sparkline_data <- obs_filtered %>%
    group_by(indicator, indicator_sort) %>%
    arrange(period) %>%
    summarize(
      sparkline_values = list(observed_performance),
      .groups = "drop"
    )

  # Join sparkline data
  summary_table <- summary_table %>%
    left_join(sparkline_data, by = c("indicator", "indicator_sort"))

  # Sort by indicator_sort and select final display columns
  summary_table <- summary_table %>%
    arrange(indicator_sort) %>%
    select(
      indicator_very_short,
      observed_performance_display,
      national_standard_display,
      numerator_display,
      denominator_display,
      status,
      recent_change_display,
      longterm_change_display,
      sparkline_values,
      period_meaningful
    )

  return(summary_table)
}
