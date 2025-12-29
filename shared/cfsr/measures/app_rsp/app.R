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
# Data is at cfsr/data/ level (shared across all apps)
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

  data <- readRDS(file_path)

  # Ensure period is a factor with correct chronological ordering
  # If period is not already a factor, convert it with sorted levels
  if (!is.factor(data$period)) {
    # Get unique periods and sort them
    # This will sort chronologically for consistent period formats
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
      ),
      # Format label for display
      rsp_label = ifelse(!is.na(rsp_display),
                         formatC(rsp_display, digits = 1, format = "f"),
                         "")
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
                    width = 0.2, linewidth = 0.8) +
      # Line connecting RSP values
      geom_line(data = plot_data_valid,
                aes(y = rsp_display, group = 1),
                color = "#6b7280", linewidth = 0.5) +
      # RSP point values
      geom_point(data = plot_data_valid,
                 aes(y = rsp_display, color = bar_color, group = period_label),
                 size = 2) +
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
      plot.margin = margin(5, 10, 1, 5),
      plot.background = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA)
    )

  p
}

#####################################
# HIGHLIGHTS CARD FUNCTIONS ----
#####################################

#' Calculate current performance counts
calculate_current_performance <- function(latest_data) {
  perf_counts <- list(better = 0, nodiff = 0, worse = 0, dq = 0)

  for (i in seq_len(nrow(latest_data))) {
    row <- latest_data[i, ]

    # Call existing helper function
    status <- get_performance_status(
      rsp = row$rsp,
      rsp_lower = row$rsp_lower,
      rsp_upper = row$rsp_upper,
      national_std = row$national_standard,
      direction_rule = row$direction_rule,
      format_type = row$format
    )

    # Count by status including DQ
    if (status$status == "better") {
      perf_counts$better <- perf_counts$better + 1
    } else if (status$status == "nodiff") {
      perf_counts$nodiff <- perf_counts$nodiff + 1
    } else if (status$status == "worse") {
      perf_counts$worse <- perf_counts$worse + 1
    } else if (status$status == "dq") {
      perf_counts$dq <- perf_counts$dq + 1
    }
  }

  return(perf_counts)
}

#' Calculate consistency analysis across all periods
calculate_consistency_analysis <- function(data) {
  consistency_counts <- list(always_worse = 0, always_better = 0, other = 0)

  # For each indicator, check consistency across all periods
  for (ind_sort in rsp_indicator_order) {
    ind_data <- data %>% filter(indicator_sort == ind_sort)

    if (nrow(ind_data) == 0) next

    # Get metadata for this indicator
    direction_rule <- ind_data$direction_rule[1]
    format_type <- ind_data$format[1]
    national_std <- ind_data$national_standard[1]

    # Track status for each period
    statuses <- c()
    has_dq <- FALSE

    for (i in seq_len(nrow(ind_data))) {
      row <- ind_data[i, ]

      status <- get_performance_status(
        rsp = row$rsp,
        rsp_lower = row$rsp_lower,
        rsp_upper = row$rsp_upper,
        national_std = national_std,
        direction_rule = direction_rule,
        format_type = format_type
      )

      if (status$status == "dq") {
        has_dq <- TRUE
      } else {
        statuses <- c(statuses, status$status)
      }
    }

    # Classify consistency
    if (length(statuses) == 0) {
      # All DQ - skip
      next
    }

    unique_statuses <- unique(statuses)

    if (length(unique_statuses) == 1 && unique_statuses[1] == "worse") {
      consistency_counts$always_worse <- consistency_counts$always_worse + 1
    } else if (length(unique_statuses) == 1 && unique_statuses[1] == "better") {
      consistency_counts$always_better <- consistency_counts$always_better + 1
    } else {
      # Mixed or all nodiff or includes DQ
      consistency_counts$other <- consistency_counts$other + 1
    }
  }

  return(consistency_counts)
}

