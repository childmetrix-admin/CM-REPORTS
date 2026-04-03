########################################
# CFSR Profile PowerPoint Generation
########################################
# Purpose: Generate PowerPoint presentations from CFSR profile data
# Inputs: State code, profile period
# Outputs: PowerPoint file with data-driven talking points and screenshot placeholders

########################################
# LIBRARIES & CONFIGURATION ----
########################################

library(officer)   # PowerPoint manipulation
library(tidyverse) # Data manipulation
library(glue)      # String interpolation

# Source shared utilities
source("shared/utils/state_utils.R")

# Source CFSR functions
source("domains/cfsr/functions/functions_cfsr_profile_shared.R")
source("domains/cfsr/extraction/paths.R")

########################################
# FUNCTIONS ----
########################################

#' Load CFSR Data for PowerPoint Generation
#'
#' Reads RDS files and indicator dictionary for specified state/period
#'
#' @param state Character. State code (e.g., "md", "ky")
#' @param period Character. Profile period (e.g., "2025_02")
#'
#' @return List with state, rsp, observed data and dictionary
#'
#' @examples
#' data <- load_cfsr_data("md", "2025_02")
#'
load_cfsr_data <- function(state, period) {
  # Validate inputs
  if (missing(state) || missing(period)) {
    stop("Both state and period are required")
  }

  # Construct file paths
  state_upper <- toupper(state)
  state_file <- glue("domains/cfsr/data/rds/{state}/{period}/{state_upper}_cfsr_profile_state_{period}.rds")
  rsp_file <- glue("domains/cfsr/data/rds/{state}/{period}/{state_upper}_cfsr_profile_rsp_{period}.rds")
  observed_file <- glue("domains/cfsr/data/rds/{state}/{period}/{state_upper}_cfsr_profile_observed_{period}.rds")

  # Validate files exist
  if (!file.exists(state_file)) {
    stop(glue("State file not found: {state_file}"))
  }
  if (!file.exists(rsp_file)) {
    stop(glue("RSP file not found: {rsp_file}"))
  }
  if (!file.exists(observed_file)) {
    stop(glue("Observed file not found: {observed_file}"))
  }

  # Read RDS files
  message(glue("Loading data for {state_upper} - {period}"))
  state_data <- readRDS(state_file)
  rsp_data <- readRDS(rsp_file)
  observed_data <- readRDS(observed_file)

  # Read indicator dictionary
  dict <- read_csv("domains/cfsr/extraction/cfsr_round4_indicators_dictionary.csv",
                   show_col_types = FALSE)

  # Return list
  list(
    state = state_data,
    rsp = rsp_data,
    observed = observed_data,
    dictionary = dict
  )
}


#' Generate Indicator Talking Points
#'
#' Creates data-driven bullet points for an indicator
#'
#' @param ind_data Data frame. Filtered indicator data for one indicator
#' @param state_code Character. State code (e.g., "md")
#'
#' @return Character vector of bullet points
#'
#' @examples
#' bullets <- generate_indicator_talking_points(entry_rate_data, "md")
#'
generate_indicator_talking_points <- function(ind_data, state_code) {
  # Get state name
  state_name <- state_code_to_name(toupper(state_code))

  # Extract values
  performance <- ind_data$performance[1]
  rank <- ind_data$state_rank[1]
  total_states <- ind_data$reporting_states[1]
  national_std <- ind_data$national_standard[1]
  format_type <- ind_data$format[1]
  decimal_prec <- ind_data$decimal_precision[1]
  numerator <- ind_data$numerator[1]
  denominator <- ind_data$denominator[1]
  direction <- ind_data$direction_desired[1]

  # Format performance value
  if (format_type == "percent") {
    perf_display <- glue("{round(performance * 100, decimal_prec)}%")
  } else {
    scale_val <- ind_data$scale[1]
    scale_label <- case_when(
      scale_val == 1000 ~ "per 1,000",
      scale_val == 100000 ~ "per 100,000",
      TRUE ~ ""
    )
    perf_display <- glue("{round(performance, decimal_prec)} {scale_label}")
  }

  # Start bullet list
  bullets <- c(
    glue("{state_name} ranks {rank} of {total_states} reporting states"),
    glue("Performance: {perf_display}")
  )

  # Add national standard comparison (if applicable)
  if (!is.na(national_std) && national_std != "" && !is.na(performance) && !is.na(direction)) {
    nat_std_num <- as.numeric(national_std)

    if (format_type == "percent") {
      nat_std_display <- glue("{nat_std_num}%")
      diff_value <- (performance * 100) - nat_std_num
      diff_direction <- if (diff_value > 0) "above" else "below"
      diff_abs <- abs(diff_value)
      std_text <- glue("{round(diff_abs, decimal_prec)}% {diff_direction} national standard of {nat_std_display}")
    } else {
      diff_value <- performance - nat_std_num
      diff_direction <- if (diff_value > 0) "above" else "below"
      std_text <- glue("{round(abs(diff_value), decimal_prec)} {diff_direction} national standard of {round(nat_std_num, decimal_prec)}")
    }

    # Determine if meeting standard
    meets_standard <- if (direction == "up") {
      if (format_type == "percent") {
        (performance * 100) >= nat_std_num
      } else {
        performance >= nat_std_num
      }
    } else {
      if (format_type == "percent") {
        (performance * 100) <= nat_std_num
      } else {
        performance <= nat_std_num
      }
    }

    bullets <- c(bullets, std_text)

    if (meets_standard) {
      bullets <- c(bullets, "Performance meets or exceeds national standard")
    } else {
      bullets <- c(bullets, "Performance below national standard")
    }
  }

  # Add population context
  if (!is.na(numerator) && !is.na(denominator)) {
    num_fmt <- format(round(numerator), big.mark = ",")
    denom_fmt <- format(round(denominator), big.mark = ",")
    pop_text <- glue("Based on {num_fmt} events among {denom_fmt} children")
    bullets <- c(bullets, pop_text)
  }

  return(bullets)
}


