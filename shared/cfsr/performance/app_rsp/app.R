# app.R - RSP (Risk-Standardized Performance) Shiny Application
# CFSR Risk-Standardized Performance Dashboard

library(shiny)
library(dplyr)
library(ggplot2)
library(scales)

# Define %||% operator (null coalescing) if not available
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || x == "") y else x

#####################################
# DATA LOADING FUNCTIONS ----
#####################################

# Data directory (shared with national app)
# Data is at performance/data/ level (shared across all apps)
data_dir <- "D:/repo_childmetrix/cm-reports/shared/cfsr/performance/data"

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
#' Each RDS file already contains all historical periods for that profile version
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

  readRDS(file_path)
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

# RSP indicator order (Safety first, excludes Entry Rate which has no RSP)
# indicator_sort: 1=Maltreatment in care, 2=Recurrence, 4=Perm12 entries,
#                 5=Perm12 12-23mo, 6=Perm12 24+mo, 7=Reentry, 8=Placement stability
rsp_indicator_order <- c(1, 2, 4, 5, 6, 7, 8)

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
  if (is.na(rsp) || is.na(rsp_lower) || is.na(rsp_upper) || is.na(national_std)) {
    return(list(status = "dq", label = "Data quality issue", css_class = "status-dq"))
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

  # Check if interval overlaps national standard
  overlaps <- lower_display <= national_std && upper_display >= national_std

  if (overlaps) {
    return(list(status = "nodiff", label = "No statistical difference", css_class = "status-nodiff"))
  }

  # Determine better/worse based on direction
  if (direction_rule == "lt") {
    if (upper_display < national_std) {
      return(list(status = "better", label = "Statistically better", css_class = "status-better"))
    } else {
      return(list(status = "worse", label = "Statistically worse", css_class = "status-worse"))
    }
  } else {
    if (lower_display > national_std) {
      return(list(status = "better", label = "Statistically better", css_class = "status-better"))
    } else {
      return(list(status = "worse", label = "Statistically worse", css_class = "status-worse"))
    }
  }
}

