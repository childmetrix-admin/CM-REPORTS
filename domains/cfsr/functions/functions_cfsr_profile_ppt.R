########################################
# CFSR Profile PowerPoint Generation
########################################
# Purpose: Generate PowerPoint presentations from CFSR profile data
# Inputs: State code, profile period; optional YAML talking points; Azure or local RDS
# Outputs: PowerPoint file with data-driven talking points and screenshot embeds

########################################
# LIBRARIES & CONFIGURATION ----
########################################

library(officer)   # PowerPoint manipulation
library(dplyr)     # Data manipulation
library(readr)     # CSV reading
library(tidyr)     # Data tidying
library(stringr)   # String manipulation
library(glue)      # String interpolation
library(yaml)      # Talking-point templates

# Public dashboard URLs for slide placeholders (override with CM_PUBLIC_*_URL in .env)
.cfsr_public_summary_base <- function() {
  sub("/$", "", Sys.getenv(
    "CM_PUBLIC_SUMMARY_URL",
    "https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io"
  ))
}
.cfsr_public_measures_base <- function() {
  sub("/$", "", Sys.getenv(
    "CM_PUBLIC_MEASURES_URL",
    "https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io"
  ))
}

.cfsr_use_local_rds <- function() {
  tolower(Sys.getenv("CFSR_PPT_USE_LOCAL_RDS", "")) %in% c("1", "true", "yes")
}

# Source shared utilities
source("shared/utils/state_utils.R")

# Source CFSR functions
source("domains/cfsr/functions/functions_cfsr_profile_shared.R")

# Screenshot stem helpers + capture_cfsr_screenshots()
source("domains/cfsr/functions/capture_screenshots.R")

if (!.cfsr_use_local_rds()) {
  source("domains/cfsr/extraction/paths.R")
} else {
  message("CFSR_PPT_USE_LOCAL_RDS is set — using local domains/cfsr/data/rds/ (Azure paths.R not loaded).")
}

########################################
# INTERNAL HELPERS ----
########################################

.cfsr_default_yaml_path <- function() {
  "domains/cfsr/content/cfsr_profile_talking_points.yml"
}

.cfsr_resolve_template_path <- function(state, template_path) {
  if (!is.null(template_path) && nzchar(template_path) && file.exists(template_path)) {
    return(template_path)
  }
  sl <- tolower(state)
  cand <- file.path("states", sl, "_assets", paste0(sl, "-presentation-template.pptx"))
  if (file.exists(cand)) {
    return(cand)
  }
  ky <- file.path("states", "ky", "_assets", "ky-presentation-template.pptx")
  if (file.exists(ky)) {
    return(ky)
  }
  stop(
    "No PowerPoint template found. Run: python domains/cfsr/scripts/build_presentation_template.py ",
    "or pass template_path= to build_presentation_skeleton()."
  )
}

.cfsr_require_layout <- function(ppt, layout) {
  if (!officer::has_layout(ppt, layout)) {
    ls <- officer::layout_summary(ppt)
    nm <- if (!is.null(ls$name)) ls$name else ls[[1]]
    stop("Layout '", layout, "' not in template. Available:\n", paste(unique(nm), collapse = ", "))
  }
}

.cfsr_substitute_placeholders <- function(template, vars) {
  if (length(template) == 0 || !nzchar(template)) {
    return(template)
  }
  out <- template
  for (nm in names(vars)) {
    pat <- paste0("{{", nm, "}}")
    val <- vars[[nm]]
    if (is.null(val)) {
      val <- ""
    } else {
      val <- as.character(val)
    }
    out <- gsub(pat, val, out, fixed = TRUE)
  }
  out
}

