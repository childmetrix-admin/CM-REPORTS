# app.R - Observed Performance Shiny Application (Integrated with National Comparison)
# CFSR Observed Performance Dashboard - Single Page with View Parameter Routing
#
# NOTE: Data loading, libraries, and shared functions are in global.R
# This file contains:
# - build_observed_chart() function for KPI trend charts
# - Single-page UI that switches content based on ?view= parameter
# - Server logic for Overview page (7 KPI cards) and indicator detail pages (national bar charts)
#
# ARCHITECTURE: This app is embedded in Maryland hub HTML via iframe. The outer page
# handles sidebar navigation by changing the iframe URL with ?view= parameter.
# Valid views: overview (default), entry_rate, maltreatment, recurrence,
#              perm12_entries, perm12_12_23, perm12_24, reentry, placement

# Load libraries
library(shiny)
library(plotly)
library(dplyr)
library(ggplot2)

# Source global.R first (loads data, helper functions, and global variables)
# NOTE: Shiny should auto-load global.R, but we source it explicitly to ensure it runs
source("global.R", local = FALSE)

# Source shared modules and functions (relative to app directory)
source("../../modules/indicator_detail.R")
source("../../functions/chart_builder.R")

# Define %||% operator (null coalescing)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || x == "") y else x

#####################################
# HELPER FUNCTIONS ----
#####################################

# NOTE: Performance status (better/worse/nodiff/dq) is pre-calculated in the RDS file
# based on RSP confidence interval overlap logic. No longer calculated here.

#' Build observed performance trend chart (simple line chart, no confidence intervals)
build_observed_chart <- function(data, national_std, format_type, direction_rule) {
  if (nrow(data) == 0) return(NULL)

  # Prepare data - convert percentages for display
  # NOTE: performance is stored as proportion (0.125)
  #       national_std is stored as percentage (12.5)
  is_pct <- (format_type == "percent")
  multiplier <- if (is_pct) 100 else 1

  # Preserve period order from the data as it comes in (already chronologically sorted)
  period_order <- unique(data$period)

  plot_data <- data %>%
    mutate(
      observed_display = performance * multiplier,
      period = factor(period, levels = period_order)
    )

  # Get value range for y-axis
  # NOTE: Don't multiply national_std - it's already a percentage
  y_vals <- c(plot_data$observed_display, national_std)
  y_vals <- y_vals[!is.na(y_vals)]

  if (length(y_vals) == 0) {
    y_max <- if (is_pct) 100 else 10
  } else {
    y_max <- max(y_vals, na.rm = TRUE) * 1.25  # Increased from 1.15 to prevent label cutoff
  }

  # Create base plot
  p <- ggplot(plot_data, aes(x = period, y = observed_display, group = 1))

  # Add national standard dashed line
  # NOTE: Don't multiply national_std - it's already a percentage
  p <- p + geom_hline(yintercept = national_std,
                     linetype = "dashed", color = "#10b981", linewidth = 0.8)

  # Add line connecting points
  p <- p + geom_line(color = "#6b7280", linewidth = 0.5)

  # Add colored data points based on status
  plot_data_valid <- plot_data %>% filter(!is.na(observed_display))
  plot_data_dq <- plot_data %>% filter(is.na(observed_display))

  if (nrow(plot_data_valid) > 0) {
    p <- p + geom_point(data = plot_data_valid,
                       aes(color = status), size = 2)
  }

  # Add data labels on first and last non-NA periods
  if (nrow(plot_data_valid) > 0) {
    # Get first and last rows with non-NA observed performance
    first_row <- plot_data_valid[1, ]
    last_row <- plot_data_valid[nrow(plot_data_valid), ]

    # Combine into data frame for labeling
    label_data <- bind_rows(first_row, last_row) %>%
      distinct()  # In case there's only 1 non-NA period (first = last)

    # Format labels based on format_type
    label_data <- label_data %>%
      mutate(
        label_text = if (is_pct) {
          paste0(round(observed_display, 1), "%")
        } else {
          as.character(round(observed_display, 2))  # 2 decimals for count indicators
        }
      )

    p <- p +
      geom_text(data = label_data,
                aes(y = observed_display, label = label_text),
                color = "#6b7280", fontface = "bold", size = 3.5, vjust = -1.1)
  }

  # Add "DQ" labels for missing data periods
  if (nrow(plot_data_dq) > 0) {
    # Position DQ labels at bottom of chart
    dq_y <- y_max * 0.05
    p <- p + geom_text(data = plot_data_dq,
                      aes(x = period, y = dq_y),
                      label = "DQ", color = "#f59e0b", fontface = "bold", size = 3)
  }

  # Color scale for status
  p <- p + scale_color_manual(
    values = c(
      "better" = "#4472C4",   # Blue
      "worse" = "#ef4444",    # Red
      "nodiff" = "#6b7280",   # Gray
      "dq" = "#f59e0b"        # Amber
    ),
    guide = "none"  # Hide legend
  )

  # Format and theme
  p <- p +
    scale_y_continuous(
      limits = c(0, y_max),
      labels = if (is_pct) {
        function(x) paste0(x, "%")
      } else {
        scales::comma_format()
      }
    ) +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_size = 10) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 0, hjust = 0.5, size = 9, color = "#374151"),
      axis.text.y = element_text(size = 9, color = "#374151"),
      plot.margin = margin(5, 10, 1, 5)
    )

  return(p)
}

