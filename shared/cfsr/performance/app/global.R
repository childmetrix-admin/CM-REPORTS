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

# DYNAMIC PROFILE LOADING
# Note: getQueryString() doesn't work in global.R (runs before session starts)
# So we load the default (MD, latest) here, and app.R will handle dynamic
# reloading based on URL parameters

# Load default data (Maryland, latest profile)
# Data files are in shared/cfsr/performance/app/data/
app_data <- load_cfsr_data(state = "MD", profile = "latest")

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