#' Build named list of placeholders for YAML talking points
#' @noRd
.cfsr_build_tp_vars <- function(ind_data, state_code) {
  state_name <- state_code_to_name(toupper(state_code))

  performance <- ind_data$performance[1]
  rank <- ind_data$state_rank[1]
  total_states <- ind_data$reporting_states[1]
  national_std <- ind_data$national_standard[1]
  format_type <- ind_data$format[1]
  decimal_prec <- ind_data$decimal_precision[1]
  numerator <- ind_data$numerator[1]
  denominator <- ind_data$denominator[1]
  direction <- ind_data$direction_desired[1]
  src <- ind_data$source[1]
  if (is.na(src)) {
    src <- ""
  }

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

  nat_std_bullet <- ""
  meets_standard_text <- ""

  if (!is.na(national_std) && national_std != "" && !is.na(performance) && !is.na(direction)) {
    nat_std_num <- as.numeric(national_std)

    if (format_type == "percent") {
      nat_std_display <- glue("{nat_std_num}%")
      diff_value <- (performance * 100) - nat_std_num
      diff_direction <- if (diff_value > 0) "above" else "below"
      diff_abs <- abs(diff_value)
      nat_std_bullet <- as.character(glue(
        "{round(diff_abs, decimal_prec)}% {diff_direction} national standard of {nat_std_display}."
      ))
    } else {
      nat_std_display <- as.character(glue("{round(nat_std_num, decimal_prec)}"))
      diff_value <- performance - nat_std_num
      diff_direction <- if (diff_value > 0) "above" else "below"
      nat_std_bullet <- as.character(glue(
        "{round(abs(diff_value), decimal_prec)} {diff_direction} national standard of {nat_std_display}."
      ))
    }

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

    meets_standard_text <- if (meets_standard) {
      "Performance meets or exceeds national standard."
    } else {
      "Performance below national standard."
    }
  }

  num_den_bullet <- ""
  if (!is.na(numerator) && !is.na(denominator)) {
    num_fmt <- format(round(numerator), big.mark = ",")
    denom_fmt <- format(round(denominator), big.mark = ",")
    num_den_bullet <- glue("Based on {num_fmt} events among {denom_fmt} children.")
  }

  list(
    STATE_NAME = state_name,
    RANK = as.character(rank),
    TOTAL_STATES = as.character(total_states),
    PERF_DISPLAY = as.character(perf_display),
    NAT_STD_BULLET = as.character(nat_std_bullet),
    MEETS_STANDARD_TEXT = as.character(meets_standard_text),
    NUMERATOR = if (!is.na(numerator)) format(round(numerator), big.mark = ",") else "",
    DENOMINATOR = if (!is.na(denominator)) format(round(denominator), big.mark = ",") else "",
    NUM_DEN_BULLET = as.character(num_den_bullet),
    SOURCE = as.character(src),
    SOURCE_BULLET = if (nzchar(src)) paste0("Source: ", src) else ""
  )
}

#' Render bullet strings from YAML templates + substitution map
#' @noRd
render_bullets_from_yaml <- function(indicator_name,
                                     vars,
                                     yaml_path = NULL) {
  yp <- if (is.null(yaml_path) || !nzchar(yaml_path)) {
    .cfsr_default_yaml_path()
  } else {
    yaml_path
  }
  if (!file.exists(yp)) {
    stop("Talking points YAML not found: ", yp)
  }
  tpl <- yaml::yaml.load_file(yp)

  ind_block <- tpl$indicators[[indicator_name]]
  bullets_tpl <- if (!is.null(ind_block) && !is.null(ind_block$bullets)) {
    ind_block$bullets
  } else {
    tpl$default_bullets
  }

  if (is.null(bullets_tpl)) {
    return(character())
  }

  out <- vapply(bullets_tpl, function(line) {
    .cfsr_substitute_placeholders(as.character(line), vars)
  }, character(1))

  # Drop empty / whitespace-only lines
  out <- out[nzchar(trimws(out))]
  # Drop stray periods-only artifacts
  out <- out[!grepl("^[.]$", trimws(out))]
  out
}

########################################
# FUNCTIONS ----
########################################

#' Load CFSR Data for PowerPoint Generation
#'
#' Reads RDS files and indicator dictionary for specified state/period.
#' Uses Azure Blob (\code{load_rds_data}) unless env \code{CFSR_PPT_USE_LOCAL_RDS} is true.
#'
#' @param state Character. State code (e.g., "md", "ky")
#' @param period Character. Profile period (e.g., "2025_02")
#'
#' @return List with state, rsp, observed data and dictionary
#'
load_cfsr_data <- function(state, period) {
  if (missing(state) || missing(period)) {
    stop("Both state and period are required")
  }

  state_upper <- toupper(state)
  sl <- tolower(state)

  message(glue("Loading data for {state_upper} - {period}"))

  if (.cfsr_use_local_rds()) {
    state_file <- glue("domains/cfsr/data/rds/{sl}/{period}/{state_upper}_cfsr_profile_state_{period}.rds")
    rsp_file <- glue("domains/cfsr/data/rds/{sl}/{period}/{state_upper}_cfsr_profile_rsp_{period}.rds")
    observed_file <- glue("domains/cfsr/data/rds/{sl}/{period}/{state_upper}_cfsr_profile_observed_{period}.rds")
    for (f in c(state_file, rsp_file, observed_file)) {
      if (!file.exists(f)) {
        stop("Local RDS file not found: ", f)
      }
    }
    state_data <- readRDS(state_file)
    rsp_data <- readRDS(rsp_file)
    observed_data <- readRDS(observed_file)
  } else {
    state_data <- load_rds_data(build_rds_path(sl, period, "state"))
    rsp_data <- load_rds_data(build_rds_path(sl, period, "rsp"))
    observed_data <- load_rds_data(build_rds_path(sl, period, "observed"))
  }

  dict <- read_csv(
    "domains/cfsr/extraction/cfsr_round4_indicators_dictionary.csv",
    show_col_types = FALSE
  )

  list(
    state = state_data,
    rsp = rsp_data,
    observed = observed_data,
    dictionary = dict
  )
}