#' Build observed performance trend chart using BAR CHART (test version)
build_observed_chart_bars <- function(data, national_std, format_type, direction_rule) {
  if (nrow(data) == 0) return(NULL)

  # Prepare data - convert percentages for display
  # NOTE: performance is stored as proportion (0.125)
  #       national_std is stored as percentage (12.5)
  is_pct <- (format_type == "percent")
  multiplier <- if (is_pct) 100 else 1

  # Preserve period order from the data as it comes in (already chronologically sorted)
  period_order <- unique(data$period)

  plot_data <- data %>%
    mutate(
      observed_display = performance * multiplier,
      period = factor(period, levels = period_order)
    )

  # Get value range for y-axis
  # NOTE: Don't multiply national_std - it's already a percentage
  y_vals <- c(plot_data$observed_display, national_std)
  y_vals <- y_vals[!is.na(y_vals)]

  if (length(y_vals) == 0) {
    y_max <- if (is_pct) 100 else 10
  } else {
    y_max <- max(y_vals, na.rm = TRUE) * 1.25  # Increased from 1.15 to prevent label cutoff
  }

  # Split data into valid and DQ
  plot_data_valid <- plot_data %>% filter(!is.na(observed_display))
  plot_data_dq <- plot_data %>% filter(is.na(observed_display))

  # Create base plot
  p <- ggplot()

  # Add bars for valid data (colored by status)
  if (nrow(plot_data_valid) > 0) {
    p <- p + geom_col(data = plot_data_valid,
                      aes(x = period, y = observed_display, fill = status),
                      width = 0.6, alpha = 0.85)
  }

  # Add national standard dashed line
  # NOTE: Don't multiply national_std - it's already a percentage
  p <- p + geom_hline(yintercept = national_std,
                     linetype = "dashed", color = "#10b981", linewidth = 0.8)

  # Add value labels on top of bars
  if (nrow(plot_data_valid) > 0) {
    label_data <- plot_data_valid %>%
      mutate(
        label_text = if (is_pct) {
          paste0(round(observed_display, 1), "%")
        } else {
          as.character(round(observed_display, 2))
        }
      )

    p <- p +
      geom_text(data = label_data,
                aes(x = period, y = observed_display, label = label_text),
                color = "#374151", fontface = "bold", size = 3, vjust = -0.5)
  }

  # Add "DQ" labels for missing data periods
  if (nrow(plot_data_dq) > 0) {
    # Position DQ labels at bottom of chart
    dq_y <- y_max * 0.05
    p <- p + geom_text(data = plot_data_dq,
                      aes(x = period, y = dq_y),
                      label = "DQ", color = "#f59e0b", fontface = "bold", size = 3)
  }

  # Color scale for status (fill instead of color)
  p <- p + scale_fill_manual(
    values = c(
      "better" = "#4472C4",   # Blue
      "worse" = "#ef4444",    # Red
      "nodiff" = "#6b7280",   # Gray
      "dq" = "#f59e0b"        # Amber
    ),
    guide = "none"  # Hide legend
  )

  # Format and theme
  p <- p +
    scale_y_continuous(
      limits = c(0, y_max),
      labels = if (is_pct) {
        function(x) paste0(x, "%")
      } else {
        scales::comma_format()
      }
    ) +
    labs(x = NULL, y = NULL) +
    theme_minimal(base_size = 10) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      axis.text.x = element_text(angle = 0, hjust = 0.5, size = 9, color = "#374151"),
      axis.text.y = element_text(size = 9, color = "#374151"),
      plot.margin = margin(5, 10, 1, 5)
    )

  return(p)
}

