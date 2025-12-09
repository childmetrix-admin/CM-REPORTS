# rsp_dashboard.R - RSP (Risk-Standardized Performance) Dashboard Module
# Displays 7 KPI boxes with confidence interval charts for each CFSR indicator

library(ggplot2)
library(dplyr)
library(scales)

#' RSP Dashboard UI
#'
#' @param id Module namespace ID
rsp_dashboard_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Custom CSS for KPI boxes
    tags$style(HTML("
      .rsp-container {
        padding: 20px;
        background-color: #f8f9fa;
        min-height: 100vh;
      }
      .rsp-header {
        margin-bottom: 24px;
      }
      .rsp-header h2 {
        font-size: 1.5rem;
        font-weight: 600;
        color: #1f2937;
        margin: 0 0 8px 0;
      }
      .rsp-header .subtitle {
        color: #6b7280;
        font-size: 0.9rem;
      }
      .kpi-grid {
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
        .kpi-grid {
          grid-template-columns: repeat(2, 1fr);
        }
        .kpi-grid-bottom {
          grid-template-columns: repeat(2, 1fr);
          max-width: 100%;
        }
      }
      @media (max-width: 768px) {
        .kpi-grid, .kpi-grid-bottom {
          grid-template-columns: 1fr;
          max-width: 100%;
        }
      }
      .kpi-box {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 8px;
        padding: 16px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      }
      .kpi-box.status-better {
        border-left: 4px solid #10b981;
      }
      .kpi-box.status-worse {
        border-left: 4px solid #ef4444;
      }
      .kpi-box.status-nodiff {
        border-left: 4px solid #6b7280;
      }
      .kpi-box.status-dq {
        border-left: 4px solid #f59e0b;
      }
      .kpi-title {
        font-size: 0.85rem;
        font-weight: 600;
        color: #374151;
        margin-bottom: 4px;
        line-height: 1.3;
      }
      .kpi-subtitle {
        font-size: 0.75rem;
        color: #9ca3af;
        margin-bottom: 12px;
      }
      .kpi-value-row {
        display: flex;
        align-items: baseline;
        gap: 8px;
        margin-bottom: 8px;
      }
      .kpi-value {
        font-size: 1.75rem;
        font-weight: 700;
        color: #111827;
      }
      .kpi-unit {
        font-size: 0.9rem;
        color: #6b7280;
      }
      .kpi-direction {
        font-size: 0.75rem;
        color: #6b7280;
        display: flex;
        align-items: center;
        gap: 4px;
        margin-bottom: 12px;
      }
      .kpi-direction .arrow-down {
        color: #10b981;
      }
      .kpi-direction .arrow-up {
        color: #10b981;
      }
      .kpi-chart {
        height: 120px;
        margin-top: 8px;
      }
      .kpi-status {
        font-size: 0.7rem;
        padding: 4px 8px;
        border-radius: 4px;
        display: inline-block;
        margin-top: 8px;
      }
      .kpi-status.better {
        background: #d1fae5;
        color: #065f46;
      }
      .kpi-status.worse {
        background: #fee2e2;
        color: #991b1b;
      }
      .kpi-status.nodiff {
        background: #f3f4f6;
        color: #374151;
      }
      .kpi-status.dq {
        background: #fef3c7;
        color: #92400e;
      }
      .legend-container {
        margin-top: 24px;
        padding: 16px;
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 8px;
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
        gap: 16px;
        font-size: 0.8rem;
        color: #6b7280;
      }
      .legend-item {
        display: flex;
        align-items: center;
        gap: 6px;
      }
      .legend-color {
        width: 16px;
        height: 4px;
        border-radius: 2px;
      }
      .legend-color.better { background: #10b981; }
      .legend-color.worse { background: #ef4444; }
      .legend-color.nodiff { background: #6b7280; }
      .legend-color.national {
        background: none;
        border-bottom: 2px dashed #3b82f6;
        height: 0;
        margin-top: 2px;
      }
    ")),

    div(class = "rsp-container",
      # Header
      div(class = "rsp-header",
        h2(textOutput(ns("header_title"))),
        div(class = "subtitle", textOutput(ns("header_subtitle")))
      ),

      # Top row: 4 KPI boxes (Safety indicators first)
      div(class = "kpi-grid",
        uiOutput(ns("kpi_box_1")),  # Maltreatment in care
        uiOutput(ns("kpi_box_2")),  # Maltreatment recurrence
        uiOutput(ns("kpi_box_3")),  # Perm 12 (entries)
        uiOutput(ns("kpi_box_4"))   # Perm 12 (12-23 mo)
      ),

      # Bottom row: 3 KPI boxes
      div(class = "kpi-grid-bottom",
        uiOutput(ns("kpi_box_5")),  # Perm 12 (24+ mo)
        uiOutput(ns("kpi_box_6")),  # Reentry
        uiOutput(ns("kpi_box_7"))   # Placement stability
      ),

      # Legend
      div(class = "legend-container",
        div(class = "legend-title", "How to read this dashboard"),
        div(class = "legend-items",
          div(class = "legend-item",
            div(class = "legend-color better"),
            span("Statistically better than national performance")
          ),
          div(class = "legend-item",
            div(class = "legend-color nodiff"),
            span("No statistical difference from national")
          ),
          div(class = "legend-item",
            div(class = "legend-color worse"),
            span("Statistically worse than national performance")
          ),
          div(class = "legend-item",
            div(class = "legend-color national"),
            span("National standard")
          )
        )
      )
    )
  )
}

#' RSP Dashboard Server
#'
#' @param id Module namespace ID
#' @param rsp_data Reactive containing RSP data frame
#' @param state_name Reactive containing full state name
#' @param state_code Reactive containing 2-letter state code
rsp_dashboard_server <- function(id, rsp_data, state_name, state_code) {
  moduleServer(id, function(input, output, session) {

    # RSP indicator order (Safety first, then others)
    # Excludes Entry Rate (indicator_sort = 3) which has no RSP
    rsp_indicator_order <- c(1, 2, 4, 5, 6, 7, 8)  # indicator_sort values

    # Header outputs
    output$header_title <- renderText({
      paste0(state_name(), " - Risk-Standardized Performance")
    })

    output$header_subtitle <- renderText({
      data <- rsp_data()
      if (is.null(data) || nrow(data) == 0) {
        return("No RSP data available")
      }
      profile_ver <- unique(data$profile_version)[1]
      paste0("CFSR Round 4 Data Profile | ", profile_ver)
    })

    # Helper function to determine performance status
    get_performance_status <- function(rsp, rsp_lower, rsp_upper, national_std, direction_rule) {
      # Handle NA/DQ cases
      if (is.na(rsp) || is.na(rsp_lower) || is.na(rsp_upper)) {
        return(list(status = "dq", label = "Data quality issue"))
      }

      # Determine if interval overlaps national standard
      overlaps_national <- rsp_lower <= national_std && rsp_upper >= national_std

      if (overlaps_national) {
        return(list(status = "nodiff", label = "No statistical difference"))
      }

      # Determine if better or worse based on direction
      if (direction_rule == "lt") {
        # Lower is better
        if (rsp_upper < national_std) {
          return(list(status = "better", label = "Statistically better"))
        } else {
          return(list(status = "worse", label = "Statistically worse"))
        }
      } else {
        # Higher is better (gt)
        if (rsp_lower > national_std) {
          return(list(status = "better", label = "Statistically better"))
        } else {
          return(list(status = "worse", label = "Statistically worse"))
        }
      }
    }

    # Helper function to format RSP value for display
    format_rsp_value <- function(value, format_type, decimal_precision, scale) {
      if (is.na(value)) return("N/A")

      if (format_type == "percent") {
        # RSP stored as decimal (0.26), display as percent (26.0%)
        pct_value <- value * 100
        formatted <- formatC(pct_value, digits = decimal_precision, format = "f")
        return(paste0(formatted, "%"))
      } else {
        # Rate - already in correct scale
        formatted <- formatC(value, digits = decimal_precision, format = "f")
        return(formatted)
      }
    }

    # Build KPI box UI
    build_kpi_box <- function(indicator_data) {
      if (is.null(indicator_data) || nrow(indicator_data) == 0) {
        return(div(class = "kpi-box", "No data available"))
      }

      # Get metadata from first row
      ind_short <- indicator_data$indicator_short[1]
      format_type <- indicator_data$format[1]
      decimal_prec <- indicator_data$decimal_precision[1]
      scale_val <- indicator_data$scale[1]
      direction_rule <- indicator_data$direction_rule[1]
      direction_legend <- indicator_data$direction_legend[1]
      national_std <- indicator_data$national_standard[1]

      # Get most recent period's data for the main value
      latest <- indicator_data %>%
        arrange(desc(period)) %>%
        slice(1)

      latest_rsp <- latest$rsp
      latest_lower <- latest$rsp_lower
      latest_upper <- latest$rsp_upper

      # Get performance status for latest period
      perf_status <- get_performance_status(
        latest_rsp, latest_lower, latest_upper,
        national_std, direction_rule
      )

      # Format the display value
      if (format_type == "percent") {
        display_value <- if (!is.na(latest_rsp)) {
          formatC(latest_rsp * 100, digits = decimal_prec, format = "f")
        } else "N/A"
        unit_label <- "%"
        subtitle <- "Risk-standardized percentage"
      } else {
        display_value <- if (!is.na(latest_rsp)) {
          formatC(latest_rsp, digits = decimal_prec, format = "f")
        } else "N/A"
        unit_label <- paste0(" per ", format(scale_val, big.mark = ","))
        subtitle <- "Risk-standardized rate"
      }

      # Direction indicator
      direction_arrow <- if (direction_rule == "lt") {
        span(class = "arrow-down", HTML("&#9660;"))  # Down arrow
      } else {
        span(class = "arrow-up", HTML("&#9650;"))  # Up arrow
      }

      # Build the chart
      chart <- build_rsp_chart(indicator_data, national_std, format_type, direction_rule)

      # Return the KPI box
      div(class = paste("kpi-box", paste0("status-", perf_status$status)),
        div(class = "kpi-title", ind_short),
        div(class = "kpi-subtitle", subtitle),
        div(class = "kpi-value-row",
          span(class = "kpi-value", display_value),
          span(class = "kpi-unit", unit_label)
        ),
        div(class = "kpi-direction",
          direction_arrow,
          span(direction_legend)
        ),
        div(class = "kpi-chart",
          chart
        ),
        div(class = paste("kpi-status", perf_status$status),
          perf_status$label
        )
      )
    }

    # Build RSP confidence interval chart
    build_rsp_chart <- function(data, national_std, format_type, direction_rule) {
      if (nrow(data) == 0) return(NULL)

      # Prepare data for plotting
      plot_data <- data %>%
        arrange(period) %>%
        mutate(
          period_label = period_meaningful,
          has_data = !is.na(rsp),
          # Convert to display scale for percentages
          rsp_display = if (format_type == "percent") rsp * 100 else rsp,
          lower_display = if (format_type == "percent") rsp_lower * 100 else rsp_lower,
          upper_display = if (format_type == "percent") rsp_upper * 100 else rsp_upper
        )

      # Adjust national standard for percentage display
      national_display <- if (format_type == "percent") national_std else national_std

      # Determine bar colors based on performance
      plot_data <- plot_data %>%
        rowwise() %>%
        mutate(
          bar_color = {
            if (is.na(rsp)) {
              "#f59e0b"  # Yellow for DQ
            } else if (lower_display <= national_display && upper_display >= national_display) {
              "#6b7280"  # Gray for no difference
            } else if (direction_rule == "lt") {
              if (upper_display < national_display) "#10b981" else "#ef4444"
            } else {
              if (lower_display > national_display) "#10b981" else "#ef4444"
            }
          }
        ) %>%
        ungroup()

      # Calculate y-axis range
      y_vals <- c(plot_data$lower_display, plot_data$upper_display, national_display)
      y_vals <- y_vals[!is.na(y_vals)]
      y_min <- min(y_vals) * 0.9
      y_max <- max(y_vals) * 1.1

      # Build the plot
      p <- ggplot(plot_data, aes(x = period_label)) +
        # National standard line
        geom_hline(yintercept = national_display,
                   linetype = "dashed", color = "#3b82f6", linewidth = 0.8) +
        # Error bars (confidence intervals)
        geom_errorbar(aes(ymin = lower_display, ymax = upper_display, color = bar_color),
                      width = 0.3, linewidth = 1.2, na.rm = TRUE) +
        # Points for RSP values
        geom_point(aes(y = rsp_display, color = bar_color),
                   size = 3, na.rm = TRUE) +
        # DQ labels for missing data
        geom_text(data = plot_data %>% filter(!has_data),
                  aes(y = national_display, label = "DQ"),
                  color = "#f59e0b", fontface = "bold", size = 3) +
        scale_color_identity() +
        scale_y_continuous(limits = c(y_min, y_max)) +
        theme_minimal() +
        theme(
          axis.title = element_blank(),
          axis.text.x = element_text(size = 7, angle = 0, hjust = 0.5, color = "#6b7280"),
          axis.text.y = element_text(size = 7, color = "#6b7280"),
          panel.grid.major.x = element_blank(),
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_line(color = "#f3f4f6"),
          plot.margin = margin(5, 5, 5, 5)
        )

      renderPlot(p, height = 110, bg = "transparent")
    }

    # Generate KPI boxes for each indicator
    lapply(1:7, function(i) {
      output[[paste0("kpi_box_", i)]] <- renderUI({
        data <- rsp_data()
        if (is.null(data) || nrow(data) == 0) {
          return(div(class = "kpi-box", "Loading..."))
        }

        # Get indicator by sort order
        target_sort <- rsp_indicator_order[i]
        ind_data <- data %>% filter(indicator_sort == target_sort)

        if (nrow(ind_data) == 0) {
          return(div(class = "kpi-box", "No data for this indicator"))
        }

        build_kpi_box(ind_data)
      })
    })

  })
}