#' Generate Indicator Talking Points
#'
#' Creates data-driven bullet points from YAML templates (fixed wording + substitutions).
#'
#' @param ind_data Data frame. Filtered indicator data for one indicator (state row)
#' @param state_code Character. State code (e.g., "md")
#' @param yaml_path Optional path to YAML; defaults to package content file
#'
#' @return Character vector of bullet points
#'
generate_indicator_talking_points <- function(ind_data, state_code, yaml_path = NULL) {
  vars <- .cfsr_build_tp_vars(ind_data, state_code)
  ind_name <- ind_data$indicator[1]
  bullets <- render_bullets_from_yaml(ind_name, vars, yaml_path)

  yp <- if (is.null(yaml_path) || !nzchar(yaml_path)) {
    .cfsr_default_yaml_path()
  } else {
    yaml_path
  }
  if (file.exists(yp)) {
    tpl <- yaml::yaml.load_file(yp)
    ctx <- tpl$indicators[[ind_name]]$context
    if (!is.null(ctx) && nzchar(ctx)) {
      ctx_line <- .cfsr_substitute_placeholders(ctx, vars)
      if (nzchar(trimws(ctx_line))) {
        bullets <- c(bullets, ctx_line)
      }
    }
  }

  bullets
}


#' Build Presentation Skeleton
#'
#' @param state Character. State code (e.g., "md")
#' @param period Character. Profile period (e.g., "2025_02")
#' @param template_path Optional path to .pptx template; defaults per-state asset then KY
#'
#' @return officer ppt object
#'
build_presentation_skeleton <- function(state, period, template_path = NULL) {
  tp <- .cfsr_resolve_template_path(state, template_path)
  ppt <- read_pptx(tp)

  state_name <- state_code_to_name(toupper(state))

  .cfsr_require_layout(ppt, "Title Slide")
  ppt <- add_slide(ppt, layout = "Title Slide")
  brand_title <- fp_text(color = "#0f4c75", font.size = 32, bold = TRUE)
  brand_sub <- fp_text(color = "#0e9ba4", font.size = 18)
  ppt <- ph_with(
    ppt,
    value = fpar(ftext(glue("{state_name} CFSR Profile"), prop = brand_title)),
    location = ph_location_label(ph_label = "Title 1")
  )
  ppt <- ph_with(
    ppt,
    value = fpar(ftext(glue("Data Profile Period: {make_period_meaningful(period)}"), prop = brand_sub)),
    location = ph_location_label(ph_label = "Subtitle 2")
  )

  .cfsr_require_layout(ppt, "Title and Content")
  ppt <- add_slide(ppt, layout = "Title and Content")
  ppt <- ph_with(
    ppt,
    value = "CFSR Round 4 Profile",
    location = ph_location_label(ph_label = "Title 1")
  )

  bg_bullets <- c(
    "Children's Bureau provides CFSR Round 4 Data Profiles every 6 months",
    "Shows your state's risk-standardized performance (RSP) and observed performance",
    "RSP is observed performance but with risk-adjustment",
    "RSP is compared to the national performance to see if performance is statistically better, worse, or no different than national performance"
  )
  bullet_block <- unordered_list(
    level_list = rep(1, length(bg_bullets)),
    str_list = bg_bullets
  )
  ppt <- ph_with(
    ppt,
    value = bullet_block,
    location = ph_location_label(ph_label = "Content Placeholder 2")
  )

  ppt
}


.cfsr_ph_image_or_text <- function(ppt, path, placeholder_text, location) {
  if (!is.null(path) && nzchar(path) && file.exists(path)) {
    ph_with(
      ppt,
      value = external_img(path, width = 7.5, height = 4.2),
      location = location
    )
  } else {
    ph_with(ppt, value = as.character(placeholder_text), location = location)
  }
}


