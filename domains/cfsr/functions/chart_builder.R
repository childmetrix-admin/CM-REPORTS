# chart_builder.R - Functions to build plotly charts

#' Build horizontal bar chart for indicator
#'
#' @param ind_df Indicator data frame (sorted, with is_selected flag)
#' @param selected_state State to highlight
#' @return Plotly object
build_indicator_chart <- function(ind_df, selected_state = NULL) {

  if (is.null(ind_df) || nrow(ind_df) == 0) {
    return(NULL)
  }

  # Get metadata from first row
  has_target <- !is.na(ind_df$national_standard[1]) &&
                ind_df$national_standard[1] != "" &&
                ind_df$national_standard[1] != "NA"
  target_value <- if (has_target) as.numeric(ind_df$national_standard[1]) else NULL
  decimal_precision <- if (!is.na(ind_df$decimal_precision[1])) {
    ind_df$decimal_precision[1]
  } else {
    1
  }
  scale_val <- if (!is.na(ind_df$scale[1])) ind_df$scale[1] else 1
  format_type <- if (!is.na(ind_df$format[1])) ind_df$format[1] else "rate"
  direction <- ind_df$direction_desired[1]

  # Data is already sorted by data_prep.R in the correct order
  # Just use row number to maintain that order (plotly will reverse it)
  # Replace NA performance with 0 for display purposes (won't show bar, but will show label)
  ind_df_display <- ind_df
  ind_df_display$performance[is.na(ind_df_display$performance)] <- 0

  sort_value <- seq_len(nrow(ind_df))

  # Transform percent values to 0-100 scale
  if (format_type == "percent") {
    # Performance data is in decimal form (0.523 = 52.3%)
    # Always multiply by 100 to convert to percentage
    ind_df$performance <- ind_df$performance * 100
    ind_df_display$performance <- ind_df_display$performance * 100
    # National standard is already in percentage form (35.2 means 35.2%)
    # So don't multiply target_value - it's already correct
    decimal_precision <- 1  # Force 1 decimal for percents
  }

  # Determine scale label for hover/display
  scale_label <- case_when(
    format_type == "percent" ~ "%",
    scale_val == 1000 ~ " per 1,000",
    scale_val == 100000 ~ " per 100,000",
    TRUE ~ ""
  )

  # Create bar colors
  bar_colors <- ifelse(ind_df$is_selected, "#4472C4", "#D3D3D3")

  # Build hover text (use original ind_df to preserve NAs)
  perf_display <- ifelse(is.na(ind_df$performance), "Not calculated due to data quality issues",
                        paste0(format(round(ind_df$performance, decimal_precision),
                                     nsmall = decimal_precision), scale_label))

  # Get reporting_states from the data (should be same for all rows in this indicator)
  total_reporting <- ind_df$reporting_states[1]

  rank_display <- ifelse(is.na(ind_df$performance), "Not calculated",
                        paste0(ind_df$rank, " of ", total_reporting))

  # Build hover text with spacing for padding
  hover_text <- paste0(
    "  <b>", ind_df$state, "</b>",
    "<br><br>",  # Space after state name
    "  Performance: ", perf_display, "  ",
    "<br>",
    "  Numerator: ", trimws(format(ind_df$numerator, big.mark = ",")), "  ",
    "<br>",
    "  Denominator: ", trimws(format(ind_df$denominator, big.mark = ",")), "  ",
    "<br>",
    "  Rank: ", rank_display, "  ",
    "<extra></extra>"
  )

  # Create text labels for bars (use original to show descriptive message)
  bar_text <- ifelse(is.na(ind_df$performance), "Not calculated due to data quality issues",
                    paste0(format(round(ind_df_display$performance, decimal_precision),
                                 nsmall = decimal_precision),
                          if (format_type == "percent") "%" else ""))

  # Calculate chart height based on number of states
  # Use fixed 15px per bar for consistent bar width and text size across all charts
  num_states <- nrow(ind_df_display)
  chart_height <- num_states * 15

  # Create base plot using pre-calculated sort_value
  p <- plot_ly(
    data = ind_df_display,
    x = ~performance,
    y = ~reorder(state, sort_value),  # Sort by performance with direction
    type = "bar",
    orientation = "h",
    marker = list(color = bar_colors),
    text = bar_text,
    textposition = "outside",
    textfont = list(size = 11, color = "#666666", family = "Arial"),  # Data label font size (matches axis labels)
    hovertemplate = hover_text,
    height = chart_height  # Specify height here, not in layout()
  )

  # Add target line if applicable
  if (has_target && !is.null(target_value)) {
    # Get the state names in sorted order (same as chart)
    # Must match the sort_value logic above
    temp_perf <- ind_df$performance
    temp_perf[is.na(temp_perf)] <- if (!is.na(direction) && direction == "down") -Inf else Inf

    if (!is.na(direction) && direction == "down") {
      states_ordered <- ind_df %>% arrange(temp_perf) %>% pull(state)
    } else {
      states_ordered <- ind_df %>% arrange(desc(temp_perf)) %>% pull(state)
    }

    p <- p %>%
      add_segments(
        x = target_value,
        xend = target_value,
        y = states_ordered[nrow(ind_df)],  # Bottom state
        yend = states_ordered[1],  # Top state
        line = list(color = "#10b981", width = 2, dash = "dash"),
        showlegend = FALSE,
        hoverinfo = "skip",
        inherit = FALSE
      )
  }

  # Configure x-axis format based on indicator type
  xaxis_config <- list(
    title = "",  # Remove x-axis title
    showgrid = TRUE,
    gridcolor = "#E5E5E5",
    zeroline = FALSE,  # Remove the vertical 0 axis line
    tickfont = list(size = 11)  # X-axis label font size
  )

  # Add formatting to axis based on type
  if (format_type == "percent") {
    # Don't use ticksuffix as it auto-multiplies by 100
    # Instead, manually format the ticks
    xaxis_config$tickformat <- ".1f"
    xaxis_config$ticksuffix <- "%"
  } else if (format_type == "rate") {
    # For rates, format with decimal places
    xaxis_config$tickformat <- paste0(".", decimal_precision, "f")
  }

  # Configure layout
  p <- p %>%
    layout(
      xaxis = xaxis_config,
      yaxis = list(
        title = "",
        showgrid = FALSE,
        categoryorder = "trace",  # Use data order
        tickfont = list(size = 11),  # State label font size
        ticksuffix = "  ",  # Add padding between state labels and axis
        fixedrange = TRUE,  # Prevent zooming/panning
        range = c(-0.5, num_states - 0.5)  # Tight fit to data, no extra space
      ),
      margin = list(l = 100, r = 80, t = 10, b = 20),
      plot_bgcolor = "white",
      paper_bgcolor = "white",
      hovermode = "closest",
      showlegend = FALSE,
      autosize = FALSE  # Prevent proportional scaling of text with chart height
    ) %>%
    config(displayModeBar = FALSE)  # Hide plotly toolbar

  return(p)
}