#' Build highlights KPI card - VERSION 1 (counts-based)
#' PRESERVED for potential reversion
build_highlights_kpi_v1 <- function(current_perf, consistency_counts) {
  div(class = "kpi-box highlights-kpi",
    div(class = "kpi-title", "Performance Summary"),
    div(class = "kpi-subtitle", "Overview of all 7 indicators"),

    # Current Performance Section
    div(style = "margin-bottom: 12px;",
      div(style = "font-size: 0.85rem; font-weight: 600; color: #6b7280; margin-bottom: 6px; text-transform: uppercase;",
        "Current Performance vs. National Performance"
      ),
      div(class = "summary-grid",
        div(class = "summary-item",
          div(class = "summary-count better", current_perf$better),
          div(class = "summary-label", "Better")
        ),
        div(class = "summary-item",
          div(class = "summary-count nodiff", current_perf$nodiff),
          div(class = "summary-label", "No Diff")
        ),
        div(class = "summary-item",
          div(class = "summary-count worse", current_perf$worse),
          div(class = "summary-label", "Worse")
        ),
        div(class = "summary-item",
          div(class = "summary-count dq", current_perf$dq),
          div(class = "summary-label", "DQ")
        )
      )
    ),

    # Consistency Section
    div(style = "border-top: 1px solid #e5e7eb; padding-top: 12px;",
      div(style = "font-size: 0.85rem; font-weight: 600; color: #6b7280; margin-bottom: 6px; text-transform: uppercase;",
        "Performance Consistency"
      ),
      div(class = "summary-grid",
        div(class = "summary-item",
          div(class = "summary-count worse", consistency_counts$always_worse),
          div(class = "summary-label", "Always Worse")
        ),
        div(class = "summary-item",
          div(class = "summary-count better", consistency_counts$always_better),
          div(class = "summary-label", "Always Better")
        ),
        div(class = "summary-item",
          div(class = "summary-count nodiff", consistency_counts$other),
          div(class = "summary-label", "Mixed")
        )
      )
    )
  )
}

#' Build highlights KPI card - VERSION 2 (list-based)
#' Shows all 7 indicators with their individual status
build_highlights_kpi_v2 <- function(latest_by_indicator) {
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
    status_label <- switch(status$status,
      "better" = "Better",
      "nodiff" = "No Diff",
      "worse" = "Worse",
      "dq" = "DQ",
      "Unknown"
    )

    div(class = "indicator-row",
      div(class = "indicator-name", row$indicator_very_short),
      div(class = paste("indicator-status", status_class), status_label)
    )
  })

  div(class = "kpi-box highlights-kpi",
    div(class = "kpi-title", "Performance Summary"),
    div(class = "kpi-subtitle", "Current vs. national performance"),

    div(class = "indicator-list",
      indicator_rows
    )
  )
}

