#####################################
#####################################
# CFSR Apps Launcher ----
#####################################
#####################################

# Purpose: Launch both consolidated CFSR Shiny apps (app_measures and app_summary)
# on separate ports for embedding in the CFSR frontend.
#
# Inputs: None (hardcoded paths to app directories)
# Outputs: Two running Shiny apps on ports 3838 and 3840

#####################################
# NOTES ----
#####################################

# This launcher starts two Shiny apps:
# 1. app_summary (port 3840) - Performance summary KPI cards
# 2. app_measures (port 3838) - Measures tab with RSP, Observed Overview, and Indicator details
#
# app_summary runs in background using callr::r_bg()
# app_measures runs in foreground (blocking) to keep console alive
#
# Both apps are embedded via iframes in the CFSR frontend (app.html)
# When app_measures is stopped (Ctrl+C), app_summary is automatically killed

#####################################
# LIBRARIES & CONFIGURATION ----
#####################################

# Check/install callr for background process management
if (!requireNamespace("callr", quietly = TRUE)) {
  install.packages("callr")
}

library(callr)

# App directories
app_summary_dir <- "D:/repo_childmetrix/cm-reports/domains/cfsr/apps/app_summary"
app_measures_dir <- "D:/repo_childmetrix/cm-reports/domains/cfsr/apps/app_measures"

# Check if apps exist
if (!dir.exists(app_summary_dir)) {
  stop("app_summary directory not found at: ", app_summary_dir)
}
if (!dir.exists(app_measures_dir)) {
  stop("app_measures directory not found at: ", app_measures_dir)
}

#####################################
# LAUNCH APPS ----
#####################################

cat("========================================\n")
cat("Launching CFSR Shiny Apps\n")
cat("========================================\n\n")

# --------------------------------------
# Launch app_summary in background (port 3840) ----
# --------------------------------------

cat("Starting app_summary on port 3840 (background)...\n")
cat("  Directory: ", app_summary_dir, "\n")
cat("  URL: http://localhost:3840\n\n")

# Start app_summary in background process
summary_process <- r_bg(
  function(app_dir) {
    # Load required packages first
    suppressPackageStartupMessages({
      library(shiny)
      library(shinydashboard)
      library(dplyr)
      library(ggplot2)
      library(plotly)
      library(DT)
    })

    # Source global.R to load all functions into environment
    source(file.path(app_dir, "global.R"))

    # Launch app
    shiny::runApp(
      app_dir,
      port = 3840,
      launch.browser = FALSE
    )
  },
  args = list(app_dir = app_summary_dir),
  supervise = TRUE
)

cat("✓ app_summary started (PID: ", summary_process$get_pid(), ")\n\n")

# Wait for app_summary to initialize
Sys.sleep(2)

# --------------------------------------
# Launch app_measures in foreground (port 3838) ----
# --------------------------------------

cat("Starting app_measures on port 3838 (foreground)...\n")
cat("  Directory: ", app_measures_dir, "\n")
cat("  URL: http://localhost:3838\n\n")

cat("✓ Both apps running. Access via main app.html portal.\n")
cat("  To stop: Press Ctrl+C or close R console\n\n")

# Load required packages for app_measures
if (!requireNamespace("shinydashboard", quietly = TRUE)) {
  cat("Installing shinydashboard package...\n")
  install.packages("shinydashboard")
}

suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(dplyr)
  library(ggplot2)
  library(plotly)
  library(DT)
})

# Source global.R to load all modules and functions into environment
cat("Loading app_measures environment...\n")
source(file.path(app_measures_dir, "global.R"))
cat("✓ Modules loaded\n\n")

# Launch app_measures (blocks until stopped)
shiny::runApp(
  app_measures_dir,
  port = 3838,
  launch.browser = FALSE  # Don't open browser - use app.html instead
)

#####################################
# CLEANUP ----
#####################################

# Kill app_summary when app_measures is stopped
cat("\n\nStopping app_summary...\n")
summary_process$kill()
cat("✓ Both apps stopped\n")
