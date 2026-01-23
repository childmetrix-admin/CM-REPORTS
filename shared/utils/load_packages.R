# load_packages.R - Package loading utilities
# Cross-domain utility for all ChildMetrix projects

#' Load R packages with automatic installation if missing
#'
#' @param packages Character vector of package names
#' @param quiet Suppress messages (default: FALSE)
#' @return Invisible NULL
#' @export
load_packages <- function(packages, quiet = FALSE) {

  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE, quietly = quiet)) {
      if (!quiet) {
        message("Installing missing package: ", pkg)
      }

      install.packages(pkg, repos = "https://cloud.r-project.org")

      if (!require(pkg, character.only = TRUE, quietly = quiet)) {
        stop("Failed to install package: ", pkg, call. = FALSE)
      }
    }
  }

  invisible(NULL)
}

#' Load core tidyverse packages used across all projects
#'
#' @param quiet Suppress messages (default: FALSE)
#' @export
load_core_packages <- function(quiet = FALSE) {
  core_pkgs <- c(
    "dplyr",      # Data manipulation
    "tidyr",      # Data tidying
    "readr",      # CSV reading
    "stringr",    # String manipulation
    "lubridate",  # Date handling
    "purrr"       # Functional programming
  )

  load_packages(core_pkgs, quiet = quiet)
}

#' Load packages for data extraction work
#'
#' Includes tidyverse + data import packages
#'
#' @param quiet Suppress messages (default: FALSE)
#' @export
load_extraction_packages <- function(quiet = FALSE) {
  extraction_pkgs <- c(
    "tidyverse",  # All tidyverse packages
    "pdftools",   # PDF parsing
    "readxl",     # Excel reading
    "lubridate",  # Date handling
    "janitor"     # Data cleaning
  )

  load_packages(extraction_pkgs, quiet = quiet)
}

#' Load packages for Shiny apps
#'
#' @param quiet Suppress messages (default: FALSE)
#' @export
load_shiny_packages <- function(quiet = FALSE) {
  shiny_pkgs <- c(
    "shiny",
    "tidyverse",
    "plotly",
    "DT",
    "shinydashboard"
  )

  load_packages(shiny_pkgs, quiet = quiet)
}