#' Add Summary Slides
#'
#' @param ppt officer ppt object
#' @param data List from load_cfsr_data()
#' @param state,period State code and profile period
#' @param screenshot_dir Directory with PNG captures (optional)
#' @param yaml_path Optional talking points YAML path
#'
add_summary_slides <- function(ppt, data, state, period,
                               screenshot_dir = NULL) {
  sl <- tolower(state)
  if (is.null(screenshot_dir)) {
    screenshot_dir <- file.path("states", sl, "cfsr", "presentations", period, "screenshots")
  }

  .cfsr_require_layout(ppt, "Section Header")
  ppt <- add_slide(ppt, layout = "Section Header")
  ppt <- ph_with(
    ppt,
    value = "CFSR Performance Summary",
    location = ph_location_label(ph_label = "Title 1")
  )

  .cfsr_require_layout(ppt, "Title and Content")

  # Summary app
  ppt <- add_slide(ppt, layout = "Title and Content")
  ppt <- ph_with(
    ppt,
    value = "Overall Performance Summary",
    location = ph_location_label(ph_label = "Title 1")
  )
  sum_png <- file.path(screenshot_dir, paste0(sl, "_summary_app_", period, ".png"))
  ppt <- .cfsr_ph_image_or_text(
    ppt,
    sum_png,
    glue(
      "[INSERT SCREENSHOT: Summary App]\n\nURL: {.cfsr_public_summary_base()}/?state={toupper(state)}&profile={period}&export=true"
    ),
    location = ph_location_label(ph_label = "Content Placeholder 2")
  )

  # RSP overview
  ppt <- add_slide(ppt, layout = "Title and Content")
  ppt <- ph_with(
    ppt,
    value = "Risk-Standardized Performance Overview",
    location = ph_location_label(ph_label = "Title 1")
  )
  rsp_png <- file.path(screenshot_dir, paste0(sl, "_rsp_overview_", period, ".png"))
  ppt <- .cfsr_ph_image_or_text(
    ppt,
    rsp_png,
    glue(
      "[INSERT SCREENSHOT: RSP KPI Cards]\n\nURL: {.cfsr_public_measures_base()}/?state={toupper(state)}&profile={period}&tab=overview&overview_tab=rsp&export=true"
    ),
    location = ph_location_label(ph_label = "Content Placeholder 2")
  )

  # Observed overview
  ppt <- add_slide(ppt, layout = "Title and Content")
  ppt <- ph_with(
    ppt,
    value = "Observed Performance Overview",
    location = ph_location_label(ph_label = "Title 1")
  )
  obs_png <- file.path(screenshot_dir, paste0(sl, "_observed_overview_", period, ".png"))
  ppt <- .cfsr_ph_image_or_text(
    ppt,
    obs_png,
    glue(
      "[INSERT SCREENSHOT: Observed KPI Cards]\n\nURL: {.cfsr_public_measures_base()}/?state={toupper(state)}&profile={period}&tab=overview&overview_tab=obs&export=true"
    ),
    location = ph_location_label(ph_label = "Content Placeholder 2")
  )

  ppt
}


#' Add Indicator Slides
#'
add_indicator_slides <- function(ppt, data, state, period,
                                 screenshot_dir = NULL,
                                 yaml_path = NULL) {
  sl <- tolower(state)
  if (is.null(screenshot_dir)) {
    screenshot_dir <- file.path("states", sl, "cfsr", "presentations", period, "screenshots")
  }

  .cfsr_require_layout(ppt, "Section Header")
  ppt <- add_slide(ppt, layout = "Section Header")
  ppt <- ph_with(
    ppt,
    value = "Individual Indicators",
    location = ph_location_label(ph_label = "Title 1")
  )

  indicators <- data$dictionary %>%
    arrange(indicator_sort) %>%
    pull(indicator)

  .cfsr_require_layout(ppt, "Two Content")

  for (indicator_name in indicators) {
    inm <- indicator_name
    ind_data <- data$state %>%
      filter(indicator == inm, dimension == "State")

    if (nrow(ind_data) == 0) {
      ind_data <- data$state %>% filter(indicator == inm)
    }
    if (nrow(ind_data) == 0) {
      warning(glue("No data found for indicator: {indicator_name}"))
      next
    }

    ppt <- add_slide(ppt, layout = "Two Content")
    ppt <- ph_with(
      ppt,
      value = ind_data$indicator_short[1],
      location = ph_location_label(ph_label = "Title 1")
    )

    stem <- .cfsr_indicator_screenshot_stem(indicator_name)
    ind_png <- file.path(screenshot_dir, paste0(sl, "_", stem, "_", period, ".png"))

    tab_q <- .cfsr_measures_tab_for_indicator(indicator_name)
    meas_url <- glue(
      "{.cfsr_public_measures_base()}/?state={toupper(state)}&profile={period}",
      "&tab={tab_q}&export=true"
    )
    ppt <- .cfsr_ph_image_or_text(
      ppt,
      ind_png,
      glue(
        "[INSERT SCREENSHOT: By State chart]\n\n{indicator_name}\n\nURL: {meas_url}"
      ),
      location = ph_location_label(ph_label = "Content Placeholder 3")
    )

    bullets <- generate_indicator_talking_points(ind_data, state, yaml_path)
    bullet_block <- unordered_list(
      level_list = rep(1, length(bullets)),
      str_list = bullets
    )
    ppt <- ph_with(
      ppt,
      value = bullet_block,
      location = ph_location_label(ph_label = "Content Placeholder 2")
    )
  }

  ppt
}


