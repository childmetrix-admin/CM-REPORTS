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
    # html2canvas library for client-side screenshot/download
    tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"),

    # Download visualization function
    tags$script(HTML("
      function downloadSummary(containerId, filename) {
        const element = document.getElementById(containerId);
        const button = element.querySelector('.summary-download-button .btn');

        if (!button) return;

        const originalText = button.innerHTML;
        button.innerHTML = '<i class=\"fa fa-spinner fa-spin\"></i> Capturing...';
        button.disabled = true;

        // Hide button only during screenshot capture
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
    ")),

    tags$style(HTML("
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background-color: #f9fafb;
        margin: 0;
        padding: 0;
      }
      .container-fluid {
        padding: 24px;
        max-width: 1200px;
        margin-left: 0;
        margin-right: auto;
      }

      /* Header (now inside card) */
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

      /* Summary table card */
      .summary-card {
        position: relative;
        background: white;
        padding: 20px 24px;
        border-radius: 8px;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        margin-bottom: 20px;
      }

      /* Download button */
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

      /* Status pill badges */
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

      /* Rank pill badge */
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

      /* Table footnote */
      .table-footnote {
        margin-top: 12px;
        font-size: 11px;
        color: #6b7280;
        font-style: italic;
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

  # Status sections (includes title/subtitle inside for download capture)
  uiOutput("status_sections")
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
    if (is.na(ind_data$performance)) {
      return(list(value = "DQ", unit = "", national = national))
    }

    # Format observed performance value
    if (ind_data$format == "percent") {
      value <- sprintf(format_str, ind_data$performance * 100)
      unit <- "%"
    } else {
      value <- sprintf(format_str, ind_data$performance)
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

  # Status sections - consolidated table
  output$status_sections <- renderUI({
    req(latest_data())
    data <- latest_data() %>%
      arrange(indicator_sort)

    # Helper function to create status pill
    status_pill <- function(status_val) {
      pill_text <- case_when(
        status_val == "better" ~ "Better",
        status_val == "worse" ~ "Worse",
        status_val == "nodiff" ~ "No Difference",
        TRUE ~ "Data Quality"
      )

      span(class = paste("status-pill", status_val), pill_text)
    }

    # Helper function to format rank
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

    # Build single consolidated table with header
    div(
      id = "summary-container",
      class = "summary-card",

      # Download button
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

      # Header (title and subtitle inside container for download capture)
      div(class = "summary-header",
        div(class = "summary-title",
          paste("CFSR Performance Summary —", state_name_rv())
        ),
        div(class = "summary-subtitle",
          paste0("CFSR Round 4 Data Profile | ", data$profile_version[1])
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
          lapply(1:nrow(data), function(i) {
            ind <- data[i, ]
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

      # Source footnote (from data)
      div(class = "summary-source",
        paste0("Source: ", data$source[1])
      ),

      # Explanatory footnotes
      div(class = "table-footnote",
        div("* Based on the state's risk-standardized performance, which is its observed performance after risk-adjustment."),
        div("** Based on the state's observed performance among states whose performance could be calculated.")
      )
    )
  })
}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
