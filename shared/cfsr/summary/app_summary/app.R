# app.R - CFSR Performance Summary Shiny Application
# Simple app showing performance summary for all 7 RSP indicators

library(shiny)
library(dplyr)

# Define %||% operator (null coalescing) if not available
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || x == "") y else x

#####################################
# DATA LOADING FUNCTIONS ----
#####################################

# Data directory (shared with other CFSR apps)
data_dir <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"

#' Get available RSP profiles for a state
get_available_rsp_profiles <- function(state) {
  state <- toupper(state)
  pattern <- paste0("^", state, "_cfsr_profile_rsp_([0-9]{4}_[0-9]{2})\\.rds$")
  all_files <- list.files(data_dir, pattern = pattern)
  if (length(all_files) == 0) return(character(0))
  periods <- gsub(paste0(state, "_cfsr_profile_rsp_(.*)\\.rds"), "\\1", all_files)
  sort(periods, decreasing = TRUE)
}

#' Load RSP data for a state and profile period
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

  filename <- paste0(state, "_cfsr_profile_rsp_", profile, ".rds")
  file_path <- file.path(data_dir, filename)

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
# DATA & CONFIGURATION ----
#####################################

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
# HELPER FUNCTIONS ----
#####################################

#' Get performance status based on RSP interval vs national standard
#' @param rsp RSP value (decimal for percent indicators, e.g., 0.26 = 26%)
#' @param rsp_lower Lower CI bound (same scale as rsp)
#' @param rsp_upper Upper CI bound (same scale as rsp)
#' @param national_std National standard (display value, e.g., 35.2 = 35.2%)
#' @param direction_rule "lt" (lower is better) or "gt" (higher is better)
#' @param format_type "percent" or "rate"
get_performance_status <- function(rsp, rsp_lower, rsp_upper, national_std, direction_rule, format_type) {
  # Handle missing/DQ data
  if (is.na(rsp) || is.na(rsp_lower) || is.na(rsp_upper)) {
    return(list(status = "dq", label = "DQ"))
  }

  if (is.na(national_std)) {
    return(list(status = "dq", label = "DQ"))
  }

  # Convert RSP values to display scale for comparison
  # RSP for percent indicators is stored as decimal (0.26 = 26%)
  # National standard is stored as display value (35.2 = 35.2%)
  if (format_type == "percent") {
    rsp_display <- rsp * 100
    lower_display <- rsp_lower * 100
    upper_display <- rsp_upper * 100
  } else {
    rsp_display <- rsp
    lower_display <- rsp_lower
    upper_display <- rsp_upper
  }

  # Check if CI includes national standard
  ci_includes_nat <- (lower_display <= national_std) && (national_std <= upper_display)

  if (ci_includes_nat) {
    return(list(status = "nodiff", label = "No Diff"))
  }

  # Determine better/worse based on direction
  if (direction_rule == "lt") {
    # Lower is better
    if (upper_display < national_std) {
      return(list(status = "better", label = "Better"))
    } else {
      return(list(status = "worse", label = "Worse"))
    }
  } else if (direction_rule == "gt") {
    # Higher is better
    if (lower_display > national_std) {
      return(list(status = "better", label = "Better"))
    } else {
      return(list(status = "worse", label = "Worse"))
    }
  }

  # Fallback
  return(list(status = "dq", label = "DQ"))
}

#' Build performance summary card
build_summary_card <- function(latest_by_indicator) {
  if (is.null(latest_by_indicator) || nrow(latest_by_indicator) == 0) {
    return(div(class = "kpi-box", p("No data available")))
  }

  # Build indicator rows
  indicator_rows <- lapply(1:nrow(latest_by_indicator), function(i) {
    row <- latest_by_indicator[i, ]

    status <- get_performance_status(
      rsp = row$rsp,
      rsp_lower = row$rsp_lower,
      rsp_upper = row$rsp_upper,
      national_std = row$national_standard,
      direction_rule = row$direction_rule,
      format_type = row$format
    )

    status_class <- status$status
    status_label <- status$label

    div(class = "indicator-row",
      div(class = "indicator-name", row$indicator_very_short),
      div(class = paste("indicator-status", status_class), status_label)
    )
  })

  div(class = "kpi-box summary-kpi",
    div(class = "kpi-title", "Performance Summary"),
    div(class = "kpi-subtitle", "Current vs. national performance"),

    div(class = "indicator-list",
      indicator_rows
    )
  )
}

