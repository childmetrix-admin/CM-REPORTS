# indicator_page.R - Reusable Shiny module for indicator detail pages

#####################################
# UI FUNCTION ----
#####################################

indicator_page_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      column(12,
        box(
          width = 12,
          # Chart title and metadata
          div(class = "chart-title", textOutput(ns("title"))),
          div(class = "chart-period", textOutput(ns("period"))),
          div(class = "chart-description",
            textOutput(ns("description"), inline = TRUE),
            tags$span(" "),
            actionLink(ns("show_details"),
                      tagList(icon("info-circle"), " Measure details."),
                      style = "font-size: 13px; margin-left: 5px;")
          ),
          div(class = "chart-target", uiOutput(ns("target"))),

          # Chart
          plotlyOutput(ns("chart"), height = "auto"),

          # Footnote
          div(class = "chart-footnote", textOutput(ns("source")))
        )
      )
    ),

    # Navigation Buttons
    fluidRow(
      column(12,
        div(style = "margin-top: 10px; margin-bottom: 10px;",
          uiOutput(ns("nav_buttons"))
        )
      )
    ),

    fluidRow(
      column(12,
        # Collapsible Data Table
        box(
          width = 12,
          title = "View Data Table",
          collapsible = TRUE,
          collapsed = TRUE,
          status = "primary",
          solidHeader = TRUE,
          fluidRow(
            column(12,
              downloadButton(ns("download_csv"), "Download CSV", style = "margin-bottom: 10px;"),
              DTOutput(ns("table"))
            )
          )
        )
      )
    )
  )
}

#####################################
# SERVER FUNCTION ----
#####################################