#' Build small multiple chart for overview page
#'
#' @param ind_df Indicator data frame
#' @param selected_state State to highlight
#' @return Plotly object (smaller version)
build_overview_chart <- function(ind_df, selected_state = NULL) {

  if (is.null(ind_df) || nrow(ind_df) == 0) {
    return(NULL)
  }

  # For overview, show only top 10 + selected state if not in top 10
  top_states <- ind_df %>%
    slice_head(n = 10)

  # Check if selected state is in top 10
  if (!is.null(selected_state) &&
      !(selected_state %in% top_states$state)) {
    state_row <- ind_df %>% filter(state == selected_state)
    if (nrow(state_row) > 0) {
      top_states <- bind_rows(top_states, state_row)
    }
  }

  # Rebuild selection flag
  top_states <- top_states %>%
    mutate(is_selected = state == selected_state)

  # Get metadata
  has_target <- !is.na(ind_df$national_standard[1]) &&
                ind_df$national_standard[1] != "" &&
                ind_df$national_standard[1] != "NA"
  target_value <- if (has_target) as.numeric(ind_df$national_standard[1]) else NULL

  # Create bar colors
  bar_colors <- ifelse(top_states$is_selected, "#4472C4", "#D3D3D3")

  # Simpler hover text
  hover_text <- paste0(
    "<b>", top_states$state, "</b><br>",
    "Performance: ", format(round(top_states$performance, 1), nsmall = 1),
    "<extra></extra>"
  )

  # Create plot
  p <- plot_ly(
    data = top_states,
    x = ~performance,
    y = ~reorder(state, -rank),
    type = "bar",
    orientation = "h",
    marker = list(color = bar_colors),
    hovertemplate = hover_text,
    height = 300  # Specify height here
  )

  # Add target line if applicable
  if (has_target && !is.null(target_value)) {
    p <- p %>%
      add_segments(
        x = target_value,
        xend = target_value,
        y = 0,
        yend = nrow(top_states) + 1,
        line = list(color = "#10b981", width = 1.5, dash = "dash"),
        showlegend = FALSE,
        hoverinfo = "skip",
        inherit = FALSE
      )
  }

  # Compact layout
  p <- p %>%
    layout(
      xaxis = list(
        title = "",
        showgrid = TRUE,
        gridcolor = "#E5E5E5",
        tickfont = list(size = 9)
      ),
      yaxis = list(
        title = "",
        showgrid = FALSE,
        categoryorder = "trace",
        tickfont = list(size = 9)
      ),
      margin = list(l = 80, r = 20, t = 5, b = 30),
      plot_bgcolor = "white",
      paper_bgcolor = "white",
      hovermode = "closest",
      showlegend = FALSE
    ) %>%
    config(displayModeBar = FALSE)

  return(p)
}

