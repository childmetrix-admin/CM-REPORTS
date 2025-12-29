# app.R - Observed Performance Shiny Application
# CFSR Observed Performance Dashboard

library(shiny)
library(dplyr)
library(ggplot2)
library(scales)

# Define %||% operator (null coalescing) if not available
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || x == "") y else x

#####################################
# DATA LOADING FUNCTIONS ----
#####################################

# Data directory (shared with all CFSR apps)
data_dir <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data"

#' Get available observed profiles for a state
get_available_observed_profiles <- function(state) {
  state <- toupper(state)
  pattern <- paste0("^", state, "_cfsr_profile_observed_([0-9]{4}_[0-9]{2})\\.rds$")
  all_files <- list.files(data_dir, pattern = pattern)
  if (length(all_files) == 0) return(character(0))
  periods <- gsub(paste0(state, "_cfsr_profile_observed_(.*)\\.rds"), "\\1", all_files)
  sort(periods, decreasing = TRUE)
}

#' Load observed data for a state and profile period
#' Each RDS file contains all historical periods for that profile version
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

  data <- readRDS(file_path)

  # Leave period as-is (not converting to factor)
  # The RDS data is already in chronological order within each indicator
  # and the chart function preserves this order using unique()

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

# Observed indicator order (all 7 indicators with observed data, excludes Entry Rate)
# indicator_sort: 1=Maltreatment in care, 2=Recurrence, 4=Perm12 entries,
#                 5=Perm12 12-23mo, 6=Perm12 24+mo, 7=Reentry, 8=Placement stability
observed_indicator_order <- c(1, 2, 4, 5, 6, 7, 8)

#####################################
# HELPER FUNCTIONS ----
#####################################

# NOTE: Performance status (better/worse/nodiff/dq) is pre-calculated in the RDS file
# based on RSP confidence interval overlap logic. No longer calculated here.

#' Build observed performance trend chart (simple line chart, no confidence intervals)
build_observed_chart <- function(data, national_std, format_type, direction_rule) {
  if (nrow(data) == 0) return(NULL)

  # Prepare data - convert percentages for display
  is_pct <- (format_type == "percent")
  multiplier <- if (is_pct) 100 else 1

  # Preserve period order from the data as it comes in (already chronologically sorted)
  # Extract unique periods in the order they appear in the input data
  plot_data <- data %>%
    mutate(period_char = trimws(as.character(period)))

  # Get periods in the order they appear in the data (preserves chronological order from RDS)
  sorted_periods <- unique(plot_data$period_char)

  plot_data <- plot_data %>%
    mutate(
      period_label = factor(period_char, levels = sorted_periods),
      has_data = !is.na(observed_performance),
      observed_display = observed_performance * multiplier
    )

  national_display <- national_std  # Already in display format

  # Use pre-calculated RSP status for point colors
  # Status is based on RSP confidence interval overlap (statistically valid)
  plot_data <- plot_data %>%
    mutate(
      point_color = case_when(
        is.na(observed_performance) ~ "#f59e0b",  # Amber for DQ (missing observed data)
        is.na(status) ~ "#6b7280",                # Gray for missing RSP status
        status == "better" ~ "#10b981",           # Green for statistically better than national
        status == "worse" ~ "#ef4444",            # Red for statistically worse than national
        status == "nodiff" ~ "#6b7280",           # Gray for no statistical difference
        status == "dq" ~ "#f59e0b",               # Amber for RSP data quality issue
        TRUE ~ "#6b7280"                          # Gray fallback
      )
    )

  # Calculate y-axis range - always start at 0
  y_vals <- c(plot_data$observed_display, national_display)
  y_max <- max(y_vals, na.rm = TRUE) * 1.15
  y_min <- 0

  # Separate data with and without observed values
  plot_data_valid <- plot_data %>% filter(has_data)
  plot_data_dq <- plot_data %>% filter(!has_data)

  # Create plot
  p <- ggplot(plot_data, aes(x = period_label)) +
    # National standard reference line
    geom_hline(yintercept = national_display, color = "#3b82f6", linetype = "dashed", size = 0.6)

  # Add line and points for valid data
  if (nrow(plot_data_valid) > 0) {
    p <- p +
      # Observed performance line
      geom_line(data = plot_data_valid,
                aes(y = observed_display, group = 1),
                color = "#6b7280", size = 0.8) +

      # Observed performance points (colored by status)
      geom_point(data = plot_data_valid,
                 aes(y = observed_display, color = point_color),
                 size = 3) +

      # Manual color scale
      scale_color_identity()
  }

  # Add DQ labels for missing data (positioned below national line)
  if (nrow(plot_data_dq) > 0) {
    p <- p +
      geom_text(data = plot_data_dq,
                aes(y = national_display * 0.75, label = "DQ"),
                color = "#f59e0b", fontface = "bold", size = 3.5)
  }

  p <- p +
    # X-axis scale with explicit period order
    scale_x_discrete(limits = sorted_periods, drop = FALSE) +

    # Y-axis scale
    scale_y_continuous(
      limits = c(y_min, y_max),
      expand = expansion(mult = c(0, 0.05))
    ) +

    # Theme
    theme_minimal() +
    theme(
      axis.title = element_blank(),
      axis.text.x = element_text(size = 8, hjust = 0.5, color = "#374151"),
      axis.text.y = element_text(size = 8, color = "#6b7280"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "#f3f4f6", size = 0.3),
      plot.margin = margin(t = 5, r = 5, b = 5, l = 5),
      plot.background = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA)
    )

  p
}

