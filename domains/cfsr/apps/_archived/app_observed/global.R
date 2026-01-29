# global.R - Loads libraries, data, and helper functions for Observed Performance app
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

# Shared functions at cfsr/ level (relative to app directory)
source("../../functions/utils.R")
source("../../functions/data_prep.R")
source("../../functions/chart_builder.R")
source("../../functions/viz_container.R")

#####################################
# MODULES ----
#####################################

# Source indicator_detail module
source("../../modules/indicator_detail.R")

#####################################
# LOAD DATA ----
#####################################

# DYNAMIC PROFILE LOADING
# Note: getQueryString() doesn't work in global.R (runs before session starts)
# So we load the default (MD, latest) here, and app.R will handle dynamic
# reloading based on URL parameters

# Load default observed data (Maryland, latest)
# This is state-specific time series data with multiple periods
observed_data <- load_cfsr_data(state = "MD", profile = "latest", type = "observed")

# Load default national data (Maryland, latest)
# This is cross-sectional comparison of all 52 states for latest period
national_data <- load_cfsr_data(state = "MD", profile = "latest", type = "national")

#####################################
# GLOBAL VARIABLES ----
#####################################

# Indicator mapping: Full indicator name → indicator_sort (1-8)
# This maps between the two data sources
indicator_mapping <- c(
  "Maltreatment in care (victimizations / 100,000 days in care)" = 1,
  "Maltreatment recurrence within 12 months" = 2,
  "Foster care entry rate (entries / 1,000 children)" = 3,
  "Permanency in 12 months for children entering care" = 4,
  "Permanency in 12 months for children in care 12-23 months" = 5,
  "Permanency in 12 months for children in care 24 months or more" = 6,
  "Reentry to foster care within 12 months" = 7,
  "Placement stability (moves / 1,000 days in care)" = 8
)

# Reverse mapping: indicator_sort → Full indicator name
indicator_sort_to_name <- names(indicator_mapping)
names(indicator_sort_to_name) <- indicator_mapping

# Indicator sort values that have observed data (excludes Entry Rate = 3)
observed_indicator_sorts <- c(1, 2, 4, 5, 6, 7, 8)

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

# View ID to indicator name mapping (for URL routing)
# Used to map view parameter (e.g., "maltreatment") to full indicator name
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

#####################################
# FEATURE FLAGS ----
#####################################

# Feature flag: Self-contained visualization containers
# Set to TRUE to use new self-contained viz containers with download buttons
# Set to FALSE to revert to original layout (page-level metadata only)
USE_VIZ_CONTAINERS <- TRUE
