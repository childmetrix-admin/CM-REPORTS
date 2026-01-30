# indicator_detail.R - Simplified module for Observed Performance app indicator detail pages
# Shows ONLY national comparison bar chart (no KPI cards)
#
# Uses ChildMetrix design system classes (cm-*) from shared/css/components.css

#####################################
# UI FUNCTION ----
#####################################

indicator_detail_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      column(12,
        # Wrap entire indicator page in white container
        div(class = "cm-page-container",
        # Indicator title (always shown)
        div(class = "cm-indicator-header",
          div(class = "cm-page-title", textOutput(ns("title")))
        ),

        # Additional metadata (only shown when feature flag is OFF)
        if (!exists("USE_VIZ_CONTAINERS") || !USE_VIZ_CONTAINERS) {
          div(class = "cm-indicator-header",
            htmlOutput(ns("description")),
            htmlOutput(ns("metadata")),
            div(class = "cm-mt-3", uiOutput(ns("target")))
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
            div(class = "cm-tab-content",
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
            div(class = "cm-tab-content",
                if (exists("USE_VIZ_CONTAINERS") && USE_VIZ_CONTAINERS) {
                  uiOutput(ns("viz_by_county"))
                } else {
                  div(class = "cm-empty-state",
                      p(class = "cm-text-lg cm-mb-2", "County-level data coming soon"),
                      p(class = "cm-text-md", "This will show performance broken down by county within the state.")
                  )
                }
            )
          ),

          # By Age tab - Conditional rendering
          tabPanel(
            "By Age",
            value = "age",
            div(class = "cm-tab-content",
                if (exists("USE_VIZ_CONTAINERS") && USE_VIZ_CONTAINERS) {
                  uiOutput(ns("viz_by_age"))
                } else {
                  div(class = "cm-empty-state",
                      p(class = "cm-text-lg cm-mb-2", "Age breakdown coming soon"),
                      p(class = "cm-text-md", "This will show performance broken down by age groups.")
                  )
                }
            )
          ),

          # By Race & Ethnicity tab - Conditional rendering
          tabPanel(
            "By Race & Ethnicity",
            value = "race",
            div(class = "cm-tab-content",
              if (exists("USE_VIZ_CONTAINERS") && USE_VIZ_CONTAINERS) {
                uiOutput(ns("viz_by_race"))
              } else {
                div(class = "cm-empty-state",
                  p(class = "cm-text-lg cm-mb-2", "Race & ethnicity breakdown coming soon"),
                  p(class = "cm-text-md", "This will show performance broken down by race and ethnicity.")
                )
              }
            )
          )
        ),

        # Footnote (appears below all tabs, only when feature flag is OFF)
        if (!exists("USE_VIZ_CONTAINERS") || !USE_VIZ_CONTAINERS) {
          div(class = "cm-footnote cm-mt-5", textOutput(ns("source")))
        }
        ) # Close cm-page-container div
      )
    )
  )
}

#####################################
# SERVER FUNCTION ----
#####################################