indicator_page_server <- function(id, indicator_name, app_data, selected_state, profile_version) {
  moduleServer(id, function(input, output, session) {

    # Get indicator data
    ind_data <- reactive({
      get_indicator_data(app_data, indicator_name, selected_state())
    })

    # Get navigation info
    nav_info <- get_indicator_navigation(indicator_name, app_data)

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

          # Get format suffix (e.g., "per 100,000 days", "%")
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

    # Chart
    output$chart <- renderPlotly({
      req(ind_data())
      build_indicator_chart(ind_data(), selected_state())
    })

    # Source footnote
    output$source <- renderText({
      if (!is.null(ind_data())) {
        paste("Source:", ind_data()$source[1])
      } else {
        ""
      }
    })

    # Show measure details modal when link is clicked
    observeEvent(input$show_details, {
      tryCatch({
        if (!is.null(ind_data())) {
          data <- ind_data()[1, ]  # Get first row for metadata

          # Safe getter function to handle NA/NULL values
          safe_get <- function(value) {
            if (is.null(value) || is.na(value) || value == "") {
              return("Not available")
            }
            return(as.character(value))
          }

        # Get national standard with suffix
        nat_std_display <- if (!is.null(data$national_standard) &&
                               !is.na(data$national_standard) &&
                               data$national_standard != "") {
          format_type <- safe_get(data$format)
          scale <- if (!is.null(data$scale) && !is.na(data$scale)) data$scale else 1

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

          paste0(data$national_standard, suffix)
        } else {
          "Not applicable"
        }

        # Build the details content
        details_content <- tagList(
          tags$table(
            style = "width: 100%; border-collapse: collapse;",
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold; width: 25%;", "Category:"),
              tags$td(style = "padding: 8px;", safe_get(data$category))
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold;", "National Standard:"),
              tags$td(style = "padding: 8px;", nat_std_display)
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold;", "Desired Direction:"),
              tags$td(style = "padding: 8px;", safe_get(data$direction_legend))
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold; vertical-align: top;", "Description:"),
              tags$td(style = "padding: 8px;", safe_get(data$description))
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold; vertical-align: top;", "Denominator:"),
              tags$td(style = "padding: 8px;", safe_get(data$denominator_def))
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold; vertical-align: top;", "Numerator:"),
              tags$td(style = "padding: 8px;", safe_get(data$numerator_def))
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold; vertical-align: top;", "Risk Adjustment:"),
              tags$td(style = "padding: 8px;",
                if (!is.null(data$risk_adjustment) && !is.na(data$risk_adjustment) && data$risk_adjustment != "") {
                  as.character(data$risk_adjustment)
                } else {
                  "None"
                }
              )
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold; vertical-align: top;", "Exclusions:"),
              tags$td(style = "padding: 8px;",
                if (!is.null(data$exclusions) && !is.na(data$exclusions) && data$exclusions != "") {
                  as.character(data$exclusions)
                } else {
                  "None"
                }
              )
            ),
            tags$tr(
              tags$td(style = "padding: 8px; font-weight: bold; vertical-align: top;", "Notes:"),
              tags$td(style = "padding: 8px;",
                if (!is.null(data$notes) && !is.na(data$notes) && data$notes != "") {
                  as.character(data$notes)
                } else {
                  "None"
                }
              )
            )
          )
        )

          showModal(modalDialog(
            title = safe_get(data$indicator),
            details_content,
            size = "l",
            easyClose = TRUE,
            footer = modalButton("Close")
          ))
        }
      }, error = function(e) {
        # Show error in modal instead of crashing
        showModal(modalDialog(
          title = "Error Loading Measure Details",
          paste("An error occurred:", e$message),
          size = "m",
          easyClose = TRUE,
          footer = modalButton("Close")
        ))
      })
    })

    # Navigation buttons
    output$nav_buttons <- renderUI({
      btn_style <- "margin: 5px; padding: 10px 20px; font-size: 14px;"

      buttons <- list()

      # Previous button
      if (!is.null(nav_info$prev_tab)) {
        buttons <- c(buttons, list(
          actionLink(
            session$ns("prev_btn"),
            label = tagList(icon("arrow-left"), paste(" Previous:", nav_info$prev_label)),
            style = btn_style,
            onclick = sprintf("$('.sidebar-menu a[data-value=\"%s\"]').click();", nav_info$prev_tab)
          )
        ))
      }

      # Spacer if both buttons exist
      if (!is.null(nav_info$prev_tab) && !is.null(nav_info$next_tab)) {
        buttons <- c(buttons, list(
          span(style = "margin: 0 15px;", "")
        ))
      }

      # Next button
      if (!is.null(nav_info$next_tab)) {
        buttons <- c(buttons, list(
          actionLink(
            session$ns("next_btn"),
            label = tagList(paste("Next:", nav_info$next_label), " ", icon("arrow-right")),
            style = btn_style,
            onclick = sprintf("$('.sidebar-menu a[data-value=\"%s\"]').click();", nav_info$next_tab)
          )
        ))
      }

      if (length(buttons) > 0) {
        div(
          style = "text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 4px;",
          buttons
        )
      } else {
        NULL
      }
    })

    # Data table
    output$table <- renderDT(
      {
        if (!is.null(ind_data())) {
          # Get decimal precision
          decimal_prec <- if (!is.null(ind_data()$decimal_precision[1])) {
            ind_data()$decimal_precision[1]
          } else {
            2
          }

          # Prepare data with indicator as first column and source as last (both hidden in display)
          table_data <- ind_data() %>%
            select(Indicator = indicator, Rank = rank, State = state,
                   Period = period_meaningful, Denominator = denominator,
                   Numerator = numerator, Performance = performance, Source = source)

          datatable(
            table_data,
            options = list(
              pageLength = 15,
              scrollX = TRUE,
              columnDefs = list(
                list(visible = FALSE, targets = c(0, 7))  # Hide first (Indicator) and last (Source) columns - 0-indexed
              )
            ),
            rownames = FALSE
          ) %>%
            formatRound('Performance', decimal_prec) %>%
            formatCurrency('Denominator', '', digits = 0) %>%
            formatCurrency('Numerator', '', digits = 0)
        }
      },
      server = FALSE  # Process client-side for proper functionality
    )

    # Download handler for CSV export (all rows, all columns)
    output$download_csv <- downloadHandler(
      filename = function() {
        # Clean indicator name: replace non-alphanumeric with underscore, collapse multiple underscores, trim trailing underscore
        clean_name <- tolower(gsub("_+", "_", gsub("[^a-zA-Z0-9]", "_", ind_data()$indicator_very_short[1])))
        clean_name <- sub("_$", "", clean_name)  # Remove trailing underscore
        paste0("cfsr_profile_", clean_name, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        write.csv(
          ind_data() %>%
            select(Indicator = indicator, Rank = rank, State = state,
                   Period = period_meaningful, Denominator = denominator,
                   Numerator = numerator, Performance = performance, Source = source),
          file,
          row.names = FALSE
        )
      }
    )
  })
}
