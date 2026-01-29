# app.R - Unified CFSR Shiny Application
# Consolidates 4 separate CFSR apps into one with URL parameter routing
#
# URL ROUTING:
# - ?view=national (default) - National comparison with sidebar navigation
# - ?view=rsp - Risk-Standardized Performance KPI cards
# - ?view=summary - Performance summary table with download
# - ?view=observed - Observed performance (with sub-routing via ?indicator=)
#
# ADDITIONAL PARAMETERS:
# - ?state=MD - State code (default: MD)
# - ?profile=2025_02 - Profile period (default: latest)
# - ?indicator=overview|entry_rate|maltreatment|... (for observed view only)
#
# ARCHITECTURE:
# This app uses dynamic UI rendering based on URL parameters. Each view
# has its own UI/server logic isolated within render functions. Data is
# lazy-loaded based on the current view to optimize performance.

# NOTE: global.R is sourced automatically by Shiny and loads:
# - Libraries (shiny, shinydashboard, plotly, DT, dplyr, ggplot2, etc.)
# - Helper functions from cfsr/functions/
# - Modules from cfsr/modules/
# - Global variables (state_codes, indicator mappings, etc.)

#####################################
# HELPER FUNCTIONS (APP-SPECIFIC) ----
#####################################

# Build RSP confidence interval chart (from app_rsp)
build_rsp_chart <- function(data, national_std, format_type, direction_rule) {
  if (nrow(data) == 0) return(NULL)

  is_pct <- (format_type == "percent")
  multiplier <- if (is_pct) 100 else 1

  original_levels <- if (is.factor(data$period)) levels(data$period) else NULL

  plot_data <- data %>%
    mutate(period_char = trimws(as.character(period)))

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

  national_display <- national_std

  plot_data <- plot_data %>%
    mutate(
      bar_color = case_when(
        is.na(rsp) ~ "#f59e0b",
        status == "better" ~ "#4472C4",
        status == "worse" ~ "#ef4444",
        status == "nodiff" ~ "#6b7280",
        status == "dq" ~ "#f59e0b",
        TRUE ~ "#6b7280"
      ),
      rsp_label = ifelse(!is.na(rsp_display),
                        formatC(rsp_display, digits = 1, format = "f"),
                        "")
    )

  y_vals <- c(plot_data$lower_display, plot_data$upper_display, national_display)
  y_vals <- y_vals[!is.na(y_vals)]
  if (length(y_vals) == 0) return(NULL)

  y_min <- 0
  y_max <- max(y_vals) * 1.1

  plot_data_valid <- plot_data %>% filter(has_data)
  plot_data_dq <- plot_data %>% filter(!has_data)

  p <- ggplot(plot_data, aes(x = period_label)) +
    geom_hline(yintercept = national_display,
               linetype = "dashed", color = "#10b981", linewidth = 0.8)

  if (nrow(plot_data_valid) > 0) {
    p <- p +
      geom_errorbar(data = plot_data_valid,
                    aes(ymin = lower_display, ymax = upper_display,
                        color = bar_color, group = period_label),
                    width = 0.2, linewidth = 0.8) +
      geom_line(data = plot_data_valid,
                aes(y = rsp_display, group = 1),
                color = "#6b7280", linewidth = 0.5) +
      geom_point(data = plot_data_valid,
                 aes(y = rsp_display, color = bar_color, group = period_label),
                 size = 2) +
      scale_color_identity()
  }

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

# Build observed performance trend chart (from app_observed)
build_observed_chart <- function(data, national_std, format_type, direction_rule) {
  if (nrow(data) == 0) return(NULL)

  is_pct <- (format_type == "percent")
  multiplier <- if (is_pct) 100 else 1

  period_order <- unique(data$period)

  plot_data <- data %>%
    mutate(
      observed_display = performance * multiplier,
      period = factor(period, levels = period_order)
    )

  y_vals <- c(plot_data$observed_display, national_std)
  y_vals <- y_vals[!is.na(y_vals)]

  if (length(y_vals) == 0) {
    y_max <- if (is_pct) 100 else 10
  } else {
    y_max <- max(y_vals, na.rm = TRUE) * 1.25
  }

  p <- ggplot(plot_data, aes(x = period, y = observed_display, group = 1))

  p <- p + geom_hline(yintercept = national_std,
                     linetype = "dashed", color = "#10b981", linewidth = 0.8)

  p <- p + geom_line(color = "#6b7280", linewidth = 0.5)

  plot_data_valid <- plot_data %>% filter(!is.na(observed_display))
  plot_data_dq <- plot_data %>% filter(is.na(observed_display))

  if (nrow(plot_data_valid) > 0) {
    p <- p + geom_point(data = plot_data_valid,
                       aes(color = status), size = 2)
  }

  if (nrow(plot_data_valid) > 0) {
    first_row <- plot_data_valid[1, ]
    last_row <- plot_data_valid[nrow(plot_data_valid), ]

    label_data <- bind_rows(first_row, last_row) %>%
      distinct()

    label_data <- label_data %>%
      mutate(
        label_text = if (is_pct) {
          paste0(round(observed_display, 1), "%")
        } else {
          as.character(round(observed_display, 2))
        }
      )

    p <- p +
      geom_text(data = label_data,
                aes(y = observed_display, label = label_text),
                color = "#6b7280", fontface = "bold", size = 3.5, vjust = -1.1)
  }

  if (nrow(plot_data_dq) > 0) {
    dq_y <- y_max * 0.05
    p <- p + geom_text(data = plot_data_dq,
                      aes(x = period, y = dq_y),
                      label = "DQ", color = "#f59e0b", fontface = "bold", size = 3)
  }

  p <- p + scale_color_manual(
    values = c(
      "better" = "#4472C4",
      "worse" = "#ef4444",
      "nodiff" = "#6b7280",
      "dq" = "#f59e0b"
    ),
    guide = "none"
  )

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
  # Consolidated CSS from all 4 apps
  tags$head(
    # html2canvas library for downloads (used by summary and observed views)
    tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"),

    # Download functions for summary and observed views
    tags$script(HTML("
      function downloadSummary(containerId, filename) {
        const element = document.getElementById(containerId);
        const button = element.querySelector('.summary-download-button .btn');

        if (!button) return;

        const originalText = button.innerHTML;
        button.innerHTML = '<i class=\"fa fa-spinner fa-spin\"></i> Capturing...';
        button.disabled = true;

        element.classList.add('exporting');

        html2canvas(element, {
          backgroundColor: '#ffffff',
          scale: 2,
          logging: false,
          useCORS: true,
          allowTaint: false
        }).then(canvas => {
          element.classList.remove('exporting');
          button.innerHTML = originalText;
          button.disabled = false;

          canvas.toBlob(blob => {
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
          });
        }).catch(err => {
          console.error('Screenshot failed:', err);
          element.classList.remove('exporting');
          button.innerHTML = originalText;
          button.disabled = false;
          alert('Failed to capture screenshot');
        });
      }

      function downloadViz(containerId, filename) {
        const element = document.getElementById(containerId);
        const button = element.querySelector('.viz-download-button .btn');

        if (!element) {
          console.error('Container not found:', containerId);
          return;
        }

        if (button) {
          button.classList.add('btn-clicked');
          button.disabled = true;
        }

        element.classList.add('exporting');

        html2canvas(element, {
          backgroundColor: '#ffffff',
          scale: 2,
          logging: false,
          useCORS: true
        }).then(canvas => {
          element.classList.remove('exporting');

          const link = document.createElement('a');
          link.download = filename;
          link.href = canvas.toDataURL('image/png');
          link.click();

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

    # Consolidated CSS
    tags$style(HTML("
      /* ===== BASE STYLES ===== */
      body {
        background-color: #f9fafb;
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

      /* ===== NATIONAL VIEW (DASHBOARD) STYLES ===== */
      .content-wrapper { background-color: #f4f4f4; }
      .box { box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
      .chart-title { font-size: 20px; font-weight: bold; margin-bottom: 5px; }
      .chart-period { font-size: 16px; font-style: italic; color: #666; margin-bottom: 10px; }
      .chart-description { font-size: 13px; color: #333; margin-bottom: 10px; line-height: 1.5; }
      .chart-target { font-size: 13px; color: #666; margin-bottom: 10px; }
      .chart-footnote { font-size: 11px; color: #666; margin-top: 5px; }
      .state-badge { background-color: #4472C4; color: white; padding: 5px 10px;
                     border-radius: 4px; font-weight: bold; }
      .profile-badge { background-color: #f0f0f0; padding: 5px 10px;
                       border-radius: 4px; font-size: 13px; }

      /* Sidebar styling - dark background */
      .main-sidebar { background-color: #2c3e50 !important; }
      .sidebar { background-color: #2c3e50 !important; }
      .skin-blue .main-sidebar { background-color: #2c3e50 !important; }

      /* Section headers */
      .sidebar-menu li.header {
        font-size: 13px !important;
        text-transform: uppercase;
        color: #ecf0f1 !important;
        font-weight: 700;
        padding: 12px 15px !important;
        letter-spacing: 1px;
        background-color: rgba(52, 73, 94, 0.6) !important;
        margin: 8px 0 4px 0 !important;
        cursor: default !important;
        pointer-events: none !important;
        user-select: none !important;
      }
      .skin-blue .sidebar-menu li.header {
        color: #ecf0f1 !important;
        background-color: rgba(52, 73, 94, 0.6) !important;
      }
      .sidebar-menu li.header:hover,
      .sidebar-menu li.header:active,
      .sidebar-menu li.header:focus {
        background-color: rgba(52, 73, 94, 0.6) !important;
        color: #ecf0f1 !important;
        cursor: default !important;
      }

      /* Sidebar menu items */
      .sidebar-menu > li > a {
        color: #bdc3c7 !important;
        background-color: transparent !important;
        padding: 7px 15px 7px 20px !important;
        text-decoration: none;
        border-left: 3px solid transparent;
        font-size: 14px;
        line-height: 1.4;
      }
      .sidebar-menu > li > a:hover {
        color: #ffffff !important;
        background-color: rgba(52, 73, 94, 0.4) !important;
        text-decoration: none !important;
      }
      .sidebar-menu > li.active > a {
        color: #ffffff !important;
        background-color: rgba(52, 152, 219, 0.3) !important;
        font-weight: 500;
        border-left: 3px solid #3498db;
        text-decoration: none;
      }
      .sidebar-menu > li > a > .fa,
      .sidebar-menu > li > a > .glyphicon {
        display: none;
      }
      .sidebar-menu li { margin-bottom: 1px; }

      /* Reduce top whitespace */
      .content-wrapper, .right-side { padding-top: 0 !important; }
      .main-sidebar { padding-top: 0 !important; margin-top: 0 !important; border-right: 1px solid #e0e0e0; }
      .sidebar { padding-top: 10px !important; }
      body, html { margin-top: 0 !important; padding-top: 0 !important; }

      /* ===== RSP & OBSERVED VIEW (KPI CARD) STYLES ===== */
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
        border-radius: 10px;
        padding: 16px 16px 10px 16px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
        max-width: 100%;
        position: relative;
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
        display: flex;
        justify-content: space-between;
        align-items: center;
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

      /* Info icon popup */
      .info-icon {
        font-size: 1.5rem;
        cursor: pointer;
        opacity: 0.8;
        transition: opacity 0.2s;
        position: relative;
        display: inline-block;
      }
      .info-icon:hover { opacity: 1; }
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
      .info-icon:hover .info-popup { display: block; }
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
      .interpretation-bar, .interpretation-point {
        width: 12px;
        height: 12px;
        border-radius: 50%;
        flex-shrink: 0;
      }
      .interpretation-bar.better, .interpretation-point.better { background: #4472C4; }
      .interpretation-bar.worse, .interpretation-point.worse { background: #ef4444; }
      .interpretation-bar.nodiff, .interpretation-point.nodiff { background: #6b7280; }
      .interpretation-bar.dq, .interpretation-point.dq { background: #f59e0b; }
      .interpretation-bar.national, .interpretation-line.national {
        width: 20px;
        height: 0;
        background: none;
        border-bottom: 2px dashed #10b981;
        border-radius: 0;
      }
      .interpretation-guide, .interpretation-notes {
        font-size: 0.95rem;
        color: #374151;
        line-height: 1.6;
      }
      .interpretation-guide p, .interpretation-notes p {
        margin: 0 0 6px 0;
      }
      .interpretation-guide p:last-child {
        margin-bottom: 0;
      }

      /* ===== SUMMARY VIEW STYLES ===== */
      .summary-card {
        position: relative;
        background: white;
        padding: 20px 24px;
        border-radius: 8px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        margin-bottom: 20px;
      }
      .summary-header {
        margin-bottom: 20px;
        padding-bottom: 16px;
        border-bottom: 1px solid #e5e7eb;
      }
      .summary-title {
        font-size: 16px;
        font-weight: 700;
        color: #4472C4;
        margin: 0 0 8px 0;
        letter-spacing: -0.5px;
      }
      .summary-subtitle {
        font-size: 14px;
        color: #6b7280;
        margin: 0;
        line-height: 1.6;
        font-weight: 400;
      }
      .summary-download-button {
        position: absolute;
        top: 16px;
        right: 16px;
        z-index: 10;
      }
      .summary-card.exporting .summary-download-button {
        display: none;
      }
      .summary-source {
        margin-top: 16px;
        padding-top: 12px;
        border-top: 1px solid #e5e7eb;
        font-size: 11px;
        color: #6b7280;
      }

      /* Status pills */
      .status-pill {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 12px;
        font-size: 13px;
        font-weight: 600;
        white-space: nowrap;
      }
      .status-pill.better {
        color: white;
        background-color: #4472C4;
      }
      .status-pill.worse {
        color: #dc2626;
        background-color: #fee2e2;
      }
      .status-pill.nodiff {
        color: #6b7280;
        background-color: #f3f4f6;
      }
      .status-pill.dq {
        color: #f59e0b;
        background-color: #fef3c7;
      }

      /* Rank pill */
      .rank-pill {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 12px;
        font-size: 13px;
        font-weight: 600;
        white-space: nowrap;
        color: #374151;
        background-color: #e5e7eb;
      }

      /* Period value */
      .period-value {
        font-size: 13px;
        color: #374151;
      }

      /* Indicator table */
      .indicator-table {
        margin: 8px 0 0 0;
      }
      .indicator-header {
        display: grid;
        grid-template-columns: 2fr 1fr 1fr 140px 80px 120px;
        gap: 12px;
        padding: 8px 0;
        font-size: 13px;
        font-weight: 600;
        color: #6b7280;
        border-bottom: 2px solid #e5e7eb;
        margin-bottom: 8px;
      }
      .indicator-list {
        list-style: none;
        padding: 0;
        margin: 0;
      }
      .indicator-row {
        display: grid;
        grid-template-columns: 2fr 1fr 1fr 140px 80px 120px;
        gap: 12px;
        padding: 8px 0;
        font-size: 15px;
        color: #374151;
        line-height: 1.5;
        border-bottom: 1px solid #f3f4f6;
        align-items: center;
      }
      .indicator-row:last-child {
        border-bottom: none;
      }
      .indicator-name {
        font-weight: 500;
      }
      .indicator-value {
        font-weight: 600;
      }
      .national-standard {
        font-weight: 600;
      }
      .table-footnote {
        margin-top: 12px;
        font-size: 11px;
        color: #6b7280;
        font-style: italic;
      }

      /* ===== OBSERVED VIEW INDICATOR DETAIL STYLES ===== */
      .indicator-detail-container {
        background: white;
        border: 1px solid #e5e7eb;
        border-radius: 6px;
        padding: 20px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      }

      /* Viz container styles */
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
      .viz-download-button .btn-clicked {
        background-color: #2c5aa0 !important;
        transform: scale(0.95);
      }
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
      .viz-pills-row {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 12px;
        flex-wrap: wrap;
      }
      .viz-period-pill {
        display: inline-block;
        background: #4472C4;
        color: white;
        font-size: 12px;
        font-weight: 600;
        padding: 4px 12px;
        border-radius: 12px;
      }
      .viz-state-pill {
        display: inline-block;
        background: #f59e0b;
        color: white;
        font-size: 12px;
        font-weight: 600;
        padding: 4px 12px;
        border-radius: 12px;
        margin-right: 16px;
      }
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
      .viz-source {
        font-size: 11px;
        color: #6b7280;
        margin-top: 4px;
        padding-top: 4px;
        border-top: 1px solid #e5e7eb;
      }
      .viz-notes {
        font-size: 11px;
        color: #6b7280;
        margin-top: 12px;
      }
    "))
  ),

  # Dynamic UI based on view parameter
  uiOutput("main_content")
)

#####################################
# SERVER ----
#####################################

server <- function(input, output, session) {

  #####################################
  # URL PARAMETER DETECTION ----
  #####################################

  # Detect view from URL (national, rsp, summary, observed)
  view_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$view %||% "national"
  })

  # Detect state from URL
  state_code_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    code <- toupper(query$state %||% "MD")
    if (!code %in% names(state_codes)) code <- "MD"
    code
  })

  # Detect profile from URL
  profile_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$profile %||% "latest"
  })

  # Detect indicator sub-view for observed (overview, entry_rate, maltreatment, etc.)
  indicator_rv <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$indicator %||% "overview"
  })

  # Get state name from code
  state_name_rv <- reactive({
    state_codes[[state_code_rv()]]
  })

  #####################################
  # LAZY DATA LOADING ----
  #####################################

  # Load data based on current view
  # National view data
  national_data <- reactive({
    req(view_rv() == "national")
    load_cfsr_data(state_code_rv(), profile_rv(), type = "national")
  })

  # RSP view data
  rsp_data <- reactive({
    req(view_rv() == "rsp")
    state <- state_code_rv()
    profile <- profile_rv()
    tryCatch({
      load_rsp_data(state, profile)
    }, error = function(e) {
      NULL
    })
  })

  # Summary view data (uses observed data)
  summary_data <- reactive({
    req(view_rv() == "summary")
    state <- state_code_rv()
    profile <- profile_rv()
    tryCatch({
      load_observed_data(state, profile)
    }, error = function(e) {
      NULL
    })
  })

  # Observed view data (both observed and national)
  observed_data <- reactive({
    req(view_rv() == "observed")
    load_cfsr_data(state_code_rv(), profile_rv(), type = "observed")
  })

  observed_national_data <- reactive({
    req(view_rv() == "observed")
    data <- load_cfsr_data(state_code_rv(), profile_rv(), type = "national")
    # Filter to most recent period per indicator for bar charts
    data %>%
      group_by(indicator) %>%
      filter(period == max(period, na.rm = TRUE)) %>%
      ungroup()
  })

  #####################################
  # MAIN CONTENT ROUTER ----
  #####################################

  output$main_content <- renderUI({
    view <- view_rv()

    # Route to appropriate view
    if (view == "national") {
      render_national_view()
    } else if (view == "rsp") {
      render_rsp_view()
    } else if (view == "summary") {
      render_summary_view()
    } else if (view == "observed") {
      render_observed_view()
    } else {
      # Default to national view
      render_national_view()
    }
  })

  #####################################
  # NATIONAL VIEW (DASHBOARD) ----
  #####################################

  render_national_view <- function() {
    # Get sidebar indicators from data
    data <- national_data()
    sidebar_indicators <- data %>%
      distinct(indicator, indicator_very_short, indicator_sort, category) %>%
      arrange(indicator_sort)

    # Build dashboard UI
    dashboardPage(
      skin = "blue",

      dashboardHeader(disable = TRUE),

      dashboardSidebar(
        width = 200,
        sidebarMenu(
          id = "sidebar_menu",

          menuItem("Overview", tabName = "overview", icon = NULL),
          tags$li(tags$a(href = "#shiny-tab-entry_rate", `data-toggle` = "tab", `data-value` = "entry_rate",
                         title = "Foster care entry rate (entries / 1,000 children)", "Entry rate")),

          tags$li(class = "header", "SAFETY"),
          tags$li(tags$a(href = "#shiny-tab-maltreatment", `data-toggle` = "tab", `data-value` = "maltreatment",
                         title = "Maltreatment in care (victimizations / 100,000 days in care)", "Maltreatment in care")),
          tags$li(tags$a(href = "#shiny-tab-recurrence", `data-toggle` = "tab", `data-value` = "recurrence",
                         title = "Maltreatment recurrence within 12 months", "Recurrence")),

          tags$li(class = "header", "PERMANENCY"),
          tags$li(tags$a(href = "#shiny-tab-perm12_entries", `data-toggle` = "tab", `data-value` = "perm12_entries",
                         title = "Permanency in 12 months for children entering care", "Perm 12mo - Entries")),
          tags$li(tags$a(href = "#shiny-tab-perm12_12_23", `data-toggle` = "tab", `data-value` = "perm12_12_23",
                         title = "Permanency in 12 months for children in care 12-23 months", "Perm 12mo - 12-23mo")),
          tags$li(tags$a(href = "#shiny-tab-perm12_24", `data-toggle` = "tab", `data-value` = "perm12_24",
                         title = "Permanency in 12 months for children in care 24 months or more", "Perm 12mo - 24+mo")),
          tags$li(tags$a(href = "#shiny-tab-reentry", `data-toggle` = "tab", `data-value` = "reentry",
                         title = "Reentry to foster care within 12 months", "Reentry")),

          tags$li(class = "header", "WELL-BEING"),
          tags$li(tags$a(href = "#shiny-tab-placement", `data-toggle` = "tab", `data-value` = "placement",
                         title = "Placement stability (moves / 1,000 days in care)", "Placement stability"))
        )
      ),

      dashboardBody(
        tabItems(
          # Overview tab
          tabItem(
            tabName = "overview",

            fluidRow(
              column(12,
                div(style = "margin-bottom: 15px; padding: 10px; background-color: #f8f9fa; border-left: 3px solid #4472C4;",
                  tags$p(style = "margin: 0; font-size: 13px; color: #333;",
                    "The data on this page show states' ",
                    tags$em("observed"),
                    " performance (i.e., without risk-adjustment).",
                    tags$br(),
                    "This data is from ",
                    textOutput("national_data_source_text", inline = TRUE),
                    " (specifically, the National supplemental context data Excel file)."
                  )
                )
              )
            ),

            fluidRow(
              column(12,
                h2(textOutput("national_state_performance_title", inline = TRUE)),
                p("Most recent period available. Lower rank is better.")
              )
            ),
            fluidRow(
              column(12,
                box(
                  width = 12,
                  DT::dataTableOutput("national_state_performance_table"),
                  p(style = "font-size: 11px; color: #666; margin-top: 10px;",
                    "DQ = Not calculated due to data quality issues. Reporting States = The number of states whose performance could be calculated.")
                )
              )
            ),

            fluidRow(
              column(12,
                box(
                  width = 12,
                  title = "View Rankings for All States",
                  collapsible = TRUE,
                  collapsed = TRUE,
                  status = "primary",
                  solidHeader = TRUE,
                  DT::dataTableOutput("national_overview_rankings_table")
                )
              )
            )
          ),

          # Indicator tabs
          tabItem(tabName = "entry_rate", indicator_page_ui("entry_rate")),
          tabItem(tabName = "maltreatment", indicator_page_ui("maltreatment")),
          tabItem(tabName = "perm12_entries", indicator_page_ui("perm12_entries")),
          tabItem(tabName = "perm12_12_23", indicator_page_ui("perm12_12_23")),
          tabItem(tabName = "perm12_24", indicator_page_ui("perm12_24")),
          tabItem(tabName = "placement", indicator_page_ui("placement")),
          tabItem(tabName = "reentry", indicator_page_ui("reentry")),
          tabItem(tabName = "recurrence", indicator_page_ui("recurrence"))
        )
      )
    )
  }

  # National view server logic
  observe({
    req(view_rv() == "national")

    data <- national_data()
    profile_ver <- reactive({
      if (!is.null(data$profile_version[1])) {
        data$profile_version[1]
      } else {
        NULL
      }
    })

    # Overview page outputs
    output$national_data_source_text <- renderText({
      pv <- profile_ver()
      if (!is.null(pv) && pv != "") {
        paste0("the ", pv, " Data Profile")
      } else {
        paste(state_name_rv(), "Recent Data Profile")
      }
    })

    output$national_state_performance_title <- renderText({
      state <- state_name_rv()
      if (!is.null(state)) {
        paste0(state, "'s Performance on CFSR Statewide Data Indicators")
      } else {
        "State Performance on CFSR Statewide Data Indicators"
      }
    })

    output$national_state_performance_table <- DT::renderDataTable({
      table_data <- build_state_performance_table(data, state_name_rv())

      if (is.null(table_data)) {
        return(NULL)
      }

      DT::datatable(
        table_data,
        options = list(
          dom = 't',
          ordering = FALSE,
          columnDefs = list(
            list(className = 'dt-center', targets = 1:4)
          ),
          initComplete = JS(
            "function(settings, json) {",
            "  $(this.api().table().container()).css({'font-size': '12px'});",
            "  $(this.api().table().header()).css({'font-size': '12px', 'padding': '4px'});",
            "  $(this.api().table().body()).find('td').css({'padding': '4px 8px'});",
            "}"
          )
        ),
        rownames = FALSE,
        selection = 'none',
        class = 'cell-border stripe compact hover'
      )
    })

    output$national_overview_rankings_table <- DT::renderDataTable({
      table_data <- build_overview_rankings_table(data, state_name_rv())

      DT::datatable(
        table_data,
        options = list(
          pageLength = 52,
          dom = 't',
          scrollY = "600px",
          scrollCollapse = TRUE,
          ordering = TRUE,
          order = list(list(0, 'asc')),
          columnDefs = list(
            list(className = 'dt-center', targets = 1:(ncol(table_data) - 1))
          ),
          initComplete = JS(
            "function(settings, json) {",
            "  $(this.api().table().container()).css({'font-size': '12px'});",
            "  $(this.api().table().header()).css({'font-size': '12px', 'padding': '4px'});",
            "  $(this.api().table().body()).find('td').css({'padding': '4px 8px'});",
            "}"
          )
        ),
        rownames = FALSE,
        selection = 'none',
        class = 'cell-border stripe compact hover'
      ) %>%
        DT::formatStyle(
          'State',
          target = 'row',
          backgroundColor = DT::styleEqual(state_name_rv(), '#E8F4FD')
        )
    })

    # Indicator pages
    indicator_page_server(
      "entry_rate",
      indicator_name = "Foster care entry rate (entries / 1,000 children)",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )

    indicator_page_server(
      "maltreatment",
      indicator_name = "Maltreatment in care (victimizations / 100,000 days in care)",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )

    indicator_page_server(
      "perm12_entries",
      indicator_name = "Permanency in 12 months for children entering care",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )

    indicator_page_server(
      "perm12_12_23",
      indicator_name = "Permanency in 12 months for children in care 12-23 months",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )

    indicator_page_server(
      "perm12_24",
      indicator_name = "Permanency in 12 months for children in care 24 months or more",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )

    indicator_page_server(
      "placement",
      indicator_name = "Placement stability (moves / 1,000 days in care)",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )

    indicator_page_server(
      "reentry",
      indicator_name = "Reentry to foster care within 12 months",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )

    indicator_page_server(
      "recurrence",
      indicator_name = "Maltreatment recurrence within 12 months",
      app_data = national_data,
      selected_state = state_name_rv,
      profile_version = profile_ver
    )
  })

  #####################################
  # RSP VIEW (KPI CARDS) ----
  #####################################

  render_rsp_view <- function() {
    tagList(
      div(class = "header",
        h1(textOutput("rsp_header_title")),
        p(class = "subtitle", textOutput("rsp_header_subtitle"))
      ),

      # Row 1: Interpretation + Safety
      div(class = "kpi-grid-row",
        div(class = "interpretation-kpi",
          div(class = "kpi-title",
            span("How to Interpret RSP Charts"),
            span(class = "info-icon", "\u24D8",
              div(class = "info-popup",
                tags$img(src = "kpi_help.png", alt = "KPI Help Guide",
                         style = "width: 100%; max-width: 500px;")
              )
            )
          ),

          div(class = "interpretation-legend",
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
            div(class = "interpretation-legend-item",
              div(class = "interpretation-bar dq"),
              span("Data quality issue")
            ),
            div(class = "interpretation-legend-item",
              div(class = "interpretation-bar national"),
              span("National performance")
            )
          ),

          div(class = "interpretation-guide",
            p("Risk-Standardized Performance (RSP) is the percent or rate of children experiencing the outcome, with risk adjustment. The vertical bars in each graph represent the lower and upper 95% confidence intervals for the RSP."),
            p("To be statistically better or worse than national performance, the entire RSP interval needs to be above or below national performance (the dotted blue line).")
          )
        ),

        uiOutput("rsp_kpi_1"),
        uiOutput("rsp_kpi_2")
      ),

      # Row 2: Permanency
      div(class = "kpi-grid-row",
        uiOutput("rsp_kpi_3"),
        uiOutput("rsp_kpi_4"),
        uiOutput("rsp_kpi_5")
      ),

      # Row 3: Reentry + Placement
      div(class = "kpi-grid-row",
        uiOutput("rsp_kpi_6"),
        uiOutput("rsp_kpi_7")
      )
    )
  }

  # RSP view server logic
  observe({
    req(view_rv() == "rsp")

    data <- rsp_data()

    output$rsp_header_title <- renderText({
      paste("Risk-Standardized Performance —", state_name_rv())
    })

    output$rsp_header_subtitle <- renderText({
      if (is.null(data) || nrow(data) == 0) {
        return("No RSP data available for this state/profile")
      }
      profile_ver <- unique(data$profile_version)[1]
      paste0("CFSR Round 4 Data Profile | ", profile_ver)
    })

    # Build KPI for RSP
    build_rsp_kpi_output <- function(indicator_sort_val) {
      if (is.null(data) || nrow(data) == 0) {
        return(div(class = "kpi-box", p("No data available")))
      }

      ind_data <- data %>% filter(indicator_sort == indicator_sort_val)
      if (nrow(ind_data) == 0) {
        return(div(class = "kpi-box", p("No data for this indicator")))
      }

      ind_short <- ind_data$indicator_short[1]
      ind_desc <- ind_data$description[1]
      format_type <- ind_data$format[1]
      decimal_prec <- ind_data$decimal_precision[1]
      scale_val <- ind_data$scale[1]
      direction_rule <- ind_data$direction_rule[1]
      direction_legend <- ind_data$direction_legend[1]
      national_std <- ind_data$national_standard[1]

      latest <- ind_data %>% arrange(desc(period)) %>% slice(1)
      latest_rsp <- latest$rsp
      status_val <- latest$status

      if (format_type == "percent") {
        display_val <- if (!is.na(latest_rsp)) formatC(latest_rsp * 100, digits = decimal_prec, format = "f") else "DQ"
        unit_label <- "%"
        national_display <- formatC(national_std, digits = decimal_prec, format = "f")
        national_unit <- "%"
      } else {
        display_val <- if (!is.na(latest_rsp)) formatC(latest_rsp, digits = decimal_prec, format = "f") else "DQ"
        unit_label <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
        national_display <- formatC(national_std, digits = decimal_prec, format = "f")
        national_unit <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
      }

      arrow <- if (direction_rule == "lt") "\u25BC" else "\u25B2"

      value_color <- switch(status_val,
        "better" = "#4472C4",
        "worse" = "#ef4444",
        "nodiff" = "#6b7280",
        "dq" = "#f59e0b",
        "#111827"
      )

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
            build_rsp_chart(ind_data, national_std, format_type, direction_rule)
          }, height = 100, bg = "transparent")
        )
      )
    }

    output$rsp_kpi_1 <- renderUI({ build_rsp_kpi_output(rsp_indicator_order[1]) })
    output$rsp_kpi_2 <- renderUI({ build_rsp_kpi_output(rsp_indicator_order[2]) })
    output$rsp_kpi_3 <- renderUI({ build_rsp_kpi_output(rsp_indicator_order[3]) })
    output$rsp_kpi_4 <- renderUI({ build_rsp_kpi_output(rsp_indicator_order[4]) })
    output$rsp_kpi_5 <- renderUI({ build_rsp_kpi_output(rsp_indicator_order[5]) })
    output$rsp_kpi_6 <- renderUI({ build_rsp_kpi_output(rsp_indicator_order[6]) })
    output$rsp_kpi_7 <- renderUI({ build_rsp_kpi_output(rsp_indicator_order[7]) })
  })

  #####################################
  # SUMMARY VIEW (PERFORMANCE TABLE) ----
  #####################################

  render_summary_view <- function() {
    uiOutput("summary_sections")
  }

  # Summary view server logic
  observe({
    req(view_rv() == "summary")

    data <- summary_data()

    # Get latest period data for each indicator
    latest_data <- reactive({
      req(data)
      data %>%
        group_by(indicator_sort) %>%
        arrange(desc(period)) %>%
        slice(1) %>%
        ungroup()
    })

    # Helper function to format indicator value
    format_indicator_value <- function(ind_data) {
      precision <- if (!is.null(ind_data$decimal_precision) && !is.na(ind_data$decimal_precision)) {
        ind_data$decimal_precision
      } else {
        1
      }

      format_str <- paste0("%.", precision, "f")
      if (ind_data$format == "percent") {
        if (!is.na(ind_data$national_standard)) {
          national <- paste0(" (", sprintf(format_str, as.numeric(ind_data$national_standard)), "%)")
        } else {
          national <- ""
        }
      } else {
        if (!is.na(ind_data$national_standard)) {
          national <- paste0(" (", sprintf(format_str, as.numeric(ind_data$national_standard)), ")")
        } else {
          national <- ""
        }
      }

      if (is.na(ind_data$performance)) {
        return(list(value = "DQ", unit = "", national = national))
      }

      if (ind_data$format == "percent") {
        value <- sprintf(format_str, ind_data$performance * 100)
        unit <- "%"
      } else {
        value <- sprintf(format_str, ind_data$performance)
        if (grepl("Maltreatment", ind_data$indicator_short, ignore.case = TRUE)) {
          unit <- " victimizations"
        } else if (grepl("Placement", ind_data$indicator_short, ignore.case = TRUE)) {
          unit <- " moves"
        } else {
          unit <- ""
        }
      }

      list(value = value, unit = unit, national = national)
    }

    output$summary_sections <- renderUI({
      req(latest_data())
      latest <- latest_data() %>%
        arrange(indicator_sort)

      status_pill <- function(status_val) {
        pill_text <- case_when(
          status_val == "better" ~ "Better",
          status_val == "worse" ~ "Worse",
          status_val == "nodiff" ~ "No Difference",
          TRUE ~ "Data Quality"
        )

        span(class = paste("status-pill", status_val), pill_text)
      }

      format_rank <- function(ind_data) {
        if (!is.null(ind_data$state_rank) && !is.null(ind_data$reporting_states) &&
            !is.na(ind_data$state_rank) && !is.na(ind_data$reporting_states)) {
          span(class = "rank-pill",
            paste0(ind_data$state_rank, " of ", ind_data$reporting_states)
          )
        } else {
          span("—")
        }
      }

      div(
        id = "summary-container",
        class = "summary-card",

        div(class = "summary-download-button",
          actionButton(
            "download_summary",
            "Download",
            icon = icon("download"),
            onclick = sprintf(
              "downloadSummary('%s', 'cfsr_summary_%s.png')",
              "summary-container",
              tolower(state_name_rv())
            )
          )
        ),

        div(class = "summary-header",
          div(class = "summary-title",
            paste("CFSR Performance Summary —", state_name_rv())
          ),
          div(class = "summary-subtitle",
            paste0("CFSR Round 4 Data Profile | ", latest$profile_version[1])
          )
        ),

        div(class = "indicator-table",
          div(class = "indicator-header",
            span("Indicator"),
            span("State's Observed Perf"),
            span("National Performance"),
            span("Compared to National*"),
            span("Rank**"),
            span("Period")
          ),
          tags$ul(class = "indicator-list",
            lapply(1:nrow(latest), function(i) {
              ind <- latest[i, ]
              formatted <- format_indicator_value(ind)
              tags$li(class = "indicator-row",
                span(class = "indicator-name", ind$indicator_short),
                span(class = "indicator-value",
                  paste0(formatted$value, formatted$unit)
                ),
                span(class = "national-standard",
                  gsub("^\\s*\\(|\\)$", "", formatted$national)
                ),
                status_pill(ind$status),
                format_rank(ind),
                span(class = "period-value", ind$period_meaningful)
              )
            })
          )
        ),

        div(class = "summary-source",
          paste0("Source: ", latest$source[1])
        ),

        div(class = "table-footnote",
          div("* Based on the state's risk-standardized performance, which is its observed performance after risk-adjustment."),
          div("** Based on the state's observed performance among states whose performance could be calculated.")
        )
      )
    })
  })

  #####################################
  # OBSERVED VIEW (KPI + INDICATOR DETAIL) ----
  #####################################

  render_observed_view <- function() {
    indicator <- indicator_rv()

    if (indicator == "overview") {
      # Overview page with 7 KPI cards
      tagList(
        div(class = "header",
          h1(textOutput("observed_header_title")),
          p(class = "subtitle", textOutput("observed_header_subtitle"))
        ),

        div(class = "kpi-grid-row",
          div(class = "interpretation-kpi",
            div(class = "kpi-title",
              span("How to Interpret Observed Performance Charts"),
              span(class = "info-icon", "\u24D8",
                div(class = "info-popup",
                  tags$img(src = "kpi_observed_help.png", alt = "KPI Help Guide",
                           style = "width: 100%; max-width: 500px;")
                )
              )
            ),

            div(class = "interpretation-legend",
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
              div(class = "interpretation-legend-item",
                div(class = "interpretation-point dq"),
                span("Data quality issue")
              ),
              div(class = "interpretation-legend-item",
                div(class = "interpretation-line national"),
                span("National standard")
              ),
              div(class = "interpretation-legend-item")
            ),

            div(class = "interpretation-notes",
              tags$p("Observed performance is the percent or rate of children experiencing the outcome, without risk-adjustment."),
              tags$p("Whether performance is statistically better, worse, or no different from national performance is based on your state's risk-standardized performance (RSP). The results are shown here for convenience.")
            )
          ),

          uiOutput("obs_kpi_1"),
          uiOutput("obs_kpi_2")
        ),

        div(class = "kpi-grid-row",
          uiOutput("obs_kpi_3"),
          uiOutput("obs_kpi_4"),
          uiOutput("obs_kpi_5")
        ),

        div(class = "kpi-grid-row",
          uiOutput("obs_kpi_6"),
          uiOutput("obs_kpi_7"),
          div()
        )
      )
    } else if (indicator %in% names(view_to_indicator)) {
      # Indicator detail page
      div(class = "indicator-detail-container",
        indicator_detail_ui(indicator)
      )
    } else {
      # Invalid indicator
      div(
        div(class = "header",
          h1("Invalid Indicator"),
          p(class = "subtitle", paste("Unknown indicator:", indicator))
        ),
        p("Defaulting to Overview page...")
      )
    }
  }

  # Observed view server logic
  observe({
    req(view_rv() == "observed")

    data <- observed_data()
    national_data_obs <- observed_national_data()

    profile_version <- reactive({
      if (is.null(data) || nrow(data) == 0) return("Unknown")
      unique(data$profile_version)[1]
    })

    output$observed_header_title <- renderText({
      paste("Observed Performance —", state_name_rv())
    })

    output$observed_header_subtitle <- renderText({
      paste0("CFSR Round 4 Data Profile | ", profile_version())
    })

    # Build KPI for observed
    build_obs_kpi_output <- function(indicator_sort_val) {
      if (is.null(data) || nrow(data) == 0) {
        return(div(class = "kpi-box", p("No data available")))
      }

      ind_data <- data %>% filter(indicator_sort == indicator_sort_val)
      if (nrow(ind_data) == 0) {
        return(div(class = "kpi-box", p("No data for this indicator")))
      }

      ind_short <- ind_data$indicator_short[1]
      ind_desc <- ind_data$description[1]
      national_std <- ind_data$national_standard[1]
      direction_rule <- ind_data$direction_rule[1]
      direction_legend <- ind_data$direction_legend[1]
      format_type <- ind_data$format[1]
      decimal_prec <- ind_data$decimal_precision[1]

      latest <- ind_data %>% arrange(desc(period)) %>% slice(1)
      latest_val <- latest$performance

      if (format_type == "percent") {
        display_val <- if (!is.na(latest_val)) formatC(latest_val * 100, digits = decimal_prec, format = "f") else "DQ"
        unit_label <- "%"
        national_display <- formatC(national_std, digits = decimal_prec, format = "f")
        national_unit <- "%"
      } else {
        display_val <- if (!is.na(latest_val)) formatC(latest_val, digits = decimal_prec, format = "f") else "DQ"
        unit_label <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
        national_display <- formatC(national_std, digits = decimal_prec, format = "f")
        national_unit <- if (indicator_sort_val == 1) " victimizations" else if (indicator_sort_val == 8) " moves" else ""
      }

      arrow <- if (direction_rule == "lt") "\u25BC" else "\u25B2"

      status_val <- latest$status
      value_color <- switch(status_val,
        "better" = "#4472C4",
        "worse" = "#ef4444",
        "nodiff" = "#6b7280",
        "dq" = "#f59e0b",
        "#6b7280"
      )

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
            build_observed_chart(ind_data, national_std, format_type, direction_rule)
          }, height = 100, bg = "transparent")
        )
      )
    }

    output$obs_kpi_1 <- renderUI({ build_obs_kpi_output(observed_indicator_sorts[1]) })
    output$obs_kpi_2 <- renderUI({ build_obs_kpi_output(observed_indicator_sorts[2]) })
    output$obs_kpi_3 <- renderUI({ build_obs_kpi_output(observed_indicator_sorts[3]) })
    output$obs_kpi_4 <- renderUI({ build_obs_kpi_output(observed_indicator_sorts[4]) })
    output$obs_kpi_5 <- renderUI({ build_obs_kpi_output(observed_indicator_sorts[5]) })
    output$obs_kpi_6 <- renderUI({ build_obs_kpi_output(observed_indicator_sorts[6]) })
    output$obs_kpi_7 <- renderUI({ build_obs_kpi_output(observed_indicator_sorts[7]) })

    # Indicator detail pages
    indicator_detail_server("entry_rate", view_to_indicator[["entry_rate"]], observed_national_data, state_code_rv, profile_rv)
    indicator_detail_server("maltreatment", view_to_indicator[["maltreatment"]], observed_national_data, state_code_rv, profile_rv)
    indicator_detail_server("recurrence", view_to_indicator[["recurrence"]], observed_national_data, state_code_rv, profile_rv)
    indicator_detail_server("perm12_entries", view_to_indicator[["perm12_entries"]], observed_national_data, state_code_rv, profile_rv)
    indicator_detail_server("perm12_12_23", view_to_indicator[["perm12_12_23"]], observed_national_data, state_code_rv, profile_rv)
    indicator_detail_server("perm12_24", view_to_indicator[["perm12_24"]], observed_national_data, state_code_rv, profile_rv)
    indicator_detail_server("reentry", view_to_indicator[["reentry"]], observed_national_data, state_code_rv, profile_rv)
    indicator_detail_server("placement", view_to_indicator[["placement"]], observed_national_data, state_code_rv, profile_rv)
  })
}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
