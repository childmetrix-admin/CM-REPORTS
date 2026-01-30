# global.R - Consolidated Measures App (RSP + Observed + National)
#
# This app consolidates 3 separate CFSR apps into one:
# - app_rsp (Risk-Standardized Performance KPI cards)
# - app_observed (Observed Performance KPI cards + indicator details)
# - app_national (National comparison with state-by-state charts)
#
# Navigation is built into the Shiny app sidebar, eliminating external HTML dependencies

# Load required packages
suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(dplyr)
  library(ggplot2)
  library(plotly)
  library(DT)
})

# Detect monorepo root
detect_monorepo_root <- function() {
  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "CLAUDE.md")) ||
        file.exists(file.path(current, ".git"))) {
      return(current)
    }
    current <- dirname(current)
  }
  root <- Sys.getenv("CM_REPORTS_ROOT", "d:/repo_childmetrix/cm-reports")
  return(root)
}

monorepo_root <- detect_monorepo_root()
message("Monorepo root detected: ", monorepo_root)

# Add resource path for shared CSS files
shared_path <- file.path(monorepo_root, "shared")
if (dir.exists(shared_path)) {
  addResourcePath("cm-shared", shared_path)
  message("Shared resources path added: ", shared_path)
} else {
  warning("Shared directory not found at: ", shared_path)
}

# Source helper functions
utils_path <- file.path(monorepo_root, "domains/cfsr/functions/utils.R")
data_prep_path <- file.path(monorepo_root, "domains/cfsr/functions/data_prep.R")
chart_builder_path <- file.path(monorepo_root, "domains/cfsr/functions/chart_builder.R")
viz_container_path <- file.path(monorepo_root, "domains/cfsr/functions/viz_container.R")

if (!file.exists(utils_path)) stop("utils.R not found at: ", utils_path)
if (!file.exists(data_prep_path)) stop("data_prep.R not found at: ", data_prep_path)
if (!file.exists(chart_builder_path)) stop("chart_builder.R not found at: ", chart_builder_path)
if (!file.exists(viz_container_path)) stop("viz_container.R not found at: ", viz_container_path)

source(utils_path)
source(data_prep_path)
source(chart_builder_path)
source(viz_container_path)

# Source modules
indicator_page_path <- file.path(monorepo_root, "domains/cfsr/modules/indicator_page.R")
indicator_detail_path <- file.path(monorepo_root, "domains/cfsr/modules/indicator_detail.R")

if (!file.exists(indicator_page_path)) stop("indicator_page.R not found at: ", indicator_page_path)
if (!file.exists(indicator_detail_path)) stop("indicator_detail.R not found at: ", indicator_detail_path)

source(indicator_page_path)
source(indicator_detail_path)

message("All modules loaded successfully")

#####################################
# FEATURE FLAGS ----
#####################################

# Enable new viz container layout for indicator detail pages
USE_VIZ_CONTAINERS <- TRUE

#####################################
# DATA DIRECTORY & RSP DATA LOADING ----
#####################################

# Data directory
data_dir <- file.path(monorepo_root, "domains/cfsr/data/rds")

# Get available RSP profiles for a state
get_available_rsp_profiles <- function(state) {
  state <- toupper(state)

  # New hierarchical structure: domains/cfsr/data/rds/{state}/{period}/
  state_dir <- file.path(data_dir, tolower(state))

  # Check if state directory exists
  if (!dir.exists(state_dir)) return(character(0))

  # Get all period subdirectories (e.g., "2025_02", "2024_08")
  period_dirs <- list.dirs(state_dir, full.names = FALSE, recursive = FALSE)
  period_dirs <- period_dirs[grepl("^[0-9]{4}_[0-9]{2}$", period_dirs)]

  if (length(period_dirs) == 0) return(character(0))

  # Filter to periods where the RSP file actually exists
  periods <- character(0)
  for (period in period_dirs) {
    expected_file <- file.path(state_dir, period,
                              paste0(state, "_cfsr_profile_rsp_", period, ".rds"))
    if (file.exists(expected_file)) {
      periods <- c(periods, period)
    }
  }

  if (length(periods) == 0) return(character(0))

  # Sort in descending order (most recent first)
  sort(periods, decreasing = TRUE)
}

# Load RSP data for a state and profile period
load_rsp_data <- function(state, profile = "latest") {
  state <- toupper(state)
  # If "latest" requested, find most recent profile
  if (profile == "latest") {
    available <- get_available_rsp_profiles(state)
    if (length(available) == 0) {
      stop("No RSP profiles available for ", state)
    }
    profile <- available[1]
  }

  # New hierarchical structure: domains/cfsr/data/rds/{state}/{period}/
  state_dir <- file.path(data_dir, tolower(state), profile)
  filename <- paste0(state, "_cfsr_profile_rsp_", profile, ".rds")
  file_path <- file.path(state_dir, filename)

  if (!file.exists(file_path)) {
    stop("RSP data file not found: ", file_path)
  }
  data <- readRDS(file_path)
  # Ensure period is a factor with correct chronological ordering
  if (!is.factor(data$period)) {
    unique_periods <- sort(unique(as.character(data$period)))
    data$period <- factor(data$period, levels = unique_periods)
  }
  data
}

#####################################
# GLOBAL VARIABLES ----
#####################################

# Global variables from original apps
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
  "WI" = "Wisconsin", "WY" = "Wyoming", "DC" = "District of Columbia",
  "PR" = "Puerto Rico"
)

# RSP indicator order (excludes Entry Rate which has no RSP)
# indicator_sort: 1=Maltreatment in care, 2=Recurrence, 4=Perm12 entries,
#                 5=Perm12 12-23mo, 6=Perm12 24+mo, 7=Reentry, 8=Placement stability
rsp_indicator_order <- c(1, 2, 4, 5, 6, 7, 8)

# Observed indicator sorts (same as RSP - excludes Entry Rate from KPI grid)
# Entry Rate has detail pages but no KPI card
observed_indicator_sorts <- c(1, 2, 4, 5, 6, 7, 8)

# View to indicator mapping (for observed detail pages)
view_to_indicator <- c(
  "entry_rate" = "Foster care entry rate (entries / 1,000 children)",
  "maltreatment" = "Maltreatment in care (victimizations / 100,000 days in care)",
  "recurrence" = "Maltreatment recurrence within 12 months",
  "perm12_entries" = "Permanency in 12 months for children entering care",
  "perm12_12_23" = "Permanency in 12 months for children in care 12-23 months",
  "perm12_24" = "Permanency in 12 months for children in care 24 months or more",
  "reentry" = "Reentry to foster care within 12 months",
  "placement" = "Placement stability (moves / 1,000 days in care)"
)
