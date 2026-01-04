# indicator_detail.R - Simplified module for Observed Performance app indicator detail pages
# Shows ONLY national comparison bar chart (no KPI cards)

#####################################
# UI FUNCTION ----
#####################################

indicator_detail_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      column(12,
        # Chart title and metadata
        div(class = "chart-title", textOutput(ns("title"))),
        div(class = "chart-period", textOutput(ns("period"))),
        div(class = "chart-description", textOutput(ns("description"))),
        div(class = "chart-target", uiOutput(ns("target"))),

        # National comparison bar chart
        plotlyOutput(ns("chart"), height = "auto"),

        # Footnote
        div(class = "chart-footnote", textOutput(ns("source")))
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

    # Title
    output$title <- renderText({
      if (!is.null(ind_data())) {
        ind_data()$indicator[1]
      } else {
        indicator_name
      }
    })

    # Period
    output$period <- renderText({
      if (!is.null(ind_data())) {
        paste("Period:", ind_data()$period_meaningful[1])
      } else {
        ""
      }
    })

    # Description
    output$description <- renderText({
      if (!is.null(ind_data())) {
        ind_data()$description[1]
      } else {
        ""
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