#' Build Presentation Skeleton
#'
#' Creates basic presentation structure with title and CFSR background slides
#'
#' @param state Character. State code (e.g., "md")
#' @param period Character. Profile period (e.g., "2025_02")
#'
#' @return officer ppt object
#'
#' @examples
#' ppt <- build_presentation_skeleton("md", "2025_02")
#'
build_presentation_skeleton <- function(state, period) {
  # Read template (use .pptx version)
  template_path <- "docs/cfsr_presentation_template.pptx"
  if (!file.exists(template_path)) {
    stop(glue("Template not found: {template_path}"))
  }

  ppt <- read_pptx(template_path)

  # Get state name
  state_name <- state_code_to_name(toupper(state))

  # Add title slide
  ppt <- add_slide(ppt, layout = "Title Slide")
  ppt <- ph_with(ppt, value = glue("{state_name} CFSR Profile"),
                 location = ph_location_label(ph_label = "Title 1"))
  ppt <- ph_with(ppt, value = glue("Data Profile Period: {make_period_meaningful(period)}"),
                 location = ph_location_label(ph_label = "Subtitle 2"))

  # Add CFSR background slide: "CFSR Round 4 Profile"
  ppt <- add_slide(ppt, layout = "Title and Content")
  ppt <- ph_with(ppt, value = "CFSR Round 4 Profile",
                 location = ph_location_label(ph_label = "Title 1"))

  # Add bullets (4 bullets explaining CFSR profiles)
  bullets <- c(
    "Children's Bureau provides CFSR Round 4 Data Profiles every 6 months",
    "Shows your state's risk-standardized performance (RSP) and observed performance",
    "RSP is observed performance but with risk-adjustment",
    "RSP is compared to the national performance to see if performance is statistically better, worse, or no different than national performance"
  )

  # Create unordered list
  bullet_block <- unordered_list(
    level_list = rep(1, length(bullets)),  # All level 1 bullets
    str_list = bullets
  )

  ppt <- ph_with(ppt, value = bullet_block,
                 location = ph_location_label(ph_label = "Content Placeholder 2"))

  return(ppt)
}


#' Add Summary Slides
#'
#' Adds section header and summary screenshot placeholders
#'
#' @param ppt officer ppt object
#' @param data List. CFSR data from load_cfsr_data()
#' @param state Character. State code
#' @param period Character. Profile period
#'
#' @return officer ppt object
#'
#' @examples
#' ppt <- add_summary_slides(ppt, data, "md", "2025_02")
#'
add_summary_slides <- function(ppt, data, state, period) {
  # Section header
  ppt <- add_slide(ppt, layout = "Section Header")
  ppt <- ph_with(ppt, value = "CFSR Performance Summary",
                 location = ph_location_label(ph_label = "Title 1"))

  # Summary app screenshot placeholder (Top Banner layout for full-width)
  ppt <- add_slide(ppt, layout = "Top Banner with Picture")
  ppt <- ph_with(ppt, value = "Overall Performance Summary",
                 location = ph_location_label(ph_label = "Title 1"))
  ppt <- ph_with(ppt,
                 value = glue("[INSERT SCREENSHOT: Summary App]\n\n",
                              "URL: http://localhost:3840/?state={state}&profile={period}"),
                 location = ph_location_label(ph_label = "Picture Placeholder 2"))

  # RSP overview placeholder (Side Panel layout)
  ppt <- add_slide(ppt, layout = "Side Panel with Picture")
  ppt <- ph_with(ppt, value = "Risk-Standardized Performance Overview",
                 location = ph_location_label(ph_label = "Title 1"))
  ppt <- ph_with(ppt,
                 value = glue("[INSERT SCREENSHOT: RSP KPI Cards]\n\n",
                              "URL: http://localhost:3840/rsp?state={state}&profile={period}"),
                 location = ph_location_label(ph_label = "Picture Placeholder 2"))

  # Observed overview placeholder (Side Panel layout)
  ppt <- add_slide(ppt, layout = "Side Panel with Picture")
  ppt <- ph_with(ppt, value = "Observed Performance Overview",
                 location = ph_location_label(ph_label = "Title 1"))
  ppt <- ph_with(ppt,
                 value = glue("[INSERT SCREENSHOT: Observed KPI Cards]\n\n",
                              "URL: http://localhost:3840/observed?state={state}&profile={period}"),
                 location = ph_location_label(ph_label = "Picture Placeholder 2"))

  return(ppt)
}


