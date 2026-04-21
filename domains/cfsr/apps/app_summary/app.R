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
        const button = element.querySelector('.cm-download-btn .btn');

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

    # Import ChildMetrix design system
    tags$link(
      rel = "stylesheet",
      type = "text/css",
      href = "cm-shared/css/design-tokens.css"
    ),
    tags$link(
      rel = "stylesheet",
      type = "text/css",
      href = "cm-shared/css/components.css"
    ),

    # App-specific CSS (indicator table grid layout)
    tags$style(HTML("
      body {
        font-family: var(--cm-font-family);
        background-color: var(--cm-bg-page);
        margin: 0;
        padding: 0;
      }
      .container-fluid {
        padding: var(--cm-space-6);
        max-width: 1200px;
        margin-left: 0;
        margin-right: auto;
      }

      /* Indicator table grid - unique 6-column layout */
      .indicator-table {
        margin: var(--cm-space-2) 0 0 0;
      }
      .indicator-header {
        display: grid;
        grid-template-columns: 2fr 1fr 1fr 140px 80px 120px;
        gap: var(--cm-space-3);
        padding: var(--cm-space-2) 0;
        font-size: var(--cm-text-base);
        font-weight: var(--cm-font-semibold);
        color: var(--cm-text-muted);
        border-bottom: 2px solid var(--cm-border);
        margin-bottom: var(--cm-space-2);
      }
      .indicator-list {
        list-style: none;
        padding: 0;
        margin: 0;
      }
      .indicator-row {
        display: grid;
        grid-template-columns: 2fr 1fr 1fr 140px 80px 120px;
        gap: var(--cm-space-3);
        padding: var(--cm-space-2) 0;
        font-size: var(--cm-text-lg);
        color: var(--cm-text-light);
        line-height: var(--cm-leading-normal);
        border-bottom: 1px solid var(--cm-border-light);
        align-items: center;
      }
      .indicator-row:last-child {
        border-bottom: none;
      }
      .indicator-name {
        font-weight: var(--cm-font-medium);
      }
      .indicator-value {
        font-weight: var(--cm-font-semibold);
      }
      .national-standard {
        font-weight: var(--cm-font-semibold);
      }
      .period-value {
        font-size: var(--cm-text-base);
        color: var(--cm-text-light);
      }

      /* Hide download button during export */
      .cm-summary-card.exporting .cm-download-btn {
        display: none;
      }

      /* Responsive */
      @media (max-width: 768px) {
        .container-fluid {
          padding: var(--cm-space-4);
        }
      }

      /* PPT / webshot export (?export=true) */
      body.export-mode .container-fluid {
        max-width: 800px;
        margin-left: auto;
        margin-right: auto;
      }
      body.export-mode .cm-source,
      body.export-mode .cm-footnote {
        white-space: normal !important;
        word-wrap: break-word;
        overflow-wrap: anywhere;
      }
      body.export-mode .cm-download-btn {
        display: none !important;
      }
    ")),
    tags$script(HTML("
      (function() {
        try {
          var params = new URLSearchParams(window.location.search);
          if (params.get('export') === 'true') {
            document.body.classList.add('export-mode');
          }
        } catch (e) { /* ignore */ }
      })();
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

      span(class = paste("cm-pill cm-pill--status cm-pill--", status_val, sep = ""), pill_text)
    }

    # Helper function to format rank
    format_rank <- function(ind_data) {
      if (!is.null(ind_data$state_rank) && !is.null(ind_data$reporting_states) &&
          !is.na(ind_data$state_rank) && !is.na(ind_data$reporting_states)) {
        span(class = "cm-pill cm-pill--rank",
          paste0(ind_data$state_rank, " of ", ind_data$reporting_states)
        )
      } else {
        span("—")
      }
    }

    # Build single consolidated table with header
    div(
      id = "summary-container",
      class = "cm-summary-card",

      # Download button
      div(class = "cm-download-btn",
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
      div(class = "cm-header-divider",
        div(class = "cm-page-title cm-mb-2",
          paste("CFSR Performance Summary —", state_name_rv())
        ),
        div(class = "cm-page-subtitle cm-mt-0",
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
      div(class = "cm-source",
        paste0("Source: ", data$source[1])
      ),

      # Explanatory footnotes
      div(class = "cm-footnote",
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