#####################################
# UI ----
#####################################

ui <- fluidPage(
  # Custom CSS
  tags$head(
    tags$style(HTML("
      body {
        background-color: #f9fafb;
        font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif;
        margin: 0;
        padding: 0;
      }
      .container-fluid {
        padding: 24px;
        max-width: 1400px;
        margin-left: 0;
        margin-right: auto;
      }
      .header {
        margin-bottom: 24px;
      }
      .header h1 {
        font-size: 1.5rem;
        font-weight: 600;
        color: #111827;
        margin: 0 0 6px 0;
      }
      .header .subtitle {
        color: #6b7280;
        font-size: 0.9rem;
      }
      .kpi-grid-row {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 350px));
        gap: 16px;
        margin-bottom: 16px;
        justify-content: start;
        align-items: start;
      }
      @media (max-width: 768px) {
        .kpi-grid-row {
          grid-template-columns: 1fr;
          max-width: 500px;
          margin-left: auto;
          margin-right: auto;
        }
      }
      .kpi-box {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 10px;
        padding: 16px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        max-width: 100%;
      }
      .interpretation-kpi {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 10px;
        padding: 12px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      }
      .interpretation-kpi .kpi-title {
        background: #0f4c75;
        color: white;
        margin: -12px -12px 10px -12px;
        padding: 10px 12px;
        border-radius: 10px 10px 0 0;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .info-icon {
        font-size: 1.5rem;
        cursor: pointer;
        opacity: 0.8;
        transition: opacity 0.2s;
        position: relative;
        display: inline-block;
      }
      .info-icon:hover {
        opacity: 1;
      }
      .info-popup {
        display: none;
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        z-index: 10000;
        background: white;
        padding: 0;
        border-radius: 12px;
        box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        max-width: 90vw;
        max-height: 90vh;
        overflow: hidden;
      }
      .info-popup img {
        display: block;
        background: white;
        border-radius: 12px;
      }
      .info-icon:hover .info-popup {
        display: block;
      }
      .info-popup::before {
        content: '';
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        background: rgba(0,0,0,0.5);
        z-index: -1;
      }
      .kpi-title {
        font-size: 1.40rem;
        font-weight: 600;
        color: #111827;
        margin-bottom: 4px;
        line-height: 1.3;
      }
      .kpi-subtitle {
        font-size: 0.8rem;
        color: #6b7280;
        margin-bottom: 10px;
        line-height: 1.4;
      }
      .kpi-metrics {
        display: flex;
        align-items: baseline;
        gap: 6px;
        margin-bottom: 6px;
      }
      .kpi-value {
        font-size: 1.6rem;
        font-weight: 700;
        color: #111827;
      }
      .kpi-unit {
        font-size: 0.85rem;
        color: #6b7280;
      }
      .kpi-separator {
        font-size: 1.2rem;
        color: #d1d5db;
        margin: 0 4px;
      }
      .kpi-national-label {
        color: #6b7280;
        font-size: 0.9rem;
      }
      .kpi-national-value {
        font-weight: 700;
        color: #3b82f6;
        margin-left: 4px;
      }
      .kpi-direction {
        font-size: 0.7rem;
        color: #6b7280;
        margin-bottom: 8px;
      }
      .kpi-chart-container {
        height: 110px;
        margin: 8px -8px 8px -8px;
      }

      /* Interpretation legend */
      .interpretation-legend {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr;
        gap: 8px;
        margin-bottom: 10px;
        padding-bottom: 10px;
        border-bottom: 1px solid #e5e7eb;
      }
      .interpretation-legend-item {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 0.9rem;
        color: #374151;
        font-weight: 500;
        white-space: nowrap;
      }
      .interpretation-point {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        flex-shrink: 0;
      }
      .interpretation-point.better { background: #10b981; }
      .interpretation-point.worse { background: #ef4444; }
      .interpretation-point.nodiff { background: #6b7280; }
      .interpretation-point.dq { background: #f59e0b; }
      .interpretation-line {
        width: 24px;
        height: 2px;
        background: #6b7280;
      }
      .interpretation-line.national {
        background: #3b82f6;
        border-top: 2px dashed #3b82f6;
        background: none;
      }
      .interpretation-notes {
        font-size: 0.95rem;
        color: #374151;
        line-height: 1.6;
      }
      .interpretation-notes p {
        margin: 0 0 6px 0;
      }

      /* Status colors */
      .status-better { color: #10b981; }
      .status-worse { color: #ef4444; }
      .status-dq { color: #f59e0b; }
    "))
  ),

  # Header
  div(class = "header",
    h1(textOutput("header_title")),
    div(class = "subtitle", textOutput("header_subtitle"))
  ),

  # Row 1: Interpretation Guide + Safety (3 total)
  div(class = "kpi-grid-row",
    # Interpretation guide card
    div(class = "interpretation-kpi",
      div(class = "kpi-title",
        span("How to Interpret Observed Performance Charts"),
        span(class = "info-icon", "\u24D8",  # Info icon (ⓘ)
          div(class = "info-popup",
            tags$img(src = "kpi_observed_help.png", alt = "KPI Help Guide",
                     style = "width: 100%; max-width: 500px;")
          )
        )
      ),

      # Compact legend
      div(class = "interpretation-legend",
        # Row 1: Better, Worse, No difference
        div(class = "interpretation-legend-item",
          div(class = "interpretation-point better"),
          span("Better than national")
        ),
        div(class = "interpretation-legend-item",
          div(class = "interpretation-point worse"),
          span("Worse than national")
        ),
        div(class = "interpretation-legend-item",
          div(class = "interpretation-point nodiff"),
          span("No difference")
        ),
        # Row 2: Data quality, National performance
        div(class = "interpretation-legend-item",
          div(class = "interpretation-point dq"),
          span("Data quality issue")
        ),
        div(class = "interpretation-legend-item",
          div(class = "interpretation-line national"),
          span("National performance")
        )
      ),

      # Notes
      div(class = "interpretation-notes",
        p("Observed performance is the percent or rate of children experiencing the outcome, without risk-adjustment."),
        p("Whether performance is statistically better, worse, or no different than national performance is based on your state's ", tags$strong("risk-adjusted performance"), " (see the RSP page for details) and how it compares to national performance. Those results are shown here for convenience.")
      )
    ),

    # Safety KPIs
    uiOutput("kpi_1"),
    uiOutput("kpi_2")
  ),

  # Row 2: Permanency in 12 months (3 KPIs)
  div(class = "kpi-grid-row",
    uiOutput("kpi_3"),
    uiOutput("kpi_4"),
    uiOutput("kpi_5")
  ),

  # Row 3: Re-entry and Placement Stability (2 KPIs)
  div(class = "kpi-grid-row",
    uiOutput("kpi_6"),
    uiOutput("kpi_7")
  )
)

#####################################
# SERVER ----
#####################################

server <- function(input, output, session) {

  # Get state and profile from URL parameters
  state_code_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    toupper(query$state %||% "MD")
  })

  profile_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$profile %||% "latest"
  })

  state_name_rv <- reactive({
    state_codes[[state_code_rv()]]
  })

  # Load observed data
  observed_data <- reactive({
    load_observed_data(state_code_rv(), profile_rv())
  })

  # Get profile version
  profile_version <- reactive({
    data <- observed_data()
    if (is.null(data) || nrow(data) == 0) return("Unknown")
    unique(data$profile_version)[1]
  })

  # Header outputs
  output$header_title <- renderText({
    paste0(state_name_rv(), " - Observed Performance")
  })

  output$header_subtitle <- renderText({
    profile_ver <- profile_version()
    paste0("CFSR Round 4 Data Profile | ", profile_ver)
  })

  # Generate KPI box for each indicator
  build_kpi_output <- function(indicator_sort_val) {
    data <- observed_data()
    if (is.null(data) || nrow(data) == 0) {
      return(div(class = "kpi-box", p("No data available")))
    }

    ind_data <- data %>% filter(indicator_sort == indicator_sort_val)
    if (nrow(ind_data) == 0) {
      return(div(class = "kpi-box", p("No data for this indicator")))
    }

    # Get metadata
    ind_short <- ind_data$indicator_short[1]
    ind_desc <- ind_data$description[1]
    national_std <- ind_data$national_standard[1]
    direction_rule <- ind_data$direction_rule[1]
    direction_legend <- ind_data$direction_legend[1]
    format_type <- ind_data$format[1]
    decimal_prec <- ind_data$decimal_precision[1]
    scale_val <- ind_data$scale[1]

    # Get latest period data (most recent, including NA)
    latest <- ind_data %>% arrange(desc(period)) %>% slice(1)
    latest_val <- latest$observed_performance

    # Format display value
    if (format_type == "percent") {
      display_val <- if (!is.na(latest_val)) formatC(latest_val * 100, digits = decimal_prec, format = "f") else "DQ"
      unit_label <- "%"
      national_display <- formatC(national_std, digits = decimal_prec, format = "f")
      national_unit <- "%"
    } else {
      display_val <- if (!is.na(latest_val)) formatC(latest_val, digits = decimal_prec, format = "f") else "DQ"
      # Add unit labels for specific indicators
      unit_label <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
      national_display <- formatC(national_std, digits = decimal_prec, format = "f")
      national_unit <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
    }

    # Direction arrow (triangle, matching RSP)
    arrow <- if (direction_rule == "lt") "\u25BC" else "\u25B2"

    # Use pre-calculated status from RDS for value color
    status_val <- latest$status
    value_color <- switch(status_val,
      "better" = "#10b981",   # Green
      "worse" = "#ef4444",    # Red
      "nodiff" = "#6b7280",   # Gray for no statistical difference
      "dq" = "#f59e0b",       # Amber for data quality issue
      "#6b7280"               # Gray fallback (includes NA)
    )

    # Build KPI box
    div(class = "kpi-box",
      div(class = "kpi-title", ind_short),
      div(class = "kpi-subtitle", ind_desc),
      div(class = "kpi-metrics",
        span(class = "kpi-value", style = paste0("color: ", value_color), display_val),
        span(class = "kpi-unit", unit_label),
        span(class = "kpi-separator", "|"),
        span(class = "kpi-national-value", national_display),
        span(class = "kpi-unit", national_unit),
        span(class = "kpi-national-label", "(National Performance)")
      ),
      div(class = "kpi-direction", paste(arrow, direction_legend)),
      div(class = "kpi-chart-container",
        renderPlot({
          build_observed_chart(ind_data, national_std, format_type, direction_rule)
        }, height = 100, bg = "transparent")
      )
    )
  }

  # Render each KPI box
  output$kpi_1 <- renderUI({ build_kpi_output(observed_indicator_order[1]) })
  output$kpi_2 <- renderUI({ build_kpi_output(observed_indicator_order[2]) })
  output$kpi_3 <- renderUI({ build_kpi_output(observed_indicator_order[3]) })
  output$kpi_4 <- renderUI({ build_kpi_output(observed_indicator_order[4]) })
  output$kpi_5 <- renderUI({ build_kpi_output(observed_indicator_order[5]) })
  output$kpi_6 <- renderUI({ build_kpi_output(observed_indicator_order[6]) })
  output$kpi_7 <- renderUI({ build_kpi_output(observed_indicator_order[7]) })
}

shinyApp(ui, server)