#' Add Indicator Slides
#'
#' Adds section header and one slide per indicator with talking points and screenshot placeholder
#'
#' @param ppt officer ppt object
#' @param data List. CFSR data from load_cfsr_data()
#' @param state Character. State code
#' @param period Character. Profile period
#'
#' @return officer ppt object
#'
#' @examples
#' ppt <- add_indicator_slides(ppt, data, "md", "2025_02")
#'
add_indicator_slides <- function(ppt, data, state, period) {
  # Section header
  ppt <- add_slide(ppt, layout = "Section Header")
  ppt <- ph_with(ppt, value = "Individual Indicators",
                 location = ph_location_label(ph_label = "Title 1"))

  # Get 8 indicators (sorted by indicator_sort column)
  indicators <- data$dictionary %>%
    arrange(indicator_sort) %>%
    pull(indicator)

  # Add slide for each indicator
  for (indicator_name in indicators) {
    # Filter data for this indicator
    ind_data <- data$state %>% filter(indicator == indicator_name)

    # Skip if no data
    if (nrow(ind_data) == 0) {
      warning(glue("No data found for indicator: {indicator_name}"))
      next
    }

    # Add Side Panel with Picture slide
    ppt <- add_slide(ppt, layout = "Side Panel with Picture")

    # Add title (use indicator_short)
    ppt <- ph_with(ppt, value = ind_data$indicator_short[1],
                   location = ph_location_label(ph_label = "Title 1"))

    # Add screenshot placeholder (picture on right)
    indicator_encoded <- URLencode(indicator_name, reserved = TRUE)
    ppt <- ph_with(ppt,
                   value = glue("[INSERT SCREENSHOT: {indicator_name} - By State chart]\n\n",
                                "URL: http://localhost:3840/measures?indicator={indicator_encoded}&state={state}&profile={period}"),
                   location = ph_location_label(ph_label = "Picture Placeholder 2"))

    # Generate and add talking points (body content on left panel)
    bullets <- generate_indicator_talking_points(ind_data, state)

    bullet_block <- unordered_list(
      level_list = rep(1, length(bullets)),
      str_list = bullets
    )

    ppt <- ph_with(ppt, value = bullet_block,
                   location = ph_location_label(ph_label = "Text Placeholder 3"))
  }

  return(ppt)
}


#' Save Presentation
#'
#' Saves presentation to state-specific directory
#'
#' @param ppt officer ppt object
#' @param state Character. State code
#' @param period Character. Profile period
#'
#' @return Character. Full path to saved file
#'
#' @examples
#' file_path <- save_presentation(ppt, "md", "2025_02")
#'
save_presentation <- function(ppt, state, period) {
  # Build output path: states/{state}/cfsr/presentations/{period}/
  output_dir <- glue("states/{state}/cfsr/presentations/{period}")

  # Create directory if needed
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    message(glue("Created directory: {output_dir}"))
  }

  # Generate filename
  state_upper <- toupper(state)
  filename <- glue("{state_upper}_CFSR_Presentation_{period}.pptx")
  output_path <- file.path(output_dir, filename)

  # Save
  print(ppt, target = output_path)

  message(glue("Presentation saved to: {output_path}"))
  return(output_path)
}


#' Generate CFSR Presentation (Main Orchestrator)
#'
#' Generates complete PowerPoint presentation from CFSR profile data
#'
#' @param state Character. State code (e.g., "md", "ky")
#' @param period Character. Profile period (e.g., "2025_02")
#'
#' @return Character. Full path to generated presentation
#'
#' @examples
#' generate_cfsr_presentation("md", "2025_02")
#' generate_cfsr_presentation("ky", "2025_02")
#'
#' @export
generate_cfsr_presentation <- function(state, period) {
  message(glue("====================================="))
  message(glue("Generating CFSR presentation for {toupper(state)} - {period}"))
  message(glue("====================================="))

  # Load data
  data <- load_cfsr_data(state, period)

  # Build skeleton
  ppt <- build_presentation_skeleton(state, period)
  message("✓ Built presentation skeleton (title + background slides)")

  # Add summary slides
  ppt <- add_summary_slides(ppt, data, state, period)
  message("✓ Added summary slides (3 slides with screenshot placeholders)")

  # Add indicator slides
  ppt <- add_indicator_slides(ppt, data, state, period)
  message(glue("✓ Added indicator slides ({nrow(data$dictionary)} indicators)"))

  # Save
  file_path <- save_presentation(ppt, state, period)

  message(glue("====================================="))
  message(glue("SUCCESS! Presentation complete"))
  message(glue("====================================="))

  return(file_path)
}
