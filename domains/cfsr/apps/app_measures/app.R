# app.R - Consolidated Measures App
#
# Consolidates 3 CFSR apps: national (state comparisons), rsp (KPI cards), observed (KPI cards + details)
# Navigation is built into the app sidebar (no external HTML dependencies)

# Shiny sources app.R into a dedicated environment; objects from global.R may live only in
# .GlobalEnv and not be visible when building `ui`. Source global.R into THIS env first so
# indicator_detail_ui / server helpers exist (packages + modules are loaded inside global.R).
gf <- file.path(Sys.getenv("CM_REPORTS_ROOT", "/app"), "global.R")
if (file.exists(gf)) {
  sys.source(gf, envir = environment(), keep.source = FALSE)
} else {
  library(shiny)
  library(shinydashboard)
}

#####################################
# HELPER FUNCTIONS (APP-SPECIFIC) ----
#####################################

# Build RSP confidence interval chart
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

# Build observed performance trend chart
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

ui <- dashboardPage(
  skin = "blue",

  dashboardHeader(disable = TRUE),

  dashboardSidebar(
    width = 220,
    sidebarMenu(
      id = "sidebar_menu",

      menuItem("Overview", tabName = "overview", icon = icon("th")),
      menuItem("Entry rate", tabName = "obs_entry_rate", icon = NULL),
      menuItem("Maltreatment in care", tabName = "obs_maltreatment", icon = NULL),
      menuItem("Recurrence", tabName = "obs_recurrence", icon = NULL),
      menuItem("Perm 12mo - Entries", tabName = "obs_perm12_entries", icon = NULL),
      menuItem("Perm 12mo - 12-23mo", tabName = "obs_perm12_12_23", icon = NULL),
      menuItem("Perm 12mo - 24+mo", tabName = "obs_perm12_24", icon = NULL),
      menuItem("Reentry", tabName = "obs_reentry", icon = NULL),
      menuItem("Placement stability", tabName = "obs_placement", icon = NULL)
    )
  ),

  dashboardBody(
    tags$head(
      # html2canvas library for downloads
      tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"),

      # Download function for observed detail pages
      tags$script(HTML("
        function downloadViz(containerId, filename) {
          const element = document.getElementById(containerId);
          const button = element.querySelector('.cm-download-btn .btn');

          if (!element) {
            console.error('Container not found:', containerId);
            return;
          }

          if (button) {
            button.classList.add('btn-clicked');
            button.disabled = true;
          }

          element.classList.add('cm-exporting');

          html2canvas(element, {
            backgroundColor: '#ffffff',
            scale: 2,
            logging: false,
            useCORS: true
          }).then(canvas => {
            element.classList.remove('cm-exporting');

            const link = document.createElement('a');
            link.download = filename;
            link.href = canvas.toDataURL('image/png');
            link.click();

            if (button) {
              button.classList.remove('btn-clicked');
              button.disabled = false;
            }
          }).catch(error => {
            element.classList.remove('cm-exporting');
            if (button) {
              button.classList.remove('btn-clicked');
              button.disabled = false;
            }
            console.error('Screenshot failed:', error);
            alert('Failed to generate screenshot. Please try again.');
          });
        }
      ")),

      # Import ChildMetrix design system
      tags$link(rel = "stylesheet", type = "text/css",
                href = "cm-shared/css/design-tokens.css"),
      tags$link(rel = "stylesheet", type = "text/css",
                href = "cm-shared/css/components.css"),

      # App-specific CSS (sidebar, info popups, interpretation cards, export states)
      tags$style(HTML("
        /* ===== BASE STYLES ===== */
        body {
          background-color: var(--cm-bg-page);
          font-family: var(--cm-font-family);
          margin: 0;
          padding: 0;
        }

        /* ===== SHINYDASHBOARD SIDEBAR OVERRIDES ===== */
        .main-sidebar { background-color: var(--cm-bg-nav) !important; }
        .sidebar { background-color: var(--cm-bg-nav) !important; }
        .skin-blue .main-sidebar { background-color: var(--cm-bg-nav) !important; }

        /* Section headers */
        .sidebar-menu li.header {
          font-size: 13px !important;
          text-transform: uppercase;
          color: #ecf0f1 !important;
          font-weight: var(--cm-font-bold);
          padding: var(--cm-space-3) var(--cm-space-4) !important;
          letter-spacing: var(--cm-tracking-wide);
          background-color: rgba(52, 73, 94, 0.6) !important;
          margin: var(--cm-space-2) 0 var(--cm-space-1) 0 !important;
          cursor: default !important;
          pointer-events: none !important;
          user-select: none !important;
        }

        /* Sidebar menu items */
        .sidebar-menu > li > a {
          color: #bdc3c7 !important;
          background-color: transparent !important;
          padding: var(--cm-space-3) var(--cm-space-4) !important;
          text-decoration: none;
          border-left: 3px solid transparent;
          font-size: var(--cm-text-md);
          line-height: var(--cm-leading-normal);
        }
        .sidebar-menu > li > a:hover {
          color: #ffffff !important;
          background-color: rgba(52, 73, 94, 0.4) !important;
          text-decoration: none !important;
        }
        .sidebar-menu > li.active > a {
          color: #ffffff !important;
          background-color: rgba(52, 152, 219, 0.3) !important;
          font-weight: var(--cm-font-medium);
          border-left: 3px solid #3498db;
          text-decoration: none;
        }

        /* Content area background */
        .content-wrapper, .right-side {
          padding-top: var(--cm-space-3) !important;
          background-color: var(--cm-bg-page) !important;
        }
        .main-sidebar { padding-top: 0 !important; margin-top: 0 !important; }
        .sidebar { padding-top: var(--cm-space-3) !important; }

        /* ===== KPI CARD EXTENSIONS (app-specific) ===== */
        .kpi-status-indicator {
          position: absolute;
          top: var(--cm-space-3);
          right: var(--cm-space-3);
          width: 12px;
          height: 12px;
          border-radius: var(--cm-radius-full);
          flex-shrink: 0;
        }
        .kpi-status-indicator.better { background: var(--cm-status-better); }
        .kpi-status-indicator.worse { background: var(--cm-status-worse); }
        .kpi-status-indicator.nodiff { background: var(--cm-status-nodiff); }
        .kpi-status-indicator.dq { background: var(--cm-status-dq); }

        .kpi-metrics {
          display: flex;
          align-items: baseline;
          gap: 6px;
          margin-bottom: 6px;
        }
        .kpi-separator {
          font-size: 1.2rem;
          color: #d1d5db;
          margin: 0 4px;
        }
        .kpi-national-label {
          color: var(--cm-text-muted);
          font-size: 0.9rem;
        }
        .kpi-national-value {
          font-weight: var(--cm-font-bold);
          color: var(--cm-status-national);
          margin-left: 4px;
        }
        .kpi-direction {
          font-size: 0.7rem;
          color: var(--cm-text-muted);
          margin-bottom: var(--cm-space-2);
        }
        .kpi-chart-container {
          height: 110px;
          margin: var(--cm-space-2) -8px 0px -8px;
        }

        /* ===== INTERPRETATION CARD (RSP & OBSERVED) ===== */
        .interpretation-kpi {
          background: var(--cm-bg-card);
          border: 1px solid var(--cm-border);
          border-radius: var(--cm-radius-lg);
          padding: var(--cm-space-3);
          box-shadow: var(--cm-shadow-sm);
        }
        .interpretation-kpi .kpi-title {
          background: var(--cm-primary);
          color: white;
          margin: calc(-1 * var(--cm-space-3)) calc(-1 * var(--cm-space-3)) var(--cm-space-3) calc(-1 * var(--cm-space-3));
          padding: var(--cm-space-3);
          border-radius: var(--cm-radius-lg) var(--cm-radius-lg) 0 0;
          font-size: var(--cm-kpi-title-size);
          font-weight: var(--cm-font-semibold);
          line-height: var(--cm-leading-tight);
          display: flex;
          justify-content: space-between;
          align-items: center;
        }

        .interpretation-legend {
          display: grid;
          grid-template-columns: 1fr 1fr 1fr;
          gap: var(--cm-space-2);
          margin-bottom: var(--cm-space-3);
          padding-bottom: var(--cm-space-3);
          border-bottom: 1px solid var(--cm-border);
        }
        .interpretation-legend-item {
          display: flex;
          align-items: center;
          gap: var(--cm-space-2);
          font-size: 0.9rem;
          color: var(--cm-text-light);
          font-weight: var(--cm-font-medium);
          white-space: nowrap;
        }
        .interpretation-bar, .interpretation-point {
          width: 12px;
          height: 12px;
          border-radius: var(--cm-radius-full);
          flex-shrink: 0;
        }
        .interpretation-bar.better, .interpretation-point.better { background: var(--cm-status-better); }
        .interpretation-bar.worse, .interpretation-point.worse { background: var(--cm-status-worse); }
        .interpretation-bar.nodiff, .interpretation-point.nodiff { background: var(--cm-status-nodiff); }
        .interpretation-bar.dq, .interpretation-point.dq { background: var(--cm-status-dq); }
        .interpretation-bar.national, .interpretation-line.national {
          width: 20px;
          height: 0;
          background: none;
          border-bottom: 2px dashed var(--cm-status-national);
          border-radius: 0;
        }
        .interpretation-guide, .interpretation-notes {
          font-size: 0.95rem;
          color: var(--cm-text-light);
          line-height: var(--cm-leading-relaxed);
        }
        .interpretation-guide p, .interpretation-notes p {
          margin: 0 0 6px 0;
        }

        /* ===== INFO ICON POPUP ===== */
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
          background: var(--cm-bg-card);
          padding: 0;
          border-radius: var(--cm-radius-pill);
          box-shadow: 0 20px 60px rgba(0,0,0,0.3);
          max-width: 90vw;
          max-height: 90vh;
          overflow: hidden;
        }
        .info-popup img {
          display: block;
          background: var(--cm-bg-card);
          border-radius: var(--cm-radius-pill);
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

        /* ===== EXPORT BUTTON STATE ===== */
        .cm-download-btn .btn-clicked {
          background-color: #2c5aa0 !important;
          transform: scale(0.95);
        }

        /* ===== TAB CONTENT STANDARDIZATION ===== */
        /* Remove Bootstrap's default tab padding so we control it via .cm-tab-content */
        .tab-content {
          padding: 0 !important;
        }
        .tab-pane {
          padding: 0 !important;
        }

        /* .cm-tab-content padding - Overview page has correct amount now */
        .cm-tab-content {
          padding-left: 15px !important;
          padding-right: 15px !important;
          margin-top: var(--cm-space-5) !important;
        }

        /* Remove viz-container padding when inside tab content to prevent double-padding */
        .cm-tab-content .cm-viz-container {
          padding: 0 !important;
          margin-bottom: 0 !important;
        }
      "))
    ),

    tabItems(
      # Overview tab (contains both RSP and Observed Performance as sub-tabs)
      tabItem(
        tabName = "overview",
        fluidRow(
          column(12,
            # White container box (like indicator pages)
            div(class = "cm-page-container",
              # Title
              div(
                class = "cm-indicator-header",
                div(
                  class = "cm-page-title",
                  textOutput("overview_title", inline = TRUE)
                )
              ),

              # Tabset with transparent tabs
              tabsetPanel(
                id = "overview_tabs",
                type = "tabs",

                tabPanel(
                  "Risk Standardized Performance",
                  div(class = "cm-tab-content", uiOutput("rsp_content"))
                ),

                tabPanel(
                  "Observed Performance",
                  div(class = "cm-tab-content", uiOutput("obs_overview_content"))
                )
              )
            )
          )
        )
      ),

      # Observed indicator detail tabs
      tabItem(tabName = "obs_entry_rate", indicator_detail_ui("entry_rate")),
      tabItem(tabName = "obs_maltreatment", indicator_detail_ui("maltreatment")),
      tabItem(tabName = "obs_recurrence", indicator_detail_ui("recurrence")),
      tabItem(tabName = "obs_perm12_entries", indicator_detail_ui("perm12_entries")),
      tabItem(tabName = "obs_perm12_12_23", indicator_detail_ui("perm12_12_23")),
      tabItem(tabName = "obs_perm12_24", indicator_detail_ui("perm12_24")),
      tabItem(tabName = "obs_reentry", indicator_detail_ui("reentry")),
      tabItem(tabName = "obs_placement", indicator_detail_ui("placement"))
    )
  )
)

#####################################
# SERVER ----
#####################################

server <- function(input, output, session) {

  #####################################
  # URL PARAMETER DETECTION ----
  #####################################

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

  # Get state name from code
  state_name_rv <- reactive({
    state_codes[[state_code_rv()]]
  })

  #####################################
  # LAZY DATA LOADING ----
  #####################################

  # RSP data
  rsp_data <- reactive({
    state <- state_code_rv()
    profile <- profile_rv()
    tryCatch({
      load_rsp_data(state, profile)
    }, error = function(e) {
      NULL
    })
  })

  # Observed data (for KPI overview)
  observed_data <- reactive({
    load_cfsr_data(state_code_rv(), profile_rv(), type = "observed")
  })

  # National data (for indicator detail pages)
  observed_national_data <- reactive({
    data <- load_cfsr_data(state_code_rv(), profile_rv(), type = "national")
    # Filter to most recent period per indicator for bar charts
    data %>%
      group_by(indicator) %>%
      filter(period == max(period, na.rm = TRUE)) %>%
      ungroup()
  })

  #####################################
  # OVERVIEW PAGE TITLE ----
  #####################################

  output$overview_title <- renderText({
    paste("CFSR Performance Trends —", state_name_rv())
  })

  #####################################
  # RSP VIEW (KPI CARDS) ----
  #####################################

  output$rsp_content <- renderUI({
    data <- rsp_data()

    tagList(
      div(
        id = "viz-container-rsp-overview",
        style = "position: relative;",

        # Download button (top-right corner)
        div(
          class = "cm-download-btn",
          actionButton(
            "download_rsp_overview",
            "Download",
            icon = icon("download"),
            onclick = "downloadViz('viz-container-rsp-overview', 'cfsr_rsp_overview.png')"
          )
        ),

        div(class = "cm-context-header",
        div(class = "cm-section-title", "Risk-Standardized Performance — CFSR Statewide Data Indicators"),
        div(class = "cm-section-description",
          "RSP is the state's observed performance, with risk-adjustment"
        ),
        div(class = "cm-pills-row",
          if (is.null(data) || nrow(data) == 0) {
            div(class = "cm-pill cm-pill--period", "No data available")
          } else {
            profile_ver <- unique(data$profile_version)[1]
            tagList(
              div(class = "cm-pill cm-pill--period", paste0("CFSR Round 4 Data Profile | ", profile_ver)),
              div(class = "cm-pill cm-pill--state", state_name_rv())
            )
          }
        )
      ),

      # Row 1: Interpretation + Safety
      div(class = "cm-kpi-grid",
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
      div(class = "cm-kpi-grid",
        uiOutput("rsp_kpi_3"),
        uiOutput("rsp_kpi_4"),
        uiOutput("rsp_kpi_5")
      ),

      # Row 3: Reentry + Placement
      div(class = "cm-kpi-grid",
        uiOutput("rsp_kpi_6"),
        uiOutput("rsp_kpi_7")
      )
      ) # Close viz-container-rsp-overview wrapper
    )
  })

  # Build RSP KPI cards
  build_rsp_kpi_output <- function(indicator_sort_val) {
    data <- rsp_data()
    if (is.null(data) || nrow(data) == 0) {
      return(div(class = "cm-kpi-card", p("No data available")))
    }

    ind_data <- data %>% filter(indicator_sort == indicator_sort_val)
    if (nrow(ind_data) == 0) {
      return(div(class = "cm-kpi-card", p("No data for this indicator")))
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

    div(class = "cm-kpi-card",
      div(class = paste("kpi-status-indicator", status_val)),
      div(class = "cm-kpi-title", ind_short),
      div(class = "cm-kpi-subtitle", ind_desc),
      div(class = "kpi-metrics",
        span(class = "cm-kpi-value", style = paste0("color: ", value_color), display_val),
        span(class = "cm-kpi-unit", unit_label),
        span(class = "kpi-separator", "|"),
        span(class = "kpi-national-value", national_display),
        span(class = "cm-kpi-unit", national_unit),
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

  #####################################
  # OBSERVED OVERVIEW (KPI CARDS) ----
  #####################################

  output$obs_overview_content <- renderUI({
    data <- observed_data()

    profile_version <- if (is.null(data) || nrow(data) == 0) {
      "Unknown"
    } else {
      unique(data$profile_version)[1]
    }

    tagList(
      div(
        id = "viz-container-observed-overview",
        style = "position: relative;",

        # Download button (top-right corner)
        div(
          class = "cm-download-btn",
          actionButton(
            "download_observed_overview",
            "Download",
            icon = icon("download"),
            onclick = "downloadViz('viz-container-observed-overview', 'cfsr_observed_overview.png')"
          )
        ),

        div(class = "cm-context-header",
        div(class = "cm-section-title", "Observed Performance — CFSR Statewide Data Indicators"),
        div(class = "cm-section-description",
          "Observed performance is the state's performance, without risk-adjustment"
        ),
        div(class = "cm-pills-row",
          div(class = "cm-pill cm-pill--period", paste0("CFSR Round 4 Data Profile | ", profile_version)),
          div(class = "cm-pill cm-pill--state", state_name_rv())
        )
      ),

      div(class = "cm-kpi-grid",
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

      div(class = "cm-kpi-grid",
        uiOutput("obs_kpi_3"),
        uiOutput("obs_kpi_4"),
        uiOutput("obs_kpi_5")
      ),

      div(class = "cm-kpi-grid",
        uiOutput("obs_kpi_6"),
        uiOutput("obs_kpi_7"),
        div()
      )
      ) # Close viz-container-observed-overview wrapper
    )
  })

  # Build observed KPI cards
  build_obs_kpi_output <- function(indicator_sort_val) {
    data <- observed_data()
    if (is.null(data) || nrow(data) == 0) {
      return(div(class = "cm-kpi-card", p("No data available")))
    }

    ind_data <- data %>% filter(indicator_sort == indicator_sort_val)
    if (nrow(ind_data) == 0) {
      return(div(class = "cm-kpi-card", p("No data for this indicator")))
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

    div(class = "cm-kpi-card",
      div(class = paste("kpi-status-indicator", status_val)),
      div(class = "cm-kpi-title", ind_short),
      div(class = "cm-kpi-subtitle", ind_desc),
      div(class = "kpi-metrics",
        span(class = "cm-kpi-value", style = paste0("color: ", value_color), display_val),
        span(class = "cm-kpi-unit", unit_label),
        span(class = "kpi-separator", "|"),
        span(class = "kpi-national-value", national_display),
        span(class = "cm-kpi-unit", national_unit),
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

  #####################################
  # OBSERVED INDICATOR DETAIL PAGES ----
  #####################################

  indicator_detail_server("entry_rate", view_to_indicator[["entry_rate"]], observed_national_data, state_code_rv, profile_rv, state_codes)
  indicator_detail_server("maltreatment", view_to_indicator[["maltreatment"]], observed_national_data, state_code_rv, profile_rv, state_codes)
  indicator_detail_server("recurrence", view_to_indicator[["recurrence"]], observed_national_data, state_code_rv, profile_rv, state_codes)
  indicator_detail_server("perm12_entries", view_to_indicator[["perm12_entries"]], observed_national_data, state_code_rv, profile_rv, state_codes)
  indicator_detail_server("perm12_12_23", view_to_indicator[["perm12_12_23"]], observed_national_data, state_code_rv, profile_rv, state_codes)
  indicator_detail_server("perm12_24", view_to_indicator[["perm12_24"]], observed_national_data, state_code_rv, profile_rv, state_codes)
  indicator_detail_server("reentry", view_to_indicator[["reentry"]], observed_national_data, state_code_rv, profile_rv, state_codes)
  indicator_detail_server("placement", view_to_indicator[["placement"]], observed_national_data, state_code_rv, profile_rv, state_codes)
}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
