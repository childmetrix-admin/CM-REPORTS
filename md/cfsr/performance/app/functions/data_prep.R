# data_prep.R - Data preparation functions

#' Prepare data for Shiny app
#'
#' Filters to latest period per indicator and joins dictionary metadata
#'
#' @param ind_data Data frame from r_cfsr_profile.R output
#' @param dict Dictionary data frame
#' @return Prepared data frame ready for app
prepare_app_data <- function(ind_data, dict) {

  # Convert dates if needed
  if ("as_of_date" %in% names(ind_data) && !inherits(ind_data$as_of_date, "Date")) {
    ind_data$as_of_date <- as.Date(ind_data$as_of_date)
  }

  # Filter to most recent period per indicator
  latest_data <- ind_data %>%
    group_by(indicator) %>%
    filter(period == max(period, na.rm = TRUE)) %>%
    ungroup()

  # Join dictionary metadata
  app_data <- latest_data %>%
    left_join(
      dict %>% select(
        indicator,
        indicator_short,
        category,
        description,
        denominator_def = denominator,
        numerator_def = numerator,
        national_standard,
        direction_rule,
        direction_desired,
        direction_legend,
        decimal_precision,
        scale,
        format,
        risk_adjustment,
        exclusions,
        notes
      ),
      by = "indicator"
    )

  return(app_data)
}

#' Get data for a specific indicator
#'
#' @param app_data Full app data
#' @param indicator_name Indicator name to filter
#' @param selected_state State to highlight
#' @return Data frame sorted by performance (best to worst)
get_indicator_data <- function(app_data, indicator_name, selected_state = NULL) {

  # Filter to indicator
  ind_df <- app_data %>%
    filter(indicator == indicator_name)

  if (nrow(ind_df) == 0) {
    warning("No data found for indicator: ", indicator_name)
    return(NULL)
  }

  # Use state_rank from CSV (pre-calculated with correct direction logic)
  # Sort by state_rank (best to worst: rank 1 = best)
  # Note: We want BEST at BOTTOM because plotly will reverse it to show at top
  # Handle NAs: Put them at the BOTTOM (worst position) so they appear at top of chart
  ind_df <- ind_df %>%
    arrange(desc(state_rank))  # Sort descending so rank 1 (best) is at bottom for plotly

  # Rename state_rank to rank for consistency with rest of app
  ind_df <- ind_df %>%
    mutate(rank = state_rank)

  # Add highlight flag for selected state
  if (!is.null(selected_state)) {
    ind_df <- ind_df %>%
      mutate(is_selected = state == selected_state)
  } else {
    ind_df <- ind_df %>%
      mutate(is_selected = FALSE)
  }

  return(ind_df)
}

#' Get summary statistics for an indicator
#'
#' @param ind_df Indicator data frame
#' @param selected_state State to get stats for
#' @return List with summary stats
get_indicator_summary <- function(ind_df, selected_state = NULL) {

  stats <- list(
    total_states = nrow(ind_df),
    best_performance = min(ind_df$performance, na.rm = TRUE),
    worst_performance = max(ind_df$performance, na.rm = TRUE),
    median_performance = median(ind_df$performance, na.rm = TRUE),
    has_target = !is.na(ind_df$national_standard[1]) &&
                 ind_df$national_standard[1] != ""
  )

  if (!is.null(selected_state)) {
    state_row <- ind_df %>% filter(state == selected_state)

    if (nrow(state_row) > 0) {
      stats$state_rank <- state_row$rank[1]
      stats$state_performance <- state_row$performance[1]
      stats$state_numerator <- state_row$numerator[1]
      stats$state_denominator <- state_row$denominator[1]
    }
  }

  return(stats)
}

#' Get all indicators for overview page
#'
#' @param app_data Full app data
#' @return List of indicator names in order
get_all_indicators <- function(app_data) {
  app_data %>%
    distinct(indicator, indicator_short, category) %>%
    arrange(
      factor(category, levels = c("Safety", "Permanency", "Well-Being", "Other")),
      indicator_short
    ) %>%
    pull(indicator)
}