#' Build RSP confidence interval chart
build_rsp_chart <- function(data, national_std, format_type, direction_rule) {
  if (nrow(data) == 0) return(NULL)

  # Prepare data - convert percentages for display
  # RSP for percent indicators is stored as decimal (0.26 = 26%)
  # National standard is stored as display value (35.2 = 35.2%)
  is_pct <- (format_type == "percent")
  multiplier <- if (is_pct) 100 else 1

  # Preserve period order from source data (already in chronological order)
  # If period is a factor, use its levels; otherwise sort alphabetically
  original_levels <- if (is.factor(data$period)) levels(data$period) else NULL

  plot_data <- data %>%
    mutate(period_char = trimws(as.character(period)))

  # Use original factor levels if available, otherwise sort alphabetically
  if (!is.null(original_levels)) {
    sorted_periods <- intersect(original_levels, unique(plot_data$period_char))
  } else {
    sorted_periods <- sort(unique(plot_data$period_char))
  }

  plot_data <- plot_data %>%
    mutate(
      period_label = factor(period_char, levels = sorted_periods),
      has_data = !is.na(rsp),
      rsp_display = rsp * multiplier,
      lower_display = rsp_lower * multiplier,
      upper_display = rsp_upper * multiplier
    )

  national_display <- national_std  # Already in display format

  # Determine bar colors based on performance vs national
  plot_data <- plot_data %>%
    mutate(
      overlaps_national = lower_display <= national_display & upper_display >= national_display,
      is_better = case_when(
        direction_rule == "lt" ~ upper_display < national_display,
        TRUE ~ lower_display > national_display
      ),
      bar_color = case_when(
        is.na(rsp) ~ "#f59e0b",        # Yellow for DQ
        overlaps_national ~ "#6b7280",  # Gray for no difference
        is_better ~ "#10b981",          # Green for better
        TRUE ~ "#ef4444"                # Red for worse
      )
    )

  # Calculate y-axis range - always start at 0
  y_vals <- c(plot_data$lower_display, plot_data$upper_display, national_display)
  y_vals <- y_vals[!is.na(y_vals)]
  if (length(y_vals) == 0) return(NULL)

  y_min <- 0
  y_max <- max(y_vals) * 1.1  # 10% padding above max

  # Separate data with and without RSP values
  plot_data_valid <- plot_data %>% filter(has_data)
  plot_data_dq <- plot_data %>% filter(!has_data)

  # Build ggplot using group aesthetic to prevent data collapse
  p <- ggplot(plot_data, aes(x = period_label)) +
    # National standard dashed line
    geom_hline(yintercept = national_display,
               linetype = "dashed", color = "#3b82f6", linewidth = 0.8)

  # Add error bars and points for valid data
  if (nrow(plot_data_valid) > 0) {
    p <- p +
      # Confidence interval bars with color in aes and scale_color_identity
      geom_errorbar(data = plot_data_valid,
                    aes(ymin = lower_display, ymax = upper_display,
                        color = bar_color, group = period_label),
                    width = 0.25, linewidth = 1.5) +
      # RSP point values
      geom_point(data = plot_data_valid,
                 aes(y = rsp_display, color = bar_color, group = period_label),
                 size = 3.5) +
      scale_color_identity()
  }

  # Add DQ labels for missing data
  if (nrow(plot_data_dq) > 0) {
    p <- p +
      geom_text(data = plot_data_dq,
                aes(y = national_display, label = "DQ"),
                color = "#f59e0b", fontface = "bold", size = 3.5)
  }

  p <- p +
    scale_x_discrete(limits = sorted_periods, drop = FALSE) +
    scale_y_continuous(limits = c(y_min, y_max)) +
    theme_minimal() +
    theme(
      axis.title = element_blank(),
      axis.text.x = element_text(size = 8, hjust = 0.5, color = "#374151"),
      axis.text.y = element_text(size = 8, color = "#6b7280"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "#e5e7eb", linewidth = 0.5),
      plot.margin = margin(5, 10, 5, 5),
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
      .kpi-grid-top {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 16px;
        margin-bottom: 16px;
      }
      .kpi-grid-bottom {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 16px;
        max-width: 75%;
      }
      @media (max-width: 1200px) {
        .kpi-grid-top { grid-template-columns: repeat(2, 1fr); }
        .kpi-grid-bottom { grid-template-columns: repeat(2, 1fr); max-width: 100%; }
      }
      @media (max-width: 768px) {
        .kpi-grid-top, .kpi-grid-bottom { grid-template-columns: 1fr; max-width: 100%; }
      }
      .kpi-box {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 10px;
        padding: 16px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      }
      .kpi-box.status-better { border-left: 4px solid #10b981; }
      .kpi-box.status-worse { border-left: 4px solid #ef4444; }
      .kpi-box.status-nodiff { border-left: 4px solid #6b7280; }
      .kpi-box.status-dq { border-left: 4px solid #f59e0b; }
      .kpi-title {
        font-size: 1.05rem;
        font-weight: 600;
        color: #111827;
        margin-bottom: 2px;
        line-height: 1.3;
      }
      .kpi-subtitle {
        font-size: 0.75rem;
        color: #9ca3af;
        margin-bottom: 10px;
      }
      .kpi-metrics {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        margin-bottom: 6px;
      }
      .kpi-value-section {
        display: flex;
        flex-direction: column;
      }
      .kpi-value-row {
        display: flex;
        align-items: baseline;
        gap: 2px;
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
      .kpi-national {
        text-align: right;
        font-size: 0.75rem;
        color: #6b7280;
      }
      .kpi-national .label { display: block; }
      .kpi-national .value { font-weight: 600; color: #374151; }
      .kpi-direction {
        font-size: 0.7rem;
        color: #6b7280;
        margin-bottom: 8px;
      }
      .kpi-chart-container {
        height: 110px;
        margin: 8px -8px 8px -8px;
      }
      .kpi-status {
        font-size: 0.7rem;
        padding: 4px 10px;
        border-radius: 4px;
        display: inline-block;
        font-weight: 500;
      }
      .kpi-status.better { background: #d1fae5; color: #065f46; }
      .kpi-status.worse { background: #fee2e2; color: #991b1b; }
      .kpi-status.nodiff { background: #f3f4f6; color: #374151; }
      .kpi-status.dq { background: #fef3c7; color: #92400e; }
      .legend-box {
        margin-top: 24px;
        padding: 16px 20px;
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 10px;
      }
      .legend-title {
        font-weight: 600;
        font-size: 0.85rem;
        color: #374151;
        margin-bottom: 12px;
      }
      .legend-items {
        display: flex;
        flex-wrap: wrap;
        gap: 20px;
        font-size: 0.8rem;
        color: #6b7280;
      }
      .legend-item {
        display: flex;
        align-items: center;
        gap: 8px;
      }
      .legend-bar {
        width: 20px;
        height: 4px;
        border-radius: 2px;
      }
      .legend-bar.better { background: #10b981; }
      .legend-bar.worse { background: #ef4444; }
      .legend-bar.nodiff { background: #6b7280; }
      .legend-bar.national {
        background: none;
        border-bottom: 2px dashed #3b82f6;
        height: 0;
      }
    "))
  ),

  # Header
  div(class = "header",
    h1(textOutput("header_title")),
    div(class = "subtitle", textOutput("header_subtitle"))
  ),

  # Top row: 4 KPI boxes
  div(class = "kpi-grid-top",
    uiOutput("kpi_1"),
    uiOutput("kpi_2"),
    uiOutput("kpi_3"),
    uiOutput("kpi_4")
  ),

  # Bottom row: 3 KPI boxes
  div(class = "kpi-grid-bottom",
    uiOutput("kpi_5"),
    uiOutput("kpi_6"),
    uiOutput("kpi_7")
  ),

  # Legend
  div(class = "legend-box",
    div(class = "legend-title", "How to interpret the charts"),
    div(class = "legend-items",
      div(class = "legend-item",
        div(class = "legend-bar better"), span("Statistically better than national")
      ),
      div(class = "legend-item",
        div(class = "legend-bar nodiff"), span("No statistical difference")
      ),
      div(class = "legend-item",
        div(class = "legend-bar worse"), span("Statistically worse than national")
      ),
      div(class = "legend-item",
        div(class = "legend-bar national"), span("National standard")
      )
    )
  )
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

  # Header outputs
  output$header_title <- renderText({
    paste0(state_name_rv(), " - Risk-Standardized Performance")
  })

  output$header_subtitle <- renderText({
    data <- rsp_data()
    if (is.null(data) || nrow(data) == 0) {
      return("No RSP data available for this state/profile")
    }
    profile_ver <- unique(data$profile_version)[1]
    paste0("CFSR Round 4 Data Profile | ", profile_ver)
  })

  # Generate KPI box for each indicator
  build_kpi_output <- function(indicator_sort_val) {
    data <- rsp_data()
    if (is.null(data) || nrow(data) == 0) {
      return(div(class = "kpi-box", p("No data available")))
    }

    ind_data <- data %>% filter(indicator_sort == indicator_sort_val)
    if (nrow(ind_data) == 0) {
      return(div(class = "kpi-box", p("No data for this indicator")))
    }

    # Get metadata
    ind_short <- ind_data$indicator_short[1]
    format_type <- ind_data$format[1]
    decimal_prec <- ind_data$decimal_precision[1]
    scale_val <- ind_data$scale[1]
    direction_rule <- ind_data$direction_rule[1]
    direction_legend <- ind_data$direction_legend[1]
    national_std <- ind_data$national_standard[1]

    # Get latest period data
    latest <- ind_data %>% arrange(desc(period)) %>% slice(1)
    latest_rsp <- latest$rsp
    latest_lower <- latest$rsp_lower
    latest_upper <- latest$rsp_upper

    # Performance status
    perf <- get_performance_status(latest_rsp, latest_lower, latest_upper,
                                    national_std, direction_rule, format_type)

    # Format display values
    if (format_type == "percent") {
      display_val <- if (!is.na(latest_rsp)) formatC(latest_rsp * 100, digits = decimal_prec, format = "f") else "N/A"
      unit_label <- "%"
      subtitle_text <- "RSP (%)"
      national_display <- paste0(formatC(national_std, digits = decimal_prec, format = "f"), "%")
    } else {
      display_val <- if (!is.na(latest_rsp)) formatC(latest_rsp, digits = decimal_prec, format = "f") else "N/A"
      unit_label <- ""
      subtitle_text <- paste0("RSP (per ", format(scale_val, big.mark = ","), ")")
      national_display <- formatC(national_std, digits = decimal_prec, format = "f")
    }

    # Direction arrow
    arrow <- if (direction_rule == "lt") "\u25BC" else "\u25B2"

    # Build KPI box
    div(class = paste("kpi-box", perf$css_class),
      div(class = "kpi-title", ind_short),
      div(class = "kpi-subtitle", subtitle_text),
      div(class = "kpi-metrics",
        div(class = "kpi-value-section",
          div(class = "kpi-value-row",
            span(class = "kpi-value", display_val),
            span(class = "kpi-unit", unit_label)
          )
        ),
        div(class = "kpi-national",
          span(class = "label", "National:"),
          span(class = "value", national_display)
        )
      ),
      div(class = "kpi-direction", paste(arrow, direction_legend)),
      div(class = "kpi-chart-container",
        renderPlot({
          build_rsp_chart(ind_data, national_std, format_type, direction_rule)
        }, height = 100, bg = "transparent")
      ),
      div(class = paste("kpi-status", perf$status), perf$label)
    )
  }

  # Render each KPI box
  output$kpi_1 <- renderUI({ build_kpi_output(rsp_indicator_order[1]) })
  output$kpi_2 <- renderUI({ build_kpi_output(rsp_indicator_order[2]) })
  output$kpi_3 <- renderUI({ build_kpi_output(rsp_indicator_order[3]) })
  output$kpi_4 <- renderUI({ build_kpi_output(rsp_indicator_order[4]) })
  output$kpi_5 <- renderUI({ build_kpi_output(rsp_indicator_order[5]) })
  output$kpi_6 <- renderUI({ build_kpi_output(rsp_indicator_order[6]) })
  output$kpi_7 <- renderUI({ build_kpi_output(rsp_indicator_order[7]) })
}

shinyApp(ui, server)