#' Closing slide (summary, contact, acknowledgments)
#' @noRd
add_closing_slide <- function(ppt, state, period) {
  .cfsr_require_layout(ppt, "Title and Content")
  state_name <- state_code_to_name(toupper(state))
  ppt <- add_slide(ppt, layout = "Title and Content")
  ppt <- ph_with(
    ppt,
    value = glue("Summary — {state_name}"),
    location = ph_location_label(ph_label = "Title 1")
  )
  closing <- c(
    glue("This deck summarizes observed CFSR profile indicators for {make_period_meaningful(period)}."),
    "Review each indicator slide with agency leadership before external distribution.",
    "Contact: kurt@childmetrix.com",
    "Acknowledgments: Children's Bureau CFSR Round 4 Data Profile; ChildMetrix."
  )
  ppt <- ph_with(
    ppt,
    value = unordered_list(level_list = rep(1, length(closing)), str_list = closing),
    location = ph_location_label(ph_label = "Content Placeholder 2")
  )
  ppt
}


#' Save Presentation
#'
save_presentation <- function(ppt, state, period) {
  output_dir <- glue("states/{tolower(state)}/cfsr/presentations/{period}")
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    message(glue("Created directory: {output_dir}"))
  }

  state_upper <- toupper(state)
  filename <- glue("{state_upper}_CFSR_Presentation_{period}.pptx")
  output_path <- file.path(output_dir, filename)

  print(ppt, target = output_path)
  message(glue("Presentation saved to: {output_path}"))
  output_path
}


#' Generate CFSR Presentation (Main Orchestrator)
#'
#' @param state Character. State code (e.g., "md", "ky")
#' @param period Character. Profile period (e.g., "2025_02")
#' @param auto_capture If TRUE, run \code{capture_cfsr_screenshots()} before building slides
#' @param template_path Optional .pptx template path
#' @param yaml_path Optional talking points YAML path
#' @param screenshot_dir Override directory for PNG inputs
#'
#' @return Character. Full path to saved presentation
#'
generate_cfsr_presentation <- function(state,
                                       period,
                                       auto_capture = FALSE,
                                       template_path = NULL,
                                       yaml_path = NULL,
                                       screenshot_dir = NULL) {
  message(glue("====================================="))
  message(glue("Generating CFSR presentation for {toupper(state)} - {period}"))
  message(glue("====================================="))

  sl <- tolower(state)
  if (is.null(screenshot_dir)) {
    screenshot_dir <- file.path("states", sl, "cfsr", "presentations", period, "screenshots")
  }

  if (isTRUE(auto_capture)) {
    dir.create(screenshot_dir, recursive = TRUE, showWarnings = FALSE)
    message("Capturing screenshots with webshot2 …")
    capture_cfsr_screenshots(state, period, screenshot_dir)
  }

  data <- load_cfsr_data(state, period)

  ppt <- build_presentation_skeleton(state, period, template_path = template_path)
  message("Built presentation skeleton (title + background slides)")

  ppt <- add_summary_slides(ppt, data, state, period,
    screenshot_dir = screenshot_dir
  )
  message("Added summary slides")

  ppt <- add_indicator_slides(ppt, data, state, period,
    screenshot_dir = screenshot_dir,
    yaml_path = yaml_path
  )
  message(glue("Added indicator slides ({nrow(data$dictionary)} indicators)"))

  ppt <- add_closing_slide(ppt, state, period)
  message("Added closing slide")

  file_path <- save_presentation(ppt, state, period)

  message(glue("====================================="))
  message("SUCCESS! Presentation complete")
  message(glue("====================================="))

  file_path
}
