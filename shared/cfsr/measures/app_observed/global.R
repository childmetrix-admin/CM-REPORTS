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

# Shared functions at cfsr/ level (use absolute paths for reliability)
source("D:/repo_childmetrix/cm-reports/shared/cfsr/functions/utils.R")
source("D:/repo_childmetrix/cm-reports/shared/cfsr/functions/data_prep.R")
source("D:/repo_childmetrix/cm-reports/shared/cfsr/functions/chart_builder.R")

#####################################
# MODULES ----
#####################################

# Shared modules at cfsr/ level (use absolute paths for reliability)
source("D:/repo_childmetrix/cm-reports/shared/cfsr/modules/indicator_page.R")

#####################################
# LOAD DATA ----
#####################################

# DYNAMIC PROFILE LOADING
# Note: getQueryString() doesn't work in global.R (runs before session starts)
# So we load default data here, and app.R will handle dynamic reloading
# based on URL parameters

# TODO: Load observed performance data once available
# For now, we'll use placeholder data or load what exists
# Planned data files:
#   - Observed performance trends (from PDF page 4)
#   - State-by-state data (from National Excel)
#   - County-level data (from State Excel)
#   - Demographic breakdowns (if available)

# Default data will be loaded as:
# app_data <- load_observed_data(state = "MD", profile = "latest")

#####################################
# GLOBAL VARIABLES ----
#####################################

# Indicator definitions (matching RSP indicators)
indicators <- data.frame(
  indicator_num = 1:8,
  indicator_name = c(
    "Entry Rate",
    "Maltreatment in Care",
    "Recurrence of Maltreatment",
    "Permanency in 12mo - Entries",
    "Permanency in 12mo - 12-23mo",
    "Permanency in 12mo - 24+mo",
    "Reentry to Foster Care",
    "Placement Stability"
  ),
  indicator_short = c(
    "Entry Rate",
    "Maltreatment",
    "Recurrence",
    "Perm 12mo - Entries",
    "Perm 12mo - 12-23mo",
    "Perm 12mo - 24+mo",
    "Reentry",
    "Placement"
  ),
  category = c(
    "Other",      # Entry Rate
    "Safety",     # Maltreatment in Care
    "Safety",     # Recurrence
    "Permanency", # Perm 12mo - Entries
    "Permanency", # Perm 12mo - 12-23mo
    "Permanency", # Perm 12mo - 24+mo
    "Permanency", # Reentry
    "Well-Being"  # Placement Stability
  ),
  stringsAsFactors = FALSE
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