#####################################
# UI ----
#####################################

ui <- fluidPage(
  # Custom CSS
  tags$head(
    # html2canvas library for client-side screenshot/download
    tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"),

    # Download visualization function
    tags$script(HTML("
      function downloadViz(containerId, filename) {
        const element = document.getElementById(containerId);
        const button = element.querySelector('.viz-download-button .btn');

        if (!element) {
          console.error('Container not found:', containerId);
          return;
        }

        // Show clicked state
        if (button) {
          button.classList.add('btn-clicked');
          button.disabled = true;
        }

        // Hide button only during screenshot capture
        element.classList.add('exporting');

        html2canvas(element, {
          backgroundColor: '#ffffff',
          scale: 2,
          logging: false,
          useCORS: true
        }).then(canvas => {
          // Remove exporting class immediately
          element.classList.remove('exporting');

          // Trigger download
          const link = document.createElement('a');
          link.download = filename;
          link.href = canvas.toDataURL('image/png');
          link.click();

          // Reset button state
          if (button) {
            button.classList.remove('btn-clicked');
            button.disabled = false;
          }
        }).catch(error => {
          element.classList.remove('exporting');
          if (button) {
            button.classList.remove('btn-clicked');
            button.disabled = false;
          }
          console.error('Screenshot failed:', error);
          alert('Failed to generate screenshot. Please try again.');
        });
      }
    ")),

    tags$style(HTML("
      /* Page Layout */
      body {
        background: #f9fafb;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        margin: 0;
        padding: 0;
      }
      .container-fluid {
        padding: 24px;
        max-width: 1400px;
        margin-left: 0;
        margin-right: auto;
      }

      /* KPI Card Styles (from original app_observed) */
      .header {
        margin-bottom: 24px;
        padding-bottom: 0;
      }
      .header h1 {
        margin: 0 0 12px 0;
        font-size: 16px;
        font-weight: 700;
        color: #4472C4;
        letter-spacing: -0.5px;
      }
      .header .subtitle {
        margin: 0;
        font-size: 16px;
        color: #6b7280;
        line-height: 1.6;
        font-weight: 400;
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
        border-radius: 6px;
        padding: 12px;
        position: relative;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        transition: box-shadow 0.2s;
      }
      .kpi-box:hover {
        box-shadow: 0 4px 8px rgba(0,0,0,0.12);
      }
      .interpretation-kpi {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 10px;
        padding: 12px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      }
      .interpretation-kpi .kpi-title {
        background: #4472C4;
        color: white;
        margin: -12px -12px 10px -12px;
        padding: 10px 12px;
        border-radius: 10px 10px 0 0;
        font-size: 1.40rem;
        font-weight: 600;
        line-height: 1.3;
      }
      .kpi-title {
        font-size: 1.40rem;
        font-weight: 700;
        color: #1f2937;
        margin-bottom: 4px;
        position: relative;
        display: flex;
        align-items: center;
        justify-content: space-between;
      }
      .kpi-subtitle {
        font-size: 0.8rem;
        color: #6b7280;
        margin-bottom: 10px;
        line-height: 1.3;
        min-height: 32px;
      }
      .kpi-metrics {
        display: flex;
        align-items: baseline;
        gap: 6px;
        margin-bottom: 8px;
        flex-wrap: wrap;
      }
      .kpi-value {
        font-size: 1.7rem;
        font-weight: 700;
        line-height: 1;
      }
      .kpi-unit {
        font-size: 0.85rem;
        color: #6b7280;
        font-weight: 500;
      }
      .kpi-separator {
        color: #d1d5db;
        font-weight: 300;
        margin: 0 2px;
      }
      .kpi-national-label {
        color: #6b7280;
        font-size: 0.9rem;
      }
      .kpi-national-value {
        font-weight: 700;
        color: #10b981;
        margin-left: 4px;
      }
      .kpi-direction {
        font-size: 0.7rem;
        color: #6b7280;
        margin-bottom: 8px;
      }
      .kpi-chart-container {
        height: 110px;
        margin: 8px -8px 0px -8px;
      }
      .kpi-status-indicator {
        position: absolute;
        top: 12px;
        right: 12px;
        width: 12px;
        height: 12px;
        border-radius: 50%;
        flex-shrink: 0;
      }
      .kpi-status-indicator.better { background: #4472C4; }
      .kpi-status-indicator.worse { background: #ef4444; }
      .kpi-status-indicator.nodiff { background: #6b7280; }
      .kpi-status-indicator.dq { background: #f59e0b; }

      /* Info icon popup */
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
      .interpretation-point.better { background: #4472C4; }
      .interpretation-point.worse { background: #ef4444; }
      .interpretation-point.nodiff { background: #6b7280; }
      .interpretation-point.dq { background: #f59e0b; }
      .interpretation-line {
        width: 24px;
        height: 2px;
        background: #6b7280;
      }
      .interpretation-line.national {
        background: #10b981;
        border-top: 2px dashed #10b981;
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

      /* Chart styles for indicator detail pages */
      .indicator-detail-container {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 6px;
        padding: 20px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      }
      .chart-title {
        font-size: 1.4rem;
        font-weight: 700;
        color: #1f2937;
        margin-bottom: 8px;
      }
      .chart-period {
        font-size: 0.95rem;
        color: #6b7280;
        margin-bottom: 4px;
      }
      .chart-description {
        font-size: 0.9rem;
        color: #6b7280;
        margin-bottom: 8px;
      }
      .chart-target {
        font-size: 0.95rem;
        margin-bottom: 12px;
        font-weight: 500;
      }
      .chart-footnote {
        font-size: 0.85rem;
        color: #9ca3af;
        margin-top: 12px;
        font-style: italic;
      }

      /* Viz Container Styles (for self-contained visualizations with download) */
      .viz-export-container {
        position: relative;
        background: white;
        border-radius: 6px;
        padding: 8px 20px 20px 8px;
      }

      .viz-download-button {
        position: absolute;
        top: 16px;
        right: 16px;
        z-index: 100;
      }

      /* Clicked state - visual feedback */
      .viz-download-button .btn-clicked {
        background-color: #2c5aa0 !important;
        transform: scale(0.95);
      }

      /* Hide download button during screenshot export */
      .viz-export-container.exporting .viz-download-button {
        display: none !important;
      }

      .viz-context-header {
        border-bottom: 1px solid #e5e7eb;
        padding-bottom: 12px;
        margin-bottom: 16px;
      }

      .viz-title {
        font-size: 15px;
        font-weight: 600;
        color: #1f2937;
        margin-bottom: 4px;
      }

      .viz-description {
        font-size: 13px;
        font-weight: 400;
        color: #6b7280;
        line-height: 1.4;
        margin-bottom: 8px;
      }

      /* Pills row container */
      .viz-pills-row {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 12px;
        flex-wrap: wrap;
      }

      /* Period pill (highlighted timeframe) - Blue */
      .viz-period-pill {
        display: inline-block;
        background: #4472C4;
        color: white;
        font-size: 12px;
        font-weight: 600;
        padding: 4px 12px;
        border-radius: 12px;
      }

      /* State pill - Orange */
      .viz-state-pill {
        display: inline-block;
        background: #f59e0b;
        color: white;
        font-size: 12px;
        font-weight: 600;
        padding: 4px 12px;
        border-radius: 12px;
        margin-right: 16px;  /* Space after orange pill */
      }

      /* Legend (national performance) - Regular text */
      .viz-legend-pill {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        font-size: 12px;
        font-weight: 500;
        color: #374151;
      }

      .viz-legend-pill .legend-line {
        width: 20px;
        height: 0;
        border-top: 2px dashed #10b981;
        display: inline-block;
      }

      /* Source footnote */
      .viz-source {
        font-size: 11px;
        color: #6b7280;
        margin-top: 4px;
        padding-top: 4px;
        border-top: 1px solid #e5e7eb;
      }

      /* Notes (definitions, methodology) */
      .viz-notes {
        font-size: 11px;
        color: #6b7280;
        margin-top: 12px;
      }
    "))
  ),

  # Main content area - switches based on view parameter
  uiOutput("main_content")
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

  # Get view parameter (which page to show)
  view_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$view %||% "overview"
  })

  # Load observed data (uses function from utils.R via global.R)
  observed_data <- reactive({
    load_cfsr_data(state_code_rv(), profile_rv(), type = "observed")
  })

  # Load national data (uses function from utils.R via global.R)
  # Filter to most recent period per indicator for bar chart displays
  national_data <- reactive({
    data <- load_cfsr_data(state_code_rv(), profile_rv(), type = "national")
    data %>%
      group_by(indicator) %>%
      filter(period == max(period, na.rm = TRUE)) %>%
      ungroup()
  })

  # Get profile version
  profile_version <- reactive({
    data <- observed_data()
    if (is.null(data) || nrow(data) == 0) return("Unknown")
    unique(data$profile_version)[1]
  })

  # Header outputs
  output$header_title <- renderText({
    paste("Observed Performance —", state_name_rv())
  })

  output$header_subtitle <- renderText({
    paste0("CFSR Round 4 Data Profile | ", profile_version())
  })

  #####################################
  # MAIN CONTENT ROUTER ----
  #####################################

  # Render different content based on view parameter
  output$main_content <- renderUI({
    view <- view_rv()

    # Route to appropriate page based on view parameter
    if (view == "overview") {
      # ===== OVERVIEW PAGE (7 KPI CARDS) =====
      tagList(
        # Header
        div(class = "header",
          h1(textOutput("header_title")),
          p(class = "subtitle", textOutput("header_subtitle"))
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
                span("No statistical difference")
              ),
              # Row 2: DQ and national standard
              div(class = "interpretation-legend-item",
                div(class = "interpretation-point dq"),
                span("Data quality issue")
              ),
              div(class = "interpretation-legend-item",
                div(class = "interpretation-line national"),
                span("National standard")
              ),
              div(class = "interpretation-legend-item")  # Empty cell for alignment
            ),

            # Interpretation notes
            div(class = "interpretation-notes",
              tags$p("Observed performance is the percent or rate of children experiencing the outcome, without risk-adjustment."),
              tags$p("Whether performance is statistically better, worse, or no different from national performance is based on your state's risk-standardized performance (RSP). The results are shown here for convenience.")
            )
          ),

          # Maltreatment in Care KPI
          uiOutput("kpi_1"),

          # Recurrence KPI
          uiOutput("kpi_2")
        ),

        # Row 2: Permanency indicators (3 total)
        div(class = "kpi-grid-row",
          uiOutput("kpi_3"),  # Perm 12mo - Entries
          uiOutput("kpi_4"),  # Perm 12mo - 12-23mo
          uiOutput("kpi_5")   # Perm 12mo - 24+mo
        ),

        # Row 3: Reentry + Placement Stability (2 total)
        div(class = "kpi-grid-row",
          uiOutput("kpi_6"),  # Reentry
          uiOutput("kpi_7"),  # Placement Stability
          div()  # Empty cell for alignment
        )
      )
    } else if (view %in% names(view_to_indicator)) {
      # ===== INDICATOR DETAIL PAGE (NATIONAL BAR CHART) =====
      div(class = "indicator-detail-container",
        # Use the indicator_detail module UI
        indicator_detail_ui(view)
      )
    } else {
      # ===== INVALID VIEW =====
      div(
        div(class = "header",
          h1("Invalid View"),
          p(class = "subtitle", paste("Unknown view:", view))
        ),
        p("Defaulting to Overview page...")
      )
    }
  })

  #####################################
  # OVERVIEW PAGE (KPI CARDS) ----
  #####################################

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
    latest_val <- latest$performance

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
      "better" = "#4472C4",   # Blue
      "worse" = "#ef4444",    # Red
      "nodiff" = "#6b7280",   # Gray for no statistical difference
      "dq" = "#f59e0b",       # Amber for data quality issue
      "#6b7280"               # Gray fallback (includes NA)
    )

    # Build KPI box
    div(class = "kpi-box",
      div(class = paste("kpi-status-indicator", status_val)),
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
          # TEST: Using bar chart version - change back to build_observed_chart() for line charts
          # build_observed_chart_bars(ind_data, national_std, format_type, direction_rule)
          build_observed_chart(ind_data, national_std, format_type, direction_rule)
        }, height = 100, bg = "transparent")
      )
    )
  }

  # Render each KPI box (7 total, matching observed_indicator_order from global.R)
  output$kpi_1 <- renderUI({ build_kpi_output(observed_indicator_sorts[1]) })
  output$kpi_2 <- renderUI({ build_kpi_output(observed_indicator_sorts[2]) })
  output$kpi_3 <- renderUI({ build_kpi_output(observed_indicator_sorts[3]) })
  output$kpi_4 <- renderUI({ build_kpi_output(observed_indicator_sorts[4]) })
  output$kpi_5 <- renderUI({ build_kpi_output(observed_indicator_sorts[5]) })
  output$kpi_6 <- renderUI({ build_kpi_output(observed_indicator_sorts[6]) })
  output$kpi_7 <- renderUI({ build_kpi_output(observed_indicator_sorts[7]) })

  #####################################
  # INDICATOR DETAIL PAGES (NATIONAL BAR CHARTS) ----
  #####################################

  # Call indicator detail module server for each of the 8 indicators
  # These will be rendered when the corresponding view is active
  indicator_detail_server("entry_rate", view_to_indicator[["entry_rate"]], national_data, state_code_rv, profile_rv)
  indicator_detail_server("maltreatment", view_to_indicator[["maltreatment"]], national_data, state_code_rv, profile_rv)
  indicator_detail_server("recurrence", view_to_indicator[["recurrence"]], national_data, state_code_rv, profile_rv)
  indicator_detail_server("perm12_entries", view_to_indicator[["perm12_entries"]], national_data, state_code_rv, profile_rv)
  indicator_detail_server("perm12_12_23", view_to_indicator[["perm12_12_23"]], national_data, state_code_rv, profile_rv)
  indicator_detail_server("perm12_24", view_to_indicator[["perm12_24"]], national_data, state_code_rv, profile_rv)
  indicator_detail_server("reentry", view_to_indicator[["reentry"]], national_data, state_code_rv, profile_rv)
  indicator_detail_server("placement", view_to_indicator[["placement"]], national_data, state_code_rv, profile_rv)
}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
