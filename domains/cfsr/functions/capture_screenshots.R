# capture_screenshots.R — headless PNG captures of CFSR Shiny apps for PowerPoint decks
#
# Purpose: Save screenshots under states/{state}/cfsr/presentations/{period}/screenshots/
# Inputs: state, period, public app URLs (CM_PUBLIC_*_URL), optional webshot2 delay
# Outputs: PNG files named for functions_cfsr_profile_ppt.R embedding

.cfsr_capture_summary_base <- function() {
  sub("/$", "", Sys.getenv(
    "CM_PUBLIC_SUMMARY_URL",
    "https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io"
  ))
}

.cfsr_capture_measures_base <- function() {
  sub("/$", "", Sys.getenv(
    "CM_PUBLIC_MEASURES_URL",
    "https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io"
  ))
}

#' Map dictionary indicator string to screenshot filename stem (see presentation_screenshot_guide.md)
#' @noRd
.cfsr_indicator_screenshot_stem <- function(indicator_name) {
  if (startsWith(indicator_name, "Maltreatment in care")) {
    return("maltreatment_in_care")
  }
  if (startsWith(indicator_name, "Maltreatment recurrence")) {
    return("maltreatment_recurrence")
  }
  if (grepl("^Foster care entry rate", indicator_name)) {
    return("entry_rate")
  }
  if (grepl("^Permanency in 12 months for children entering care", indicator_name)) {
    return("perm12_entries")
  }
  if (grepl("12-23 months", indicator_name)) {
    return("perm12_12_23")
  }
  if (grepl("24 months or more", indicator_name)) {
    return("perm12_24")
  }
  if (startsWith(indicator_name, "Reentry to foster care")) {
    return("reentry")
  }
  if (startsWith(indicator_name, "Placement stability")) {
    return("placement_stability")
  }
  warning("Unknown indicator for screenshot stem: ", indicator_name)
  "indicator"
}

#' Build Measures app deep-link tab query for an indicator row
#' @noRd
.cfsr_measures_tab_for_indicator <- function(indicator_name) {
  if (startsWith(indicator_name, "Maltreatment in care")) {
    return("obs_maltreatment")
  }
  if (startsWith(indicator_name, "Maltreatment recurrence")) {
    return("obs_recurrence")
  }
  if (grepl("^Foster care entry rate", indicator_name)) {
    return("obs_entry_rate")
  }
  if (grepl("^Permanency in 12 months for children entering care", indicator_name)) {
    return("obs_perm12_entries")
  }
  if (grepl("12-23 months", indicator_name)) {
    return("obs_perm12_12_23")
  }
  if (grepl("24 months or more", indicator_name)) {
    return("obs_perm12_24")
  }
  if (startsWith(indicator_name, "Reentry to foster care")) {
    return("obs_reentry")
  }
  if (startsWith(indicator_name, "Placement stability")) {
    return("obs_placement")
  }
  "overview"
}

#' Capture CFSR dashboard screenshots for PPT embedding
#'
#' Requires packages \code{webshot2} and a Chrome/Chromium install discoverable by chromote.
#'
#' @param state Two-letter state code (e.g. \code{"md"}).
#' @param period Profile period \code{YYYY_MM}.
#' @param out_dir Directory for PNG files (typically \verb{states/{state}/cfsr/presentations/{period}/screenshots}).
#' @param delay Seconds to wait after load before capture (Plotly render).
#' @param vwidth,vheight Viewport size passed to \code{webshot2::webshot}.
#'
#' Configure chromote for Docker / Azure Container Instances (headless Chrome).
#' @noRd
.cfsr_configure_chromote_for_container <- function() {
  if (!requireNamespace("chromote", quietly = TRUE)) {
    return(invisible(NULL))
  }
  chrome_path <- Sys.getenv(
    "CHROMOTE_CHROME",
    Sys.getenv("GOOGLE_CHROME", "/usr/bin/google-chrome")
  )
  if (nzchar(chrome_path) && file.exists(chrome_path)) {
    Sys.setenv(GOOGLE_CHROME = chrome_path, CHROMOTE_CHROME = chrome_path)
  }
  tryCatch(
    {
      base_args <- tryCatch(
        chromote::default_chrome_args(),
        error = function(e) c("--headless=new", "--remote-debugging-port=0")
      )
      chromote::set_chrome_args(unique(c(
        base_args,
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--window-size=1200,800"
      )))
    },
    error = function(e) invisible(NULL)
  )
  invisible(NULL)
}