#' Build complete highlights card
build_highlights_card <- function(data) {
  if (is.null(data) || nrow(data) == 0) {
    return(NULL)
  }

  # Get each indicator's most recent period (varies by indicator)
  # For each indicator, find the last period with valid data
  latest_by_indicator <- data %>%
    group_by(indicator_sort) %>%
    arrange(period) %>%
    slice_tail(n = 1) %>%
    ungroup()

  # VERSION 1: Counts-based (preserved)
  # current_perf <- calculate_current_performance(latest_by_indicator)
  # consistency_counts <- calculate_consistency_analysis(data)
  # build_highlights_kpi_v1(current_perf, consistency_counts)

  # VERSION 2: List-based (current)
  build_highlights_kpi_v2(latest_by_indicator)
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
      .highlights-kpi .kpi-title {
        background: #0f4c75;
        color: white;
        margin: -16px -16px 12px -16px;
        padding: 12px 16px;
        border-radius: 10px 10px 0 0;
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
        # margin-right: 4px;
      }
      .kpi-separator {
        font-size: 1.2rem;
        color: #d1d5db;
        margin: 0 4px;
      }
      .kpi-national {
        font-size: 0.9rem; #not in use
        color: #6b7280;
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

      /* Interpretation guide card styling */
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
        font-size: 1.40rem;
        font-weight: 600;
        line-height: 1.3;
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
      .interpretation-bar {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        flex-shrink: 0;
      }
      .interpretation-bar.better { background: #10b981; }
      .interpretation-bar.worse { background: #ef4444; }
      .interpretation-bar.nodiff { background: #6b7280; }
      .interpretation-bar.dq { background: #f59e0b; }
      .interpretation-bar.national {
        width: 20px;
        height: 0;
        background: none;
        border-bottom: 2px dashed #3b82f6;
        border-radius: 0;
      }
      .interpretation-guide {
        font-size: 0.95rem;
        color: #374151;
        line-height: 1.6;
      }
      .interpretation-guide p {
        margin: 0 0 6px 0;
      }
      .interpretation-guide p:last-child {
        margin-bottom: 0;
      }
      .interpretation-guide a {
        color: #1C7ED6;
        text-decoration: none;
        cursor: pointer;
      }
      .interpretation-guide a:hover {
        text-decoration: underline;
      }
      .notes-link {
        color: #1C7ED6;
        text-decoration: none;
        cursor: pointer;
      }
      .notes-link:hover {
        text-decoration: underline;
      }
      .dq-text {
        color: #f59e0b;
        font-weight: 700;
        font-size: 0.95rem;
      }

      /* Summary grid for highlights card V1 (counts-based) */
      .summary-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(60px, 1fr));
        gap: 8px;
      }
      .summary-item {
        text-align: center;
      }
      .summary-count {
        font-size: 2rem;
        font-weight: 700;
        margin-bottom: 4px;
        line-height: 1.2;
      }
      .summary-count.better {
        color: #10b981;
      }
      .summary-count.nodiff {
        color: #6b7280;
      }
      .summary-count.worse {
        color: #ef4444;
      }
      .summary-count.dq {
        color: #f59e0b;
      }
      .summary-label {
        font-size: 0.85rem;
        color: #6b7280;
        text-transform: uppercase;
        font-weight: 500;
      }

      /* Indicator list for highlights card V2 (list-based) */
      .indicator-list {
        display: flex;
        flex-direction: column;
        gap: 8px;
      }
      .indicator-row {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 8px 12px;
        background: #f9fafb;
        border-radius: 6px;
        border-left: 3px solid transparent;
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
        padding: 4px 10px;
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
    "))
  ),

  # Header
  div(class = "header",
    h1(textOutput("header_title")),
    div(class = "subtitle", textOutput("header_subtitle"))
  ),

  # Row 1: Interpretation Guide + Safety (3 KPIs total)
  div(class = "kpi-grid-row",
    # Interpretation guide card
    div(class = "interpretation-kpi",
      div(class = "kpi-title",
        span("How to Interpret RSP Charts"),
        span(class = "info-icon", "\u24D8",  # Info icon (ⓘ)
          div(class = "info-popup",
            tags$img(src = "kpi_help.png", alt = "KPI Help Guide",
                     style = "width: 100%; max-width: 500px;")
          )
        )
      ),

      # Compact legend
      div(class = "interpretation-legend",
        # Row 1: Better, Worse, No difference
        div(class = "interpretation-legend-item",
          div(class = "interpretation-bar better"),
          span("Better than national")
        ),
        div(class = "interpretation-legend-item",
          div(class = "interpretation-bar worse"),
          span("Worse than national")
        ),
        div(class = "interpretation-legend-item",
          div(class = "interpretation-bar nodiff"),
          span("No difference")
        ),
        # Row 2: Data quality, National performance
        div(class = "interpretation-legend-item",
          div(class = "interpretation-bar dq"),
          span("Data quality issue")
        ),
        div(class = "interpretation-legend-item",
          div(class = "interpretation-bar national"),
          span("National performance")
        )
      ),

      # Guidance text
      div(class = "interpretation-guide",
        p("Risk-Standardized Performance (RSP) is the percent or rate of children experiencing the outcome, with risk adjustment. The vertical bars in each graph represent the lower and upper 95% confidence intervals for the RSP."),
        p("To be statistically better or worse than national performance, the entire RSP interval needs to be above or below national performance (the dotted blue line).")
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

  # Note: Performance Highlights Card moved to separate Summary app (port 3840)

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
    ind_desc <- ind_data$description[1]
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
      display_val <- if (!is.na(latest_rsp)) formatC(latest_rsp * 100, digits = decimal_prec, format = "f") else "DQ"
      unit_label <- "%"
      national_display <- formatC(national_std, digits = decimal_prec, format = "f")
      national_unit <- "%"
    } else {
      display_val <- if (!is.na(latest_rsp)) formatC(latest_rsp, digits = decimal_prec, format = "f") else "DQ"
      # Add unit labels for specific indicators
      unit_label <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
      national_display <- formatC(national_std, digits = decimal_prec, format = "f")
      national_unit <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
    }

    # Direction arrow
    arrow <- if (direction_rule == "lt") "\u25BC" else "\u25B2"

    # Determine value color based on performance status
    value_color <- switch(perf$status,
      "better" = "#10b981",   # Green
      "worse" = "#ef4444",    # Red
      "nodiff" = "#6b7280",   # Gray
      "dq" = "#f59e0b",       # Orange
      "#111827"               # Default dark gray
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
          build_rsp_chart(ind_data, national_std, format_type, direction_rule)
        }, height = 100, bg = "transparent")
      )
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