indicator_detail_server <- function(id, indicator_name, national_data, state_code, profile = reactive("latest")) {
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

      # Check if DQ flag set (data quality issues)
      if (is.list(data) && !is.null(data$dq) && data$dq) {
        # Return empty plot with message
        plot_ly() %>%
          layout(
            xaxis = list(visible = FALSE),
            yaxis = list(visible = FALSE),
            annotations = list(
              list(
                text = "The Children's Bureau could not calculate performance due to data quality issues with the state's AFCARS and/or NCANDS submissions.",
                x = 0.5,
                y = 0.5,
                xref = "paper",
                yref = "paper",
                showarrow = FALSE,
                font = list(size = 14, color = "#6b7280")
              )
            ),
            margin = list(l = 20, r = 20, t = 20, b = 20),
            plot_bgcolor = "white",
            paper_bgcolor = "white"
          ) %>%
          config(displayModeBar = FALSE)
      } else {
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

      # Sort ALL data together (state and counties) by performance
      direction <- data$direction_desired[1]
      if (!is.na(direction) && grepl("lower", direction, ignore.case = TRUE)) {
        # Lower is better: sort ascending (best = lowest first)
        data <- data %>% arrange(performance_display)
      } else {
        # Higher is better: sort descending (best = highest first)
        data <- data %>% arrange(desc(performance_display))
      }

      # Create factor to preserve sort order in plot
      data$dimension_value <- factor(data$dimension_value, levels = data$dimension_value)

      # Create color vector (state = blue, counties = gray)
      bar_colors <- ifelse(data$is_state_total, "#4472C4", "#D3D3D3")

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

      # Calculate x-axis range with padding to prevent label cutoff
      max_value <- max(data$performance_display, na.rm = TRUE)
      x_axis_max <- max_value * 1.15  # Add 15% padding for data labels

      # Create plot
      p <- plot_ly(
        data = data,
        x = ~performance_display,
        y = ~dimension_value,
        type = "bar",
        orientation = "h",
        marker = list(color = bar_colors),
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
            ticks = "outside",  # Show tick marks outside to create spacing
            ticklen = 8,  # Length of tick marks (creates space for labels)
            tickcolor = "rgba(255,255,255,0)",  # Make tick marks invisible (transparent)
            range = c(0, x_axis_max)  # Explicit range with padding for labels
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
            dtick = 1,  # One tick per category
            automargin = FALSE  # Prevent plotly from auto-adjusting margin for long labels
          ),
          margin = list(l = 115, r = 120, t = 10, b = 5),  # Extra space for longer county names
          plot_bgcolor = "white",
          paper_bgcolor = "white",
          hovermode = "closest",
          showlegend = FALSE,
          autosize = FALSE,  # Prevent proportional scaling of text with chart height
          uniformtext = list(minsize = 11, mode = "show")  # Enforce minimum 11px text size (horizontal charts)
        ) %>%
        config(displayModeBar = FALSE)

      return(p)
      }
    })

    # Age chart (vertical bar chart)
    output$chart_age <- renderPlotly({
      req(age_data())
      data <- age_data()

      # Check if DQ flag set (data quality issues)
      if (is.list(data) && !is.null(data$dq) && data$dq) {
        # Return empty plot with message
        plot_ly() %>%
          layout(
            xaxis = list(visible = FALSE),
            yaxis = list(visible = FALSE),
            annotations = list(
              list(
                text = "The Children's Bureau could not calculate performance due to data quality issues with the state's AFCARS and/or NCANDS submissions.",
                x = 0.5,
                y = 0.5,
                xref = "paper",
                yref = "paper",
                showarrow = FALSE,
                font = list(size = 14, color = "#6b7280")
              )
            ),
            margin = list(l = 20, r = 20, t = 20, b = 20),
            plot_bgcolor = "white",
            paper_bgcolor = "white"
          ) %>%
          config(displayModeBar = FALSE)
      } else {
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

      # Build data labels (performance with numerator/denominator in parentheses on new line)
      data_labels <- paste0(
        format(round(performance, decimal_precision), nsmall = decimal_precision),
        if (format_type == "percent") "%" else "",
        "\n(",
        trimws(format(data$numerator, big.mark = ",")), " / ",
        trimws(format(data$denominator, big.mark = ",")),
        ")"
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

      # Calculate y-axis range with padding to prevent label cutoff
      max_value <- max(performance, na.rm = TRUE)
      y_axis_max <- max_value * 1.25  # Add 25% padding for data labels (nudges labels up)

      # Create color vector (total = blue, age groups = gray)
      bar_colors <- ifelse(data$is_total, "#4472C4", "#D3D3D3")

      # Create plot
      p <- plot_ly(
        data = data,
        x = ~dimension_value,
        y = ~performance_display,
        type = "bar",
        marker = list(color = bar_colors),
        text = data_labels,
        textposition = "outside",
        textfont = list(size = 13, color = "#666666", family = "Arial"),
        hovertemplate = hover_text,
        width = 900,
        height = 500
      )

      # Configure layout
      p <- p %>%
        layout(
          xaxis = list(
            title = "",
            showgrid = FALSE,
            tickfont = list(size = 11),
            ticks = "outside",
            ticklen = 8,
            tickcolor = "rgba(255,255,255,0)"
          ),
          yaxis = list(
            title = "",
            showgrid = FALSE,
            zeroline = FALSE,
            tickfont = list(size = 11),
            tickformat = if (format_type == "percent") ".1f" else paste0(".", decimal_precision, "f"),
            ticksuffix = if (format_type == "percent") "%" else "",
            range = c(0, y_axis_max)
          ),
          margin = list(l = 60, r = 40, t = 10, b = 10),
          plot_bgcolor = "white",
          paper_bgcolor = "white",
          hovermode = "closest",
          showlegend = FALSE,
          uniformtext = list(minsize = 11, mode = "show")  # Enforce minimum 11px text size
        ) %>%
        config(displayModeBar = FALSE)

      return(p)
      }
    })

    # Race chart (vertical bar chart)
    output$chart_race <- renderPlotly({
      req(race_data())
      data <- race_data()

      # Check if DQ flag set (data quality issues)
      if (is.list(data) && !is.null(data$dq) && data$dq) {
        # Return empty plot with message
        plot_ly() %>%
          layout(
            xaxis = list(visible = FALSE),
            yaxis = list(visible = FALSE),
            annotations = list(
              list(
                text = "The Children's Bureau could not calculate performance due to data quality issues with the state's AFCARS and/or NCANDS submissions.",
                x = 0.5,
                y = 0.5,
                xref = "paper",
                yref = "paper",
                showarrow = FALSE,
                font = list(size = 14, color = "#6b7280")
              )
            ),
            margin = list(l = 20, r = 20, t = 20, b = 20),
            plot_bgcolor = "white",
            paper_bgcolor = "white"
          ) %>%
          config(displayModeBar = FALSE)
      } else {
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

      # Build data labels (performance with numerator/denominator in parentheses on new line)
      data_labels <- paste0(
        format(round(performance, decimal_precision), nsmall = decimal_precision),
        if (format_type == "percent") "%" else "",
        "\n(",
        trimws(format(data$numerator, big.mark = ",")), " / ",
        trimws(format(data$denominator, big.mark = ",")),
        ")"
      )

      # Build hover text (with breakdown for "Other" group)
      hover_text <- sapply(1:nrow(data), function(i) {
        base_text <- paste0(
          "  <b>", data$race_display[i], "</b>",
          "<br><br>",
          "  Performance: ", format(round(performance[i], decimal_precision), nsmall = decimal_precision), scale_label, "  ",
          "<br>",
          "  Numerator: ", trimws(format(data$numerator[i], big.mark = ",")), "  ",
          "<br>",
          "  Denominator: ", trimws(format(data$denominator[i], big.mark = ",")), "  "
        )

        # Add breakdown if this is "Other" group
        if (!is.na(data$breakdown[i])) {
          base_text <- paste0(
            base_text,
            "<br><br>",
            "  <b>Breakdown:</b>",
            "<br>",
            data$breakdown[i], "  "
          )
        }

        paste0(base_text, "<extra></extra>")
      })

      # Calculate y-axis range with padding to prevent label cutoff
      max_value <- max(performance, na.rm = TRUE)
      y_axis_max <- max_value * 1.25  # Add 25% padding for data labels (nudges labels up)

      # Create color vector (total = blue, race groups = gray)
      bar_colors <- ifelse(data$is_total, "#4472C4", "#D3D3D3")

      # Create plot
      p <- plot_ly(
        data = data,
        x = ~race_display,
        y = ~performance_display,
        type = "bar",
        marker = list(color = bar_colors),
        text = data_labels,
        textposition = "outside",
        textfont = list(size = 13, color = "#666666", family = "Arial"),
        hovertemplate = hover_text,
        width = 900,
        height = 500
      )

      # Configure layout
      p <- p %>%
        layout(
          xaxis = list(
            title = "",
            showgrid = FALSE,
            tickfont = list(size = 11),
            ticks = "outside",
            ticklen = 8,
            tickcolor = "rgba(255,255,255,0)"
          ),
          yaxis = list(
            title = "",
            showgrid = FALSE,
            zeroline = FALSE,
            tickfont = list(size = 11),
            tickformat = if (format_type == "percent") ".1f" else paste0(".", decimal_precision, "f"),
            ticksuffix = if (format_type == "percent") "%" else "",
            range = c(0, y_axis_max)
          ),
          margin = list(l = 60, r = 40, t = 10, b = 10),
          plot_bgcolor = "white",
          paper_bgcolor = "white",
          hovermode = "closest",
          showlegend = FALSE,
          uniformtext = list(minsize = 11, mode = "show")  # Enforce minimum 11px text size
        ) %>%
        config(displayModeBar = FALSE)

      return(p)
      }
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
      selected_profile <- if (is.reactive(profile)) profile() else profile

      # Load state RDS file using load_cfsr_data from utils.R
      tryCatch({
        load_cfsr_data(selected_state_code, selected_profile, "state")
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
      counties <- get_latest_period_data(state_data(), indicator_name, "^Locality$")

      # Filter out missing localities
      if (is.null(counties) || nrow(counties) == 0) {
        return(NULL)
      }

      # Check if performance couldn't be calculated (status == "dq")
      if (!is.null(counties$status) && any(counties$status == "dq", na.rm = TRUE)) {
        return(list(dq = TRUE))
      }

      counties <- counties %>%
        filter(dimension_value != "Locality of report missing")

      # Calculate state total by summing counties
      state_calc <- counties %>%
        summarise(
          numerator = sum(numerator, na.rm = TRUE),
          denominator = sum(denominator, na.rm = TRUE),
          # Copy metadata from first county
          indicator = first(indicator),
          description = first(description),
          format = first(format),
          decimal_precision = first(decimal_precision),
          scale = first(scale),
          direction_desired = first(direction_desired),
          profile_version = first(profile_version),
          period = first(period),
          period_meaningful = first(period_meaningful),
          source = first(source),
          dimension = "Locality"
        ) %>%
        mutate(
          # Calculate performance matching county data format
          # For percentages (format="percent"): stored as decimal (0.142 for 14.2%)
          # For rates (format="rate"): stored as scaled value (2.5 for "2.5 per 1,000")
          performance = if_else(
            format == "percent",
            numerator / denominator,              # Percentage: decimal only
            (numerator / denominator) * scale     # Rate: apply scale multiplier
          ),
          # State name label
          dimension_value = state_codes[get_state()],
          is_state_total = TRUE
        )

      # Add flag to counties
      counties <- counties %>% mutate(is_state_total = FALSE)

      # Combine (will be sorted in chart rendering)
      bind_rows(state_calc, counties)
    })

    # Age data reactive
    age_data <- reactive({
      req(state_data())
      data <- get_latest_period_data(state_data(), indicator_name, "^Age")

      if (is.null(data) || nrow(data) == 0) {
        return(NULL)
      }

      # Check if performance couldn't be calculated (status == "dq")
      if (!is.null(data$status) && any(data$status == "dq", na.rm = TRUE)) {
        return(list(dq = TRUE))
      }

      if (TRUE) {
        # Separate Total row from age groups (filter out only subtotals)
        total_row <- data %>%
          filter(grepl("^total$", dimension_value, ignore.case = TRUE))

        age_groups <- data %>%
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
        existing_ages <- unique(age_groups$dimension_value)
        valid_order <- age_order[age_order %in% existing_ages]

        if (length(valid_order) > 0) {
          age_groups <- age_groups %>%
            mutate(dimension_value = factor(dimension_value, levels = valid_order)) %>%
            arrange(dimension_value)
        }

        # Add is_total flag
        if (nrow(total_row) > 0) {
          total_row <- total_row %>% mutate(is_total = TRUE)
          age_groups <- age_groups %>% mutate(is_total = FALSE)

          # Combine: Total first, then age groups
          data <- bind_rows(total_row, age_groups)

          # Convert dimension_value to factor to preserve order (Total first) in plot
          data <- data %>%
            mutate(dimension_value = factor(dimension_value, levels = unique(dimension_value)))
        } else {
          # No total found, just return age groups with flag
          data <- age_groups %>% mutate(is_total = FALSE)
        }
      }

      data
    })

    # Race data reactive
    race_data <- reactive({
      req(state_data())
      data <- get_latest_period_data(state_data(), indicator_name, "^Race/ethnicity$")

      if (is.null(data) || nrow(data) == 0) {
        return(NULL)
      }

      # Check if performance couldn't be calculated (status == "dq")
      if (!is.null(data$status) && any(data$status == "dq", na.rm = TRUE)) {
        return(list(dq = TRUE))
      }

      if (TRUE) {
        # Calculate Total by summing numerators/denominators
        total_calc <- data %>%
          summarise(
            numerator = sum(numerator, na.rm = TRUE),
            denominator = sum(denominator, na.rm = TRUE),
            # Copy metadata from first race row
            indicator = first(indicator),
            description = first(description),
            format = first(format),
            decimal_precision = first(decimal_precision),
            scale = first(scale),
            direction_desired = first(direction_desired),
            profile_version = first(profile_version),
            period = first(period),
            period_meaningful = first(period_meaningful),
            source = first(source),
            dimension = first(dimension),
            dimension_value = "Total"
          ) %>%
          mutate(
            # Calculate performance matching race data format
            performance = if_else(
              format == "percent",
              numerator / denominator,              # Percentage: decimal only
              (numerator / denominator) * scale     # Rate: apply scale multiplier
            ),
            race_display = "Total",
            is_total = TRUE
          )

        # Separate "Other" races (small sample sizes) from major groups
        other_races <- data %>%
          filter(dimension_value %in% c(
            "American Indian/Alaska Native",
            "Asian",
            "Native Hawaiian/Other Pacific Islander"
          ))

        major_races <- data %>%
          filter(!dimension_value %in% c(
            "American Indian/Alaska Native",
            "Asian",
            "Native Hawaiian/Other Pacific Islander"
          ))

        # Create "Other" aggregated row if there are any small groups
        if (nrow(other_races) > 0) {
          # Store breakdown for tooltip
          other_breakdown <- other_races %>%
            mutate(
              breakdown_text = paste0(
                "  • ",
                dimension_value, ": ",
                trimws(format(numerator, big.mark = ",")), " / ",
                trimws(format(denominator, big.mark = ","))
              )
            ) %>%
            pull(breakdown_text) %>%
            paste(collapse = "<br>")

          # Aggregate "Other" row
          other_calc <- other_races %>%
            summarise(
              numerator = sum(numerator, na.rm = TRUE),
              denominator = sum(denominator, na.rm = TRUE),
              # Copy metadata from first row
              indicator = first(indicator),
              description = first(description),
              format = first(format),
              decimal_precision = first(decimal_precision),
              scale = first(scale),
              direction_desired = first(direction_desired),
              profile_version = first(profile_version),
              period = first(period),
              period_meaningful = first(period_meaningful),
              source = first(source),
              dimension = first(dimension),
              dimension_value = "Other"
            ) %>%
            mutate(
              performance = if_else(
                format == "percent",
                numerator / denominator,
                (numerator / denominator) * scale
              ),
              race_display = "Other",
              is_total = FALSE,
              breakdown = other_breakdown
            )
        } else {
          other_calc <- NULL
        }

        # Recode major race values for brevity
        race_groups <- major_races %>%
          mutate(
            race_display = case_when(
              dimension_value == "Black or African American" ~ "Black or AA",
              dimension_value == "Hispanic (of any race)" ~ "Hispanic",
              dimension_value == "White" ~ "White",
              dimension_value == "Two or More" ~ "Two or More",
              dimension_value == "Unknown/Unable to Determine" ~ "Unknown",
              dimension_value == "Missing Race/Ethnicity Data" ~ "Missing",
              TRUE ~ dimension_value
            ),
            is_total = FALSE,
            breakdown = NA_character_
          )

        # Combine major races with "Other" if it exists
        if (!is.null(other_calc)) {
          race_groups <- bind_rows(race_groups, other_calc)
        }

        # Sort by performance (highest first)
        race_groups <- race_groups %>%
          arrange(desc(performance))

        # Combine: Total first, then race groups sorted by performance
        data <- bind_rows(total_calc %>% mutate(breakdown = NA_character_), race_groups)

        # Convert race_display to factor to preserve order (Total first) in plot
        data <- data %>%
          mutate(race_display = factor(race_display, levels = unique(race_display)))
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
        HTML("")  # Empty string instead of "No national performance"
      }
    }

    # By State viz container
    output$viz_by_state <- renderUI({
      req(ind_data())
      data <- ind_data()

      # Extract metadata
      ind_title <- paste0(data$indicator[1], " \u2014 By State")
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
        state = state_codes[get_state()],
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

      ind_title <- paste0(nat_data$indicator[1], " \u2014 By County")
      ind_desc <- nat_data$description[1]
      profile_ver <- county$profile_version[1]
      period <- county$period_meaningful[1]
      source_text <- county$source[1]
      legend_html <- HTML("")

      build_viz_container(
        ns = session$ns,
        viz_id = "by_county",
        title = ind_title,
        description = ind_desc,
        period = period,
        profile = profile_ver,
        state = state_codes[get_state()],
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

      ind_title <- paste0(nat_data$indicator[1], " \u2014 By Age")
      ind_desc <- nat_data$description[1]
      profile_ver <- age$profile_version[1]
      period <- age$period_meaningful[1]
      source_text <- age$source[1]
      legend_html <- HTML("")

      build_viz_container(
        ns = session$ns,
        viz_id = "by_age",
        title = ind_title,
        description = ind_desc,
        period = period,
        profile = profile_ver,
        state = state_codes[get_state()],
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

      ind_title <- paste0(nat_data$indicator[1], " \u2014 By Race")
      ind_desc <- nat_data$description[1]
      profile_ver <- race$profile_version[1]
      period <- race$period_meaningful[1]
      source_text <- race$source[1]
      legend_html <- HTML("")

      # Build notes text with race definitions
      notes_text <- paste0(
        "<strong>Other</strong> = American Indian/Alaska Native, Asian, and Native Hawaiian/Other Pacific Islander. ",
        "All races exclude children of Hispanic origin. Children of Hispanic ethnicity may be any race."
      )

      build_viz_container(
        ns = session$ns,
        viz_id = "by_race",
        title = ind_title,
        description = ind_desc,
        period = period,
        profile = profile_ver,
        state = state_codes[get_state()],
        legend = legend_html,
        chart_output = plotlyOutput(session$ns("chart_race"), height = "auto"),
        source = source_text,
        notes = notes_text
      )
    })
  })
}