#' Capture CFSR dashboard screenshots for PPT embedding
#'
#' Uses viewport dimensions matched to Kurt's template placeholders:
#' - "Top Banner with Picture": 12.89 x 5.38 inches -> wide viewport
#' - "Side Panel with Picture": 8.67 x 7.05 inches -> more square viewport
#'
#' @return Invisibly, character vector of paths written (or skipped on failure).
#' @export
capture_cfsr_screenshots <- function(state,
                                     period,
                                     out_dir,
                                     delay = 8) {
  if (!requireNamespace("webshot2", quietly = TRUE)) {
    stop("Install webshot2 for automated screenshots: install.packages('webshot2')")
  }
  .cfsr_configure_chromote_for_container()

  st <- toupper(state)
  sl <- tolower(state)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  summ_base <- .cfsr_capture_summary_base()
  meas_base <- .cfsr_capture_measures_base()
  append_export <- function(url) {
    if (grepl("export=true", url, fixed = TRUE)) {
      return(url)
    }
    paste0(url, if (grepl("?", url, fixed = TRUE)) "&" else "?", "export=true")
  }

  written <- character()

  # Viewport dimensions matched to Kurt's template placeholders (at ~150 DPI for crisp images)
  # "Top Banner with Picture": 12.89 x 5.38 inches
  vwidth_wide <- 1934
  vheight_wide <- 807
  # "Side Panel with Picture": 8.67 x 7.05 inches (but wider viewport for full chart visibility)
  vwidth_panel <- 1300
  vheight_panel <- 1058

  # Summary app - uses "Top Banner with Picture" layout (wide)
  shots_wide <- list(
    list(
      path = file.path(out_dir, paste0(sl, "_summary_app_", period, ".png")),
      url = append_export(paste0(summ_base, "/?state=", st, "&profile=", period))
    )
  )

  # RSP and Observed overview - use "Side Panel with Picture" layout
  shots_panel <- list(
    list(
      path = file.path(out_dir, paste0(sl, "_rsp_overview_", period, ".png")),
      url = append_export(paste0(
        meas_base, "/?state=", st, "&profile=", period,
        "&tab=overview&overview_tab=rsp"
      ))
    ),
    list(
      path = file.path(out_dir, paste0(sl, "_observed_overview_", period, ".png")),
      url = append_export(paste0(
        meas_base, "/?state=", st, "&profile=", period,
        "&tab=overview&overview_tab=obs"
      ))
    )
  )

  # Indicator screenshots - use "Side Panel with Picture" layout
  dict <- read.csv(
    "domains/cfsr/extraction/cfsr_round4_indicators_dictionary.csv",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  indicators <- dict$indicator[order(dict$indicator_sort)]

  for (ind in indicators) {
    tab <- .cfsr_measures_tab_for_indicator(ind)
    stem <- .cfsr_indicator_screenshot_stem(ind)
    shots_panel <- c(shots_panel, list(list(
      path = file.path(out_dir, paste0(sl, "_", stem, "_", period, ".png")),
      url = paste0(meas_base, "/?state=", st, "&profile=", period, "&tab=", tab, "&export=true#shiny-tab-", tab)
    )))
  }

  # Capture wide screenshots (summary app)
  for (sh in shots_wide) {
    message("Capturing (wide): ", basename(sh$path))
    tryCatch(
      {
        webshot2::webshot(
          url = sh$url,
          file = sh$path,
          vwidth = vwidth_wide,
          vheight = vheight_wide,
          delay = delay
        )
        written <- c(written, sh$path)
      },
      error = function(e) {
        warning("webshot failed for ", sh$url, " — ", conditionMessage(e))
      }
    )
  }

  # Capture panel screenshots (RSP, Observed, indicators)
  for (sh in shots_panel) {
    message("Capturing (panel): ", basename(sh$path))
    tryCatch(
      {
        webshot2::webshot(
          url = sh$url,
          file = sh$path,
          vwidth = vwidth_panel,
          vheight = vheight_panel,
          delay = delay
        )
        written <- c(written, sh$path)
      },
      error = function(e) {
        warning("webshot failed for ", sh$url, " — ", conditionMessage(e))
      }
    )
  }

  invisible(written)
}
