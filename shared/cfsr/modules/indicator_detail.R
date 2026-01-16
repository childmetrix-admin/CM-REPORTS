# indicator_detail.R - Simplified module for Observed Performance app indicator detail pages
# Shows ONLY national comparison bar chart (no KPI cards)

#####################################
# UI FUNCTION ----
#####################################

indicator_detail_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Add CSS for header styling
    tags$head(
      tags$style(HTML("
        .indicator-header {
          margin-bottom: 24px;
          padding-bottom: 0;
        }
        .indicator-header .indicator-title {
          font-size: 16px;
          font-weight: 700;
          color: #4472C4;
          margin: 0 0 12px 0;
          letter-spacing: -0.5px;
        }
        .indicator-header .indicator-subtitle {
          font-size: 16px;
          color: #6b7280;
          margin: 0 0 8px 0;
          line-height: 1.6;
          font-weight: 400;
        }
        .indicator-header .indicator-subtitle:last-child {
          margin-bottom: 0;
        }
      "))
    ),

    fluidRow(
      column(12,
        # Header
        div(class = "indicator-header",
          div(class = "indicator-title", textOutput(ns("title"))),
          htmlOutput(ns("description")),
          htmlOutput(ns("metadata")),
          div(style = "margin-top: 12px;", uiOutput(ns("target")))
        ),

        # Tabbed content
        tabsetPanel(
          id = ns("breakdown_tabs"),
          type = "tabs",

          # By State tab
          tabPanel(
            "By State",
            value = "state",
            div(style = "margin-top: 20px;",
              plotlyOutput(ns("chart"), height = "auto")
            )
          ),

          # By County tab (placeholder)
          tabPanel(
            "By County",
            value = "county",
            div(style = "margin-top: 20px; padding: 40px; text-align: center; color: #6b7280;",
              p(style = "font-size: 18px; margin-bottom: 10px;", "County-level data coming soon"),
              p(style = "font-size: 14px;", "This will show performance broken down by county within the state.")
            )
          ),

          # By Age tab (placeholder)
          tabPanel(
            "By Age",
            value = "age",
            div(style = "margin-top: 20px; padding: 40px; text-align: center; color: #6b7280;",
              p(style = "font-size: 18px; margin-bottom: 10px;", "Age breakdown coming soon"),
              p(style = "font-size: 14px;", "This will show performance broken down by age groups.")
            )
          ),

          # By Race & Ethnicity tab (placeholder)
          tabPanel(
            "By Race & Ethnicity",
            value = "race",
            div(style = "margin-top: 20px; padding: 40px; text-align: center; color: #6b7280;",
              p(style = "font-size: 18px; margin-bottom: 10px;", "Race & ethnicity breakdown coming soon"),
              p(style = "font-size: 14px;", "This will show performance broken down by race and ethnicity.")
            )
          )
        ),

        # Footnote (appears below all tabs)
        div(class = "chart-footnote", style = "margin-top: 20px;", textOutput(ns("source")))
      )
    )
  )
}

#####################################
# SERVER FUNCTION ----
#####################################

indicator_detail_server <- function(id, indicator_name, national_data, state_code) {
  moduleServer(id, function(input, output, session) {

    # Check if national_data is a reactive - if so, call it to get the data
    get_data <- function() {
      if (is.reactive(national_data)) {
        national_data()
      } else {
        national_data
      }
    }

    # Check if state_code is a reactive - if so, call it to get the value
    get_state <- function() {
      if (is.reactive(state_code)) {
        state_code()
      } else {
        state_code
      }
    }

    # Get indicator data (filter national data to this indicator)
    ind_data <- reactive({
      data <- get_data()
      selected_state_code <- get_state()

      # Convert state code to full name (national data uses full names like "Maryland")
      # state_codes is defined in global.R: c("MD" = "Maryland", ...)
      selected_state_name <- state_codes[selected_state_code]

      # Filter to specific indicator
      ind_df <- data %>%
        filter(indicator == indicator_name)

      if (nrow(ind_df) == 0) {
        return(NULL)
      }

      # Sort by state_rank (best to worst)
      # Descending order so rank 1 (best) appears at bottom (plotly will reverse)
      ind_df <- ind_df %>%
        arrange(desc(state_rank)) %>%
        mutate(rank = state_rank)

      # Add highlight flag for selected state
      # Compare to full state name (not code)
      ind_df <- ind_df %>%
        mutate(is_selected = (state == selected_state_name))

      return(ind_df)
    })

    # Title (indicator name — state name)
    output$title <- renderText({
      if (!is.null(ind_data())) {
        selected_state_code <- get_state()
        state_name <- state_codes[selected_state_code]
        paste(ind_data()$indicator[1], "—", state_name)
      } else {
        indicator_name
      }
    })

    # Description
    output$description <- renderUI({
      if (!is.null(ind_data())) {
        HTML(paste0('<div class="indicator-subtitle" style="font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif !important; font-size: 14px !important; color: #333 !important; font-weight: 400 !important; line-height: 1.6 !important; margin: 0 0 8px 0 !important;">',
                    ind_data()$description[1],
                    '</div>'))
      } else {
        HTML("")
      }
    })

    # Metadata (CFSR Round 4 Data Profile | profile_version | period)
    output$metadata <- renderUI({
      if (!is.null(ind_data())) {
        profile_ver <- ind_data()$profile_version[1]
        period <- ind_data()$period_meaningful[1]
        HTML(paste0('<div class="indicator-subtitle" style="font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif !important; font-size: 14px !important; color: #333 !important; font-weight: 400 !important; line-height: 1.6 !important; margin: 0 !important;">',
                    "CFSR Round 4 Data Profile | ", profile_ver, " | ", period,
                    '</div>'))
      } else {
        HTML("")
      }
    })

    # Target line (if applicable)
    output$target <- renderUI({
      if (!is.null(ind_data())) {
        data <- ind_data()
        has_target <- !is.na(data$national_standard[1]) &&
                      data$national_standard[1] != "" &&
                      data$national_standard[1] != "NA"

        if (has_target) {
          target <- data$national_standard[1]
          direction <- data$direction_rule[1]
          symbol <- if (direction == "lt") "<" else ">"

          # Get format suffix
          format_type <- data$format[1]
          scale <- data$scale[1]

          suffix <- if (format_type == "rate") {
            if (scale == 100000) {
              " per 100,000 days"
            } else if (scale == 1000) {
              " per 1,000 days"
            } else {
              ""
            }
          } else if (format_type == "percent") {
            "%"
          } else {
            ""
          }

          HTML(paste0(
            "<span style='color: #87D180;'>───</span> ",
            "National standard: ", symbol, " ", target, suffix
          ))
        } else {
          NULL
        }
      }
    })

    # Chart (national comparison bar chart)
    output$chart <- renderPlotly({
      req(ind_data())

      # Call build_indicator_chart() from chart_builder.R
      # Function signature: build_indicator_chart(ind_df, selected_state = NULL)
      # The function extracts format_type, direction_rule, decimals from the data
      build_indicator_chart(
        ind_df = ind_data(),
        selected_state = get_state()
      )
    })

    # Source footnote
    output$source <- renderText({
      if (!is.null(ind_data())) {
        paste("Source:", ind_data()$source[1])
      } else {
        ""
      }
    })
  })
}
