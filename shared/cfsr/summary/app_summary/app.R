# app.R - CFSR Performance Summary (Executive Brief)
# Narrative summary showing high-level performance status for leadership

# Load global functions and libraries
source("global.R", local = TRUE)

#####################################
# UI ----
#####################################

ui <- fluidPage(
  # Custom CSS
  tags$head(
    tags$style(HTML("
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background-color: #f9fafb;
        margin: 0;
        padding: 0;
      }
      .container-fluid {
        padding: 24px;
        max-width: 1400px;
        margin-left: 0;
        margin-right: auto;
      }

      /* Header */
      .summary-header {
        margin-bottom: 32px;
        padding-bottom: 16px;
        border-bottom: 2px solid #e5e7eb;
      }
      .summary-title {
        font-size: 16px;
        font-weight: 700;
        color: #4472C4;
        margin: 0 0 12px 0;
        letter-spacing: -0.5px;
      }
      .summary-subtitle {
        font-size: 16px;
        color: #6b7280;
        margin: 0;
        line-height: 1.6;
        font-weight: 400;
      }

      /* Card grid */
      .card-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 16px;
        margin-bottom: 20px;
      }

      /* Status card */
      .status-card {
        background: white;
        padding: 20px 24px;
        border-radius: 8px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        border-left: 4px solid #e5e7eb;
        min-height: 200px;
      }
      .status-card.better {
        border-left-color: #16a34a;
      }
      .status-card.worse {
        border-left-color: #dc2626;
      }
      .status-card.nodiff {
        border-left-color: #6b7280;
      }
      .status-card.dq {
        border-left-color: #f59e0b;
      }

      .status-header {
        display: flex;
        align-items: center;
        margin-bottom: 12px;
      }
      .status-icon {
        font-size: 20px;
        margin-right: 10px;
        flex-shrink: 0;
      }
      .status-title {
        font-size: 18px;
        font-weight: 600;
        color: #1f2937;
        margin: 0;
      }
      .status-count {
        font-size: 16px;
        font-weight: 700;
        margin-left: 8px;
        padding: 2px 10px;
        border-radius: 12px;
        display: inline-block;
      }
      .status-count.better {
        color: #16a34a;
        background-color: #dcfce7;
      }
      .status-count.worse {
        color: #dc2626;
        background-color: #fee2e2;
      }
      .status-count.nodiff {
        color: #6b7280;
        background-color: #f3f4f6;
      }
      .status-count.dq {
        color: #f59e0b;
        background-color: #fef3c7;
      }

      .indicator-table {
        margin: 8px 0 0 0;
      }
      .indicator-header {
        display: grid;
        grid-template-columns: 2fr 1fr 1fr;
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
        grid-template-columns: 2fr 1fr 1fr;
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
        margin-left: 4px;
      }
      .indicator-value.better {
        color: #16a34a;
      }
      .indicator-value.worse {
        color: #dc2626;
      }
      .indicator-value.nodiff {
        color: #6b7280;
      }
      .indicator-value.dq {
        color: #f59e0b;
      }

      .national-standard {
        color: #3b82f6;
        font-weight: 600;
      }

      .empty-message {
        font-size: 14px;
        color: #9ca3af;
        font-style: italic;
        margin-left: 8px;
      }

      /* Footer */
      .footer-note {
        margin-top: 24px;
        padding: 16px 20px;
        background: white;
        border-radius: 8px;
        font-size: 13px;
        color: #6b7280;
        text-align: center;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      }

      /* Responsive */
      @media (max-width: 768px) {
        .container-fluid {
          padding: 16px;
        }
        .summary-title {
          font-size: 24px;
        }
        .summary-subtitle {
          font-size: 14px;
        }
        .status-title {
          font-size: 16px;
        }
        .card-grid {
          grid-template-columns: 1fr;
        }
      }
    "))
  ),

  # Header
  div(class = "summary-header",
    h1(class = "summary-title", textOutput("title")),
    p(class = "summary-subtitle", uiOutput("subtitle"))
  ),

  # Status sections
  uiOutput("status_sections"),

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

  # Load observed data (contains status column for better/worse/nodiff/dq)
  observed_data <- reactive({
    state <- state_code_rv()
    profile <- profile_rv()

    tryCatch({
      load_observed_data(state, profile)
    }, error = function(e) {
      NULL
    })
  })

  # Get latest period data for each indicator
  latest_data <- reactive({
    req(observed_data())
    data <- observed_data()

    # Get most recent period FOR EACH indicator (not global latest)
    data %>%
      group_by(indicator_sort) %>%
      arrange(desc(period)) %>%
      slice(1) %>%
      ungroup()
  })

  # Title
  output$title <- renderText({
    paste("CFSR Performance Summary —", state_name_rv())
  })

  # Subtitle
  output$subtitle <- renderUI({
    data <- observed_data()
    if (!is.null(data) && nrow(data) > 0) {
      profile_ver <- unique(data$profile_version)[1]
      state_name <- state_name_rv()
      tags$span(
        "According to the ", tags$strong(profile_ver),
        " CFSR Data Profile, ", state_name, "'s most recent performance was:"
      )
    } else {
      tags$span("Loading...")
    }
  })

  # Helper function to format indicator value
  format_indicator_value <- function(ind_data) {
    # Get decimal precision from data (default to 1 if not available)
    precision <- if (!is.null(ind_data$decimal_precision) && !is.na(ind_data$decimal_precision)) {
      ind_data$decimal_precision
    } else {
      1
    }

    # Format national standard (always available, even for DQ)
    format_str <- paste0("%.", precision, "f")
    if (ind_data$format == "percent") {
      # Format national standard (already in percentage format)
      if (!is.na(ind_data$national_standard)) {
        national <- paste0(" (", sprintf(format_str, as.numeric(ind_data$national_standard)), "%)")
      } else {
        national <- ""
      }
    } else {
      # Format national standard (already in display format)
      if (!is.na(ind_data$national_standard)) {
        national <- paste0(" (", sprintf(format_str, as.numeric(ind_data$national_standard)), ")")
      } else {
        national <- ""
      }
    }

    # If observed performance is NA, return DQ for value but keep national standard
    if (is.na(ind_data$observed_performance)) {
      return(list(value = "DQ", unit = "", national = national))
    }

    # Format observed performance value
    if (ind_data$format == "percent") {
      value <- sprintf(format_str, ind_data$observed_performance * 100)
      unit <- "%"
    } else {
      value <- sprintf(format_str, ind_data$observed_performance)
      # Determine unit based on indicator
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

  # Status sections
  output$status_sections <- renderUI({
    req(latest_data())
    data <- latest_data()

    # Group by status (keep full data frames)
    better_indicators <- data %>%
      filter(status == "better") %>%
      arrange(indicator_sort)

    worse_indicators <- data %>%
      filter(status == "worse") %>%
      arrange(indicator_sort)

    nodiff_indicators <- data %>%
      filter(status == "nodiff") %>%
      arrange(indicator_sort)

    dq_indicators <- data %>%
      filter(is.na(observed_performance) | status == "dq") %>%
      arrange(indicator_sort)

    # Build card grid
    div(class = "card-grid",
      # Better card
      div(class = "status-card better",
        div(class = "status-header",
          span(class = "status-icon", "\u2713"),  # ✓ checkmark
          h2(class = "status-title", "Better than national standard"),
          span(class = paste("status-count better"), nrow(better_indicators))
        ),
        if (nrow(better_indicators) > 0) {
          div(class = "indicator-table",
            div(class = "indicator-header",
              span("Indicator"),
              span("State's Performance"),
              span("National Performance")
            ),
            tags$ul(class = "indicator-list",
              lapply(1:nrow(better_indicators), function(i) {
                ind <- better_indicators[i, ]
                formatted <- format_indicator_value(ind)
                tags$li(class = "indicator-row",
                  span(class = "indicator-name", ind$indicator_short),
                  span(class = "indicator-value better",
                    paste0(formatted$value, formatted$unit)
                  ),
                  span(class = "national-standard",
                    gsub("^\\s*\\(|\\)$", "", formatted$national)
                  )
                )
              })
            )
          )
        } else {
          div(class = "empty-message", "None")
        }
      ),

      # Worse card
      div(class = "status-card worse",
        div(class = "status-header",
          span(class = "status-icon", "\u2717"),  # ✗ x mark
          h2(class = "status-title", "Worse than national standard"),
          span(class = paste("status-count worse"), nrow(worse_indicators))
        ),
        if (nrow(worse_indicators) > 0) {
          div(class = "indicator-table",
            div(class = "indicator-header",
              span("Indicator"),
              span("State's Performance"),
              span("National Performance")
            ),
            tags$ul(class = "indicator-list",
              lapply(1:nrow(worse_indicators), function(i) {
                ind <- worse_indicators[i, ]
                formatted <- format_indicator_value(ind)
                tags$li(class = "indicator-row",
                  span(class = "indicator-name", ind$indicator_short),
                  span(class = "indicator-value worse",
                    paste0(formatted$value, formatted$unit)
                  ),
                  span(class = "national-standard",
                    gsub("^\\s*\\(|\\)$", "", formatted$national)
                  )
                )
              })
            )
          )
        } else {
          div(class = "empty-message", "None")
        }
      ),

      # No difference card
      div(class = "status-card nodiff",
        div(class = "status-header",
          span(class = "status-icon", "\u2014"),  # — dash
          h2(class = "status-title", "No statistical difference from national standard"),
          span(class = paste("status-count nodiff"), nrow(nodiff_indicators))
        ),
        if (nrow(nodiff_indicators) > 0) {
          div(class = "indicator-table",
            div(class = "indicator-header",
              span("Indicator"),
              span("State's Performance"),
              span("National Performance")
            ),
            tags$ul(class = "indicator-list",
              lapply(1:nrow(nodiff_indicators), function(i) {
                ind <- nodiff_indicators[i, ]
                formatted <- format_indicator_value(ind)
                tags$li(class = "indicator-row",
                  span(class = "indicator-name", ind$indicator_short),
                  span(class = "indicator-value nodiff",
                    paste0(formatted$value, formatted$unit)
                  ),
                  span(class = "national-standard",
                    gsub("^\\s*\\(|\\)$", "", formatted$national)
                  )
                )
              })
            )
          )
        } else {
          div(class = "empty-message", "None")
        }
      ),

      # Data quality card
      div(class = "status-card dq",
        div(class = "status-header",
          span(class = "status-icon", "\u26A0"),  # ⚠ warning
          h2(class = "status-title", "Unable to calculate (data quality issues)"),
          span(class = paste("status-count dq"), nrow(dq_indicators))
        ),
        if (nrow(dq_indicators) > 0) {
          div(class = "indicator-table",
            div(class = "indicator-header",
              span("Indicator"),
              span("State's Performance"),
              span("National Performance")
            ),
            tags$ul(class = "indicator-list",
              lapply(1:nrow(dq_indicators), function(i) {
                ind <- dq_indicators[i, ]
                formatted <- format_indicator_value(ind)
                tags$li(class = "indicator-row",
                  span(class = "indicator-name", ind$indicator_short),
                  span(class = "indicator-value dq",
                    paste0(formatted$value, formatted$unit)
                  ),
                  span(class = "national-standard",
                    gsub("^\\s*\\(|\\)$", "", formatted$national)
                  )
                )
              })
            )
          )
        } else {
          div(class = "empty-message", "None")
        }
      )
    )
  })

  # Footer
  output$footer_text <- renderText({
    "Based on CFSR Round 4 Data Profile | Risk-Standardized Performance comparison"
  })
}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
