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
        # Indicator title (always shown)
        div(class = "indicator-header",
          div(class = "indicator-title", textOutput(ns("title")))
        ),

        # Additional metadata (only shown when feature flag is OFF)
        if (!exists("USE_VIZ_CONTAINERS") || !USE_VIZ_CONTAINERS) {
          div(class = "indicator-header",
            htmlOutput(ns("description")),
            htmlOutput(ns("metadata")),
            div(style = "margin-top: 12px;", uiOutput(ns("target")))
          )
        },

        # Tabbed content
        tabsetPanel(
          id = ns("breakdown_tabs"),
          type = "tabs",

          # By State tab - Conditional rendering based on feature flag
          tabPanel(
            "By State",
            value = "state",
            div(style = "margin-top: 20px;",
                if (exists("USE_VIZ_CONTAINERS") && USE_VIZ_CONTAINERS) {
                  uiOutput(ns("viz_by_state"))
                } else {
                  plotlyOutput(ns("chart"), height = "auto")
                }
            )
          ),

          # By County tab - Conditional rendering
          tabPanel(
            "By County",
            value = "county",
            div(style = "margin-top: 20px;",
                if (exists("USE_VIZ_CONTAINERS") && USE_VIZ_CONTAINERS) {
                  uiOutput(ns("viz_by_county"))
                } else {
                  div(style = "padding: 40px; text-align: center; color: #6b7280;",
                      p(style = "font-size: 18px; margin-bottom: 10px;", "County-level data coming soon"),
                      p(style = "font-size: 14px;", "This will show performance broken down by county within the state.")
                  )
                }
            )
          ),

          # By Age tab - Conditional rendering
          tabPanel(
            "By Age",
            value = "age",
            div(style = "margin-top: 20px;",
                if (exists("USE_VIZ_CONTAINERS") && USE_VIZ_CONTAINERS) {
                  uiOutput(ns("viz_by_age"))
                } else {
                  div(style = "padding: 40px; text-align: center; color: #6b7280;",
                      p(style = "font-size: 18px; margin-bottom: 10px;", "Age breakdown coming soon"),
                      p(style = "font-size: 14px;", "This will show performance broken down by age groups.")
                  )
                }
            )
          ),

          # By Race & Ethnicity tab - Conditional rendering
          tabPanel(
            "By Race & Ethnicity",
            value = "race",
            div(style = "margin-top: 20px;",
              if (exists("USE_VIZ_CONTAINERS") && USE_VIZ_CONTAINERS) {
                uiOutput(ns("viz_by_race"))
              } else {
                div(style = "padding: 40px; text-align: center; color: #6b7280;",
                  p(style = "font-size: 18px; margin-bottom: 10px;", "Race & ethnicity breakdown coming soon"),
                  p(style = "font-size: 14px;", "This will show performance broken down by race and ethnicity.")
                )
              }
            )
          )
        ),

        # Footnote (appears below all tabs, only when feature flag is OFF)
        if (!exists("USE_VIZ_CONTAINERS") || !USE_VIZ_CONTAINERS) {
          div(class = "chart-footnote", style = "margin-top: 20px;", textOutput(ns("source")))
        }
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

      # Filter to specific indicator and exclude "National" from state comparison
      ind_df <- data %>%
        filter(indicator == indicator_name,
               state != "National")

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

    # County chart (horizontal bar chart)
    output$chart_county <- renderPlotly({
      req(county_data())
      data <- county_data()

      # Get metadata
      format_type <- data$format[1]
      decimal_precision <- if (!is.na(data$decimal_precision[1])) data$decimal_precision[1] else 1
      scale_val <- if (!is.na(data$scale[1])) data$scale[1] else 1

      # Transform performance for display (state RDS uses "performance" column)
      performance <- data$performance
      if (format_type == "percent") {
        performance <- performance * 100
        decimal_precision <- 1
      }

      # Add transformed performance to data frame
      data$performance_display <- performance

      # Sort by performance (best to worst based on direction_desired)
      direction <- data$direction_desired[1]
      if (!is.na(direction) && grepl("lower", direction, ignore.case = TRUE)) {
        # Lower is better: sort ascending (best = lowest first)
        data <- data %>% arrange(performance)
      } else {
        # Higher is better: sort descending (best = highest first)
        data <- data %>% arrange(desc(performance))
      }

      # Create factor to preserve sort order in plot
      data$dimension_value <- factor(data$dimension_value, levels = data$dimension_value)

      # Determine scale label
      scale_label <- case_when(
        format_type == "percent" ~ "%",
        scale_val == 1000 ~ " per 1,000",
        scale_val == 100000 ~ " per 100,000",
        TRUE ~ ""
      )

      # Build hover text (use data$performance_display which is sorted)
      hover_text <- paste0(
        "  <b>", data$dimension_value, "</b>",
        "<br><br>",
        "  Performance: ", format(round(data$performance_display, decimal_precision), nsmall = decimal_precision), scale_label, "  ",
        "<br>",
        "  Numerator: ", trimws(format(data$numerator, big.mark = ",")), "  ",
        "<br>",
        "  Denominator: ", trimws(format(data$denominator, big.mark = ",")), "  ",
        "<extra></extra>"
      )

      # Bar text (use data$performance_display which is sorted)
      bar_text <- paste0(format(round(data$performance_display, decimal_precision), nsmall = decimal_precision),
                        if (format_type == "percent") "%" else "")

      # Calculate chart height using fixed 15px per bar for consistent bar width and text size
      chart_height <- nrow(data) * 15

      # Create plot
      p <- plot_ly(
        data = data,
        x = ~performance_display,
        y = ~dimension_value,
        type = "bar",
        orientation = "h",
        marker = list(color = "#4472C4"),
        text = bar_text,
        textposition = "outside",
        textfont = list(size = 11, color = "#666666", family = "Arial"),  # Data label font size (horizontal charts)
        hovertemplate = hover_text,
        height = chart_height
      )

      # Configure layout
      p <- p %>%
        layout(
          xaxis = list(
            title = "",
            showgrid = TRUE,
            gridcolor = "#E5E5E5",
            zeroline = FALSE,
            tickfont = list(size = 11),
            tickformat = if (format_type == "percent") ".1f" else paste0(".", decimal_precision, "f"),
            ticksuffix = if (format_type == "percent") "%" else "",
            ticks = "",  # Hide tick marks
            standoff = 10  # Distance in pixels between axis line and tick labels
          ),
          yaxis = list(
            title = "",
            showgrid = FALSE,
            categoryorder = "trace",
            tickfont = list(size = 11),
            ticksuffix = "  ",
            fixedrange = TRUE,
            range = c(-0.5, nrow(data) - 0.5),  # Tight fit to data (controls bar width)
            tickmode = "linear",  # Force all labels to show
            dtick = 1  # One tick per category
          ),
          margin = list(l = 150, r = 80, t = 10, b = 20),
          plot_bgcolor = "white",
          paper_bgcolor = "white",
          hovermode = "closest",
          showlegend = FALSE,
          autosize = FALSE,  # Prevent proportional scaling of text with chart height
          uniformtext = list(minsize = 11, mode = "show")  # Enforce minimum 11px text size (horizontal charts)
        ) %>%
        config(displayModeBar = FALSE)

      return(p)
    })

    # Age chart (vertical bar chart)
    output$chart_age <- renderPlotly({
      req(age_data())
      data <- age_data()

      # Get metadata
      format_type <- data$format[1]
      decimal_precision <- if (!is.na(data$decimal_precision[1])) data$decimal_precision[1] else 1
      scale_val <- if (!is.na(data$scale[1])) data$scale[1] else 1

      # Transform performance for display (state RDS uses "performance" column)
      performance <- data$performance
      if (format_type == "percent") {
        performance <- performance * 100
        decimal_precision <- 1
      }

      # Add transformed performance to data frame (FIX FOR PLOTLY ERROR)
      data$performance_display <- performance

      # Determine scale label
      scale_label <- case_when(
        format_type == "percent" ~ "%",
        scale_val == 1000 ~ " per 1,000",
        scale_val == 100000 ~ " per 100,000",
        TRUE ~ ""
      )

      # Build data labels (performance + numerator/denominator)
      data_labels <- paste0(
        format(round(performance, decimal_precision), nsmall = decimal_precision),
        if (format_type == "percent") "%" else "",
        "\n",
        trimws(format(data$numerator, big.mark = ",")), " / ",
        trimws(format(data$denominator, big.mark = ","))
      )

      # Build hover text
      hover_text <- paste0(
        "  <b>", data$dimension_value, "</b>",
        "<br><br>",
        "  Performance: ", format(round(performance, decimal_precision), nsmall = decimal_precision), scale_label, "  ",
        "<br>",
        "  Numerator: ", trimws(format(data$numerator, big.mark = ",")), "  ",
        "<br>",
        "  Denominator: ", trimws(format(data$denominator, big.mark = ",")), "  ",
        "<extra></extra>"
      )

      # Create plot
      p <- plot_ly(
        data = data,
        x = ~dimension_value,
        y = ~performance_display,
        type = "bar",
        marker = list(color = "#4472C4"),
        text = data_labels,
        textposition = "outside",
        textfont = list(size = 15, color = "#666666", family = "Arial"),  # Data label font size (vertical charts)
        hovertemplate = hover_text,
        height = 500
      )

      # Configure layout
      p <- p %>%
        layout(
          xaxis = list(
            title = "",
            showgrid = FALSE,
            tickfont = list(size = 11),
            ticks = "",  # Hide tick marks
            standoff = 10  # Distance in pixels between axis line and tick labels
          ),
          yaxis = list(
            title = "",
            showgrid = FALSE,
            zeroline = FALSE,
            tickfont = list(size = 11),
            tickformat = if (format_type == "percent") ".1f" else paste0(".", decimal_precision, "f"),
            ticksuffix = if (format_type == "percent") "%" else ""
          ),
          margin = list(l = 60, r = 40, t = 10, b = 60),
          plot_bgcolor = "white",
          paper_bgcolor = "white",
          hovermode = "closest",
          showlegend = FALSE
        ) %>%
        config(displayModeBar = FALSE)

      return(p)
    })

    # Race chart (vertical bar chart)
    output$chart_race <- renderPlotly({
      req(race_data())
      data <- race_data()

      # Get metadata
      format_type <- data$format[1]
      decimal_precision <- if (!is.na(data$decimal_precision[1])) data$decimal_precision[1] else 1
      scale_val <- if (!is.na(data$scale[1])) data$scale[1] else 1

      # Transform performance for display (state RDS uses "performance" column)
      performance <- data$performance
      if (format_type == "percent") {
        performance <- performance * 100
        decimal_precision <- 1
      }

      # Add transformed performance to data frame (FIX FOR PLOTLY ERROR)
      data$performance_display <- performance

      # Determine scale label
      scale_label <- case_when(
        format_type == "percent" ~ "%",
        scale_val == 1000 ~ " per 1,000",
        scale_val == 100000 ~ " per 100,000",
        TRUE ~ ""
      )

      # Build data labels (performance + numerator/denominator)
      data_labels <- paste0(
        format(round(performance, decimal_precision), nsmall = decimal_precision),
        if (format_type == "percent") "%" else "",
        "\n",
        trimws(format(data$numerator, big.mark = ",")), " / ",
        trimws(format(data$denominator, big.mark = ","))
      )

      # Build hover text
      hover_text <- paste0(
        "  <b>", data$race_display, "</b>",
        "<br><br>",
        "  Performance: ", format(round(performance, decimal_precision), nsmall = decimal_precision), scale_label, "  ",
        "<br>",
        "  Numerator: ", trimws(format(data$numerator, big.mark = ",")), "  ",
        "<br>",
        "  Denominator: ", trimws(format(data$denominator, big.mark = ",")), "  ",
        "<extra></extra>"
      )

      # Create plot
      p <- plot_ly(
        data = data,
        x = ~race_display,
        y = ~performance_display,
        type = "bar",
        marker = list(color = "#4472C4"),
        text = data_labels,
        textposition = "outside",
        textfont = list(size = 15, color = "#666666", family = "Arial"),  # Data label font size (vertical charts)
        hovertemplate = hover_text,
        height = 500
      )

      # Configure layout
      p <- p %>%
        layout(
          xaxis = list(
            title = "",
            showgrid = FALSE,
            tickfont = list(size = 11),
            ticks = "",  # Hide tick marks
            standoff = 10  # Distance in pixels between axis line and tick labels
          ),
          yaxis = list(
            title = "",
            showgrid = FALSE,
            zeroline = FALSE,
            tickfont = list(size = 11),
            tickformat = if (format_type == "percent") ".1f" else paste0(".", decimal_precision, "f"),
            ticksuffix = if (format_type == "percent") "%" else ""
          ),
          margin = list(l = 60, r = 40, t = 10, b = 60),
          plot_bgcolor = "white",
          paper_bgcolor = "white",
          hovermode = "closest",
          showlegend = FALSE
        ) %>%
        config(displayModeBar = FALSE)

      return(p)
    })

    # Source footnote
    output$source <- renderText({
      if (!is.null(ind_data())) {
        paste("Source:", ind_data()$source[1])
      } else {
        ""
      }
    })

    #####################################
    # STATE DATA LOADING (for demographic breakdowns) ----
    #####################################

    # Load state RDS data for County, Age, Race breakdowns
    state_data <- reactive({
      selected_state_code <- get_state()

      # Load state RDS file using load_cfsr_data from utils.R
      tryCatch({
        load_cfsr_data(selected_state_code, "latest", "state")
      }, error = function(e) {
        message("Error loading state data: ", e$message)
        return(NULL)
      })
    })

    # Helper function to get latest period for an indicator and dimension
    get_latest_period_data <- function(data, indicator, dimension_pattern) {
      if (is.null(data) || nrow(data) == 0) {
        return(NULL)
      }

      # Filter by indicator and dimension
      filtered <- data %>%
        filter(indicator == !!indicator,
               grepl(dimension_pattern, dimension, ignore.case = TRUE))

      if (nrow(filtered) == 0) {
        return(NULL)
      }

      # Get latest period
      latest_period <- max(filtered$period, na.rm = TRUE)

      # Return latest period data
      filtered %>%
        filter(period == latest_period)
    }

    # County data reactive
    county_data <- reactive({
      req(state_data())
      data <- get_latest_period_data(state_data(), indicator_name, "^Locality$")

      # Filter out missing localities
      if (!is.null(data) && nrow(data) > 0) {
        data <- data %>%
          filter(dimension_value != "Locality of report missing")
      }

      data
    })

    # Age data reactive
    age_data <- reactive({
      req(state_data())
      data <- get_latest_period_data(state_data(), indicator_name, "^Age")

      if (!is.null(data) && nrow(data) > 0) {
        # Filter out subtotal and total rows
        data <- data %>%
          filter(!grepl("subtotal|total", dimension_value, ignore.case = TRUE))

        # Sort age groups in chronological order
        # Comprehensive list covering all possible age breakdowns
        age_order <- c(
          "0 - 3 mos",
          "4 - 11 mos",
          "< 1 yr",
          "1 - 5 yrs",
          "6 - 10 yrs",
          "11 - 15 yrs",
          "11 - 16 yrs",
          "16 - 17 yrs",
          "17 yrs",
          "18+ yrs"
        )

        # Only convert to factor using ages that exist in the data
        existing_ages <- unique(data$dimension_value)
        valid_order <- age_order[age_order %in% existing_ages]

        if (length(valid_order) > 0) {
          data <- data %>%
            mutate(dimension_value = factor(dimension_value, levels = valid_order)) %>%
            arrange(dimension_value)
        }
      }

      data
    })

    # Race data reactive
    race_data <- reactive({
      req(state_data())
      data <- get_latest_period_data(state_data(), indicator_name, "^Race/ethnicity$")

      if (!is.null(data) && nrow(data) > 0) {
        # Recode race values for brevity
        data <- data %>%
          mutate(
            race_display = case_when(
              dimension_value == "American Indian/Alaska Native" ~ "AA/AN",
              dimension_value == "Asian" ~ "Asian",
              dimension_value == "Black or African American" ~ "Black or AA",
              dimension_value == "Hispanic (of any race)" ~ "Hispanic",
              dimension_value == "Native Hawaiian/Other Pacific Islander" ~ "NH or OPI",
              dimension_value == "White" ~ "White",
              dimension_value == "Two or More" ~ "Two or More",
              dimension_value == "Unknown/Unable to Determine" ~ "Unknown",
              dimension_value == "Missing Race/Ethnicity Data" ~ "Missing",
              TRUE ~ dimension_value
            )
          ) %>%
          arrange(race_display)  # Sort alphabetically by display name
      }

      data
    })

    #####################################
    # VIZ CONTAINER OUTPUTS (for new self-contained viz mode) ----
    #####################################

    # Helper function to build legend HTML
    build_legend_html <- function(data) {
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
          '<span class="legend-line"></span>',
          "National performance: ", symbol, " ", target, suffix
        ))
      } else {
        HTML("No national performance")
      }
    }

    # By State viz container
    output$viz_by_state <- renderUI({
      req(ind_data())
      data <- ind_data()

      # Extract metadata
      ind_title <- data$indicator[1]
      ind_desc <- data$description[1]
      profile_ver <- data$profile_version[1]
      period <- data$period_meaningful[1]
      source_text <- data$source[1]
      legend_html <- build_legend_html(data)

      # Build viz container
      build_viz_container(
        ns = session$ns,
        viz_id = "by_state",
        title = ind_title,
        description = ind_desc,
        period = period,
        profile = profile_ver,
        legend = legend_html,
        chart_output = plotlyOutput(session$ns("chart"), height = "auto"),
        source = source_text
      )
    })

    # By County viz container
    output$viz_by_county <- renderUI({
      req(ind_data(), county_data())
      nat_data <- ind_data()
      county <- county_data()

      ind_title <- nat_data$indicator[1]
      ind_desc <- nat_data$description[1]
      profile_ver <- county$profile_version[1]
      period <- county$period_meaningful[1]
      source_text <- county$source[1]
      legend_html <- HTML("County-level breakdown")

      build_viz_container(
        ns = session$ns,
        viz_id = "by_county",
        title = ind_title,
        description = ind_desc,
        period = period,
        profile = profile_ver,
        legend = legend_html,
        chart_output = plotlyOutput(session$ns("chart_county"), height = "auto"),
        source = source_text
      )
    })

    # By Age viz container
    output$viz_by_age <- renderUI({
      req(ind_data(), age_data())
      nat_data <- ind_data()
      age <- age_data()

      ind_title <- nat_data$indicator[1]
      ind_desc <- nat_data$description[1]
      profile_ver <- age$profile_version[1]
      period <- age$period_meaningful[1]
      source_text <- age$source[1]
      legend_html <- HTML("Age group breakdown")

      build_viz_container(
        ns = session$ns,
        viz_id = "by_age",
        title = ind_title,
        description = ind_desc,
        period = period,
        profile = profile_ver,
        legend = legend_html,
        chart_output = plotlyOutput(session$ns("chart_age"), height = "auto"),
        source = source_text
      )
    })

    # By Race & Ethnicity viz container
    output$viz_by_race <- renderUI({
      req(ind_data(), race_data())
      nat_data <- ind_data()
      race <- race_data()

      ind_title <- nat_data$indicator[1]
      ind_desc <- nat_data$description[1]
      profile_ver <- race$profile_version[1]
      period <- race$period_meaningful[1]
      source_text <- race$source[1]
      legend_html <- HTML("Race & ethnicity breakdown")

      # Build race abbreviation footnote
      race_footnote <- paste0(
        source_text, "<br><br>",
        "<strong>Race/ethnicity abbreviations:</strong> ",
        "AA/AN = American Indian/Alaska Native; ",
        "Black or AA = Black or African American; ",
        "NH or OPI = Native Hawaiian/Other Pacific Islander"
      )

      build_viz_container(
        ns = session$ns,
        viz_id = "by_race",
        title = ind_title,
        description = ind_desc,
        period = period,
        profile = profile_ver,
        legend = legend_html,
        chart_output = plotlyOutput(session$ns("chart_race"), height = "auto"),
        source = race_footnote
      )
    })
  })
}