#####################################
# UI ----
#####################################

ui <- fluidPage(
  # Custom CSS
  tags$head(
    tags$style(HTML("
      body {
        background-color: white;
        font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
        margin: 0;
        padding: 0;
      }
      .container-fluid {
        padding: 24px 32px;
        max-width: 600px;
        margin-left: 0;
        margin-right: auto;
      }

      /* KPI Box */
      .kpi-box {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
      }
      .kpi-title {
        background: #0f4c75;
        color: white;
        padding: 12px 16px;
        font-size: 1.125rem;
        font-weight: 600;
        margin: 0;
      }
      .kpi-subtitle {
        background: #0f4c75;
        color: rgba(255, 255, 255, 0.9);
        padding: 0 16px 12px 16px;
        font-size: 0.875rem;
      }

      /* Indicator list */
      .indicator-list {
        padding: 16px;
        display: flex;
        flex-direction: column;
        gap: 8px;
      }
      .indicator-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 12px;
        background: #f9fafb;
        border-radius: 6px;
      }
      .indicator-row:hover {
        background: #f3f4f6;
      }
      .indicator-name {
        font-size: 0.875rem;
        color: #374151;
        font-weight: 500;
        flex: 1;
      }
      .indicator-status {
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
        padding: 4px 12px;
        border-radius: 12px;
        min-width: 70px;
        text-align: center;
      }
      .indicator-status.better {
        background: #d1fae5;
        color: #065f46;
      }
      .indicator-status.nodiff {
        background: #e5e7eb;
        color: #374151;
      }
      .indicator-status.worse {
        background: #fee2e2;
        color: #991b1b;
      }
      .indicator-status.dq {
        background: #fef3c7;
        color: #92400e;
      }

      /* Footer note */
      .footer-note {
        margin-top: 16px;
        font-size: 0.75rem;
        color: #6b7280;
      }
    "))
  ),

  # Summary card
  uiOutput("summary_card"),

  # Footer
  div(class = "footer-note", textOutput("footer_text"))
)

#####################################
# SERVER ----
#####################################

server <- function(input, output, session) {

  # Get state and profile from URL parameters
  state_code_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    code <- toupper(query$state %||% "MD")
    if (!code %in% names(state_codes)) code <- "MD"
    code
  })

  profile_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$profile %||% "latest"
  })

  state_name_rv <- reactive({
    state_codes[[state_code_rv()]]
  })

  # Load RSP data
  rsp_data <- reactive({
    state <- state_code_rv()
    profile <- profile_rv()

    tryCatch({
      load_rsp_data(state, profile)
    }, error = function(e) {
      NULL
    })
  })

  # Summary card output
  output$summary_card <- renderUI({
    data <- rsp_data()
    if (is.null(data) || nrow(data) == 0) {
      return(div(class = "kpi-box",
        div(class = "kpi-title", "Performance Summary"),
        div(style = "padding: 16px;", p("No RSP data available for this state/profile"))
      ))
    }

    # Get each indicator's most recent period
    latest_by_indicator <- data %>%
      group_by(indicator_sort) %>%
      arrange(period) %>%
      slice_tail(n = 1) %>%
      ungroup()

    build_summary_card(latest_by_indicator)
  })

  # Footer text
  output$footer_text <- renderText({
    data <- rsp_data()
    if (is.null(data) || nrow(data) == 0) {
      return("")
    }
    profile_ver <- unique(data$profile_version)[1]
    paste0("Data from ", state_name_rv(), " CFSR Data Profile (", profile_ver, ")")
  })
}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
