# global.R - Loads libraries, data, and helper functions
# Runs once when app starts

#####################################
# LIBRARIES ----
#####################################

library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(ggplot2)

#####################################
# HELPER FUNCTIONS ----
#####################################

source("functions/utils.R")
source("functions/data_prep.R")
source("functions/chart_builder.R")

#####################################
# MODULES ----
#####################################

source("modules/indicator_page.R")

#####################################
# LOAD DATA ----
#####################################

# Check if pre-processed data exists
rds_path <- "D:/repo_childmetrix/r_cfsr_profile/shiny_app/data/cfsr_indicators_latest.rds"

if (file.exists(rds_path)) {
  app_data <- readRDS(rds_path)
  message("Loaded pre-processed data from: ", rds_path)
} else {
  # Fallback: load and process raw data
  message("Pre-processed data not found. Loading raw data...")

  # Find the most recent processed file
  data_dir <- "D:/repo_childmetrix/r_cfsr_profile/data"
  processed_dirs <- list.dirs(data_dir, recursive = FALSE)

  # Filter to YYYY_MM format only (exclude cumulative, CY, Q folders)
  period_dirs <- processed_dirs[grepl("^\\d{4}_\\d{2}$", basename(processed_dirs))]

  if (length(period_dirs) == 0) {
    stop("No data found. Please run r_cfsr_profile.R first, then prepare_app_data.R")
  }

  # Get most recent period (sorted alphabetically works for YYYY_MM format)
  latest_period <- sort(basename(period_dirs), decreasing = TRUE)[1]

  # Find CSV in processed folder
  processed_path <- file.path(data_dir, latest_period, "processed")
  run_dirs <- list.dirs(processed_path, recursive = FALSE)

  if (length(run_dirs) == 0) {
    stop("No processed data found in ", processed_path)
  }

  latest_run <- sort(basename(run_dirs), decreasing = TRUE)[1]
  csv_files <- list.files(file.path(processed_path, latest_run),
                          pattern = "\\.csv$", full.names = TRUE)

  if (length(csv_files) == 0) {
    stop("No CSV files found in ", file.path(processed_path, latest_run))
  }

  # Load the data
  ind_data <- read.csv(csv_files[1], stringsAsFactors = FALSE)

  # Load dictionary
  dict_path <- "D:/repo_childmetrix/r_cfsr_profile/code/cfsr_round4_indicators_dictionary.csv"
  if (!file.exists(dict_path)) {
    stop("Dictionary not found at: ", dict_path)
  }
  dict <- read.csv(dict_path, stringsAsFactors = FALSE)

  # Prepare data for app
  app_data <- prepare_app_data(ind_data, dict)

  # Save for next time
  saveRDS(app_data, rds_path)
  message("Saved pre-processed data to: ", rds_path)
}

#####################################
# GLOBAL VARIABLES ----
#####################################

# Get unique indicators (ordered by category)
indicators_ordered <- app_data %>%
  distinct(indicator, indicator_short, category) %>%
  arrange(
    factor(category, levels = c("Safety", "Permanency", "Well-Being", "Other")),
    indicator_short
  )

# Category groupings for sidebar
category_indicators <- list(
  "Safety" = indicators_ordered %>%
    filter(category == "Safety") %>%
    select(indicator, indicator_short),
  "Permanency" = indicators_ordered %>%
    filter(category == "Permanency") %>%
    select(indicator, indicator_short),
  "Well-Being" = indicators_ordered %>%
    filter(category == "Well-Being" | category == "Other") %>%
    select(indicator, indicator_short)
)

# State code to full name mapping
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
