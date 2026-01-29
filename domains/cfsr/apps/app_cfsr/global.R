# global.R - Consolidated CFSR App
# Loads libraries, data, and helper functions for all CFSR views
# Runs once when app starts

#####################################
# LIBRARIES ----
#####################################

# Core Shiny libraries
library(shiny)
library(shinydashboard)  # Used by national view
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(ggplot2)
library(htmltools)
library(scales)

# Summary view specific libraries
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

if (!require("sparkline", quietly = TRUE)) {
  install.packages("sparkline")
  library(sparkline)
} else {
  library(sparkline)
}

#####################################
# NULL COALESCING OPERATOR ----
#####################################

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || x == "") y else x

#####################################
# MONOREPO ROOT DETECTION ----
#####################################

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
data_dir <- file.path(monorepo_root, "domains/cfsr/data/rds")

#####################################
# HELPER FUNCTIONS ----
#####################################

# Shared functions at cfsr/functions/ level
source(file.path(monorepo_root, "domains/cfsr/functions/utils.R"))
source(file.path(monorepo_root, "domains/cfsr/functions/data_prep.R"))
source(file.path(monorepo_root, "domains/cfsr/functions/chart_builder.R"))
source(file.path(monorepo_root, "domains/cfsr/functions/viz_container.R"))

#####################################
# MODULES ----
#####################################

# Shared modules at cfsr/modules/ level
source(file.path(monorepo_root, "domains/cfsr/modules/indicator_page.R"))
source(file.path(monorepo_root, "domains/cfsr/modules/indicator_detail.R"))

#####################################
# GLOBAL VARIABLES ----
#####################################

# State code to full name mapping (used by all views)
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

# Indicator mapping: Full indicator name → indicator_sort (1-8)
# Used by observed view
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

# View ID to indicator name mapping (for observed view URL routing)
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

# Indicator sort values that have observed data (excludes Entry Rate = 3)
observed_indicator_sorts <- c(1, 2, 4, 5, 6, 7, 8)

# RSP indicator order (7 indicators, excludes Entry Rate)
rsp_indicator_order <- c(1, 2, 4, 5, 6, 7, 8)

#####################################
# FEATURE FLAGS ----
#####################################

# Feature flag: Self-contained visualization containers
# Set to TRUE to use new self-contained viz containers with download buttons
USE_VIZ_CONTAINERS <- TRUE

#####################################
# DATA LOADING FUNCTIONS ----
#####################################

# Note: Data loading is now handled in app.R based on view parameter
# Each view will lazy-load only the data it needs:
# - national view: cfsr_profile_national_{period}.rds
# - rsp view: {STATE}_cfsr_profile_rsp_{period}.rds
# - summary view: {STATE}_cfsr_profile_observed_{period}.rds
# - observed view: {STATE}_cfsr_profile_observed_{period}.rds + cfsr_profile_national_{period}.rds