#' Build overview rankings table
#'
#' @param app_data Full app data with all indicators
#' @param selected_state State to highlight (optional)
#' @return Data frame for DT table
build_overview_rankings_table <- function(app_data, selected_state = NULL) {

  # Get all unique indicators, sorted by indicator_sort
  indicators <- app_data %>%
    distinct(indicator, indicator_very_short, indicator_sort, indicator_short) %>%
    arrange(indicator_sort)

  # Get all unique states
  states <- app_data %>%
    distinct(state) %>%
    arrange(state)

  # Create base data frame with State column
  result <- states

  # Rename state column to State (capitalized)
  colnames(result)[1] <- "State"

  # Add a column for each indicator with rank values
  for (i in 1:nrow(indicators)) {
    ind_name <- indicators$indicator[i]
    col_name <- indicators$indicator_very_short[i]

    ind_data <- app_data %>%
      filter(indicator == ind_name) %>%
      select(state, state_rank, performance, numerator, denominator, indicator_short)

    # Join with result (using original 'state' column name from states df)
    result <- result %>%
      left_join(
        ind_data %>% select(state, rank_value = state_rank),
        by = c("State" = "state")
      )

    # Rename the column
    colnames(result)[ncol(result)] <- col_name
  }

  return(result)
}

#' Build state performance summary table
#'
#' @param app_data Full app data with all indicators
#' @param selected_state State to show performance for
#' @return Data frame for DT table
build_state_performance_table <- function(app_data, selected_state) {

  if (is.null(selected_state)) {
    return(NULL)
  }

  # Get all unique indicators, sorted by indicator_sort
  indicators <- app_data %>%
    distinct(indicator, indicator_sort, format) %>%
    arrange(indicator_sort)

  # Build result data frame
  result <- data.frame(
    Indicator = character(),
    Rank = character(),  # Changed to character to handle "DQ"
    `Reporting States` = integer(),
    Performance = character(),  # Changed to character to handle formatting
    `National Standard` = character(),  # Changed to character to handle formatting
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  for (i in 1:nrow(indicators)) {
    ind_name <- indicators$indicator[i]
    ind_format <- indicators$format[i]

    # Get state data for this indicator
    state_data <- app_data %>%
      filter(indicator == ind_name, state == selected_state)

    if (nrow(state_data) > 0) {
      # Get reporting_states from the data (already calculated in CSV)
      reporting_states <- state_data$reporting_states[1]
      # Format performance based on indicator format
      perf_value <- state_data$performance[1]
      if (is.na(perf_value)) {
        perf_formatted <- "DQ"
      } else {
        if (ind_format == "percent") {
          perf_formatted <- paste0(format(round(perf_value * 100, 1), nsmall = 1), " %")
        } else {  # rate
          perf_formatted <- format(round(perf_value, 2), nsmall = 2)
        }
      }

      # Format national standard (already in correct units, just format decimals)
      nat_std <- state_data$national_standard[1]
      if (!is.na(nat_std) && nat_std != "") {
        nat_std_num <- as.numeric(nat_std)
        # National standards are already in display format (e.g., 35.2 for percent, 9.07 for rate)
        # Just format the decimals appropriately
        if (ind_format == "percent") {
          nat_std_formatted <- paste0(format(round(nat_std_num, 1), nsmall = 1), " %")
        } else {  # rate
          nat_std_formatted <- format(round(nat_std_num, 2), nsmall = 2)
        }
      } else {
        nat_std_formatted <- "No national standard"
      }

      # Format rank
      rank_value <- state_data$state_rank[1]
      rank_formatted <- if (!is.na(rank_value)) as.character(rank_value) else "DQ"

      result <- rbind(result, data.frame(
        Indicator = ind_name,  # Use full indicator name instead of indicator_very_short
        Rank = rank_formatted,
        `Reporting States` = reporting_states,
        Performance = perf_formatted,
        `National Standard` = nat_std_formatted,
        stringsAsFactors = FALSE,
        check.names = FALSE
      ))
    }
  }

  return(result)
}
