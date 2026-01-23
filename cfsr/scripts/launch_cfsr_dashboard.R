# Launch CFSR Dashboard (All Apps)
#
# This script starts ALL CFSR Shiny apps in background processes:
#   - National comparison app on http://localhost:3838
#   - RSP (Risk-Standardized Performance) app on http://localhost:3839
#   - Summary (Performance Summary) app on http://localhost:3840
#   - Observed Performance app on http://localhost:3841
#
# INSTRUCTIONS:
# 1. Open this file in R or RStudio
# 2. Click "Source" or press Ctrl+Shift+S (RStudio)
# 3. Keep R running - don't close this window!
# 4. Open your browser to: file:///D:/repo_childmetrix/cm-reports/app.html
#
# To stop: Close this R session (all apps will terminate)

# Load required packages
if (!require("shiny")) {
  install.packages("shiny")
  library(shiny)
}

if (!require("callr")) {
  install.packages("callr")
  library(callr)
}

# Detect monorepo root
detect_monorepo_root <- function() {
  current <- getwd()
  while (current != dirname(current)) {
    if (file.exists(file.path(current, "CLAUDE.md")) ||
        file.exists(file.path(current, ".git"))) {
      return(current)
    }
    current <- dirname(current)
  }
  root <- Sys.getenv("CM_REPORTS_ROOT", "d:/repo_childmetrix/cm-reports")
  return(root)
}
monorepo_root <- detect_monorepo_root()

# Path to the CFSR dashboard apps (cfsr/apps/ location)
app_national_path <- file.path(monorepo_root, "cfsr/apps/app_national")
app_rsp_path <- file.path(monorepo_root, "cfsr/apps/app_rsp")
app_summary_path <- file.path(monorepo_root, "cfsr/apps/app_summary")
app_observed_path <- file.path(monorepo_root, "cfsr/apps/app_observed")
data_path <- file.path(monorepo_root, "cfsr/data/rds")

# Check if app directories exist
if (!dir.exists(app_national_path)) {
  stop("National app directory not found: ", app_national_path)
}
if (!dir.exists(app_rsp_path)) {
  stop("RSP app directory not found: ", app_rsp_path)
}
if (!dir.exists(app_summary_path)) {
  stop("Summary app directory not found: ", app_summary_path)
}
if (!dir.exists(app_observed_path)) {
  stop("Observed Performance app directory not found: ", app_observed_path)
}

# Check if data directory exists
if (!dir.exists(data_path)) {
  warning("Data directory not found: ", data_path,
          "\n\nYou may need to run cfsr-profile.R first to generate data.")
}

# Launch banner
cat("\n")
cat("================================================================\n")
cat("  CFSR Dashboard - Starting All Apps...\n")
cat("================================================================\n\n")

# Function to run app in background
run_app_background <- function(app_path, port) {
  callr::r_bg(
    function(path, p) {
      shiny::runApp(path, port = p, launch.browser = FALSE)
    },
    args = list(path = app_path, p = port),
    supervise = TRUE
  )
}

# Start RSP app in background (port 3839)
cat("Starting RSP app on port 3839...")
rsp_process <- run_app_background(app_rsp_path, 3839)
Sys.sleep(2)  # Give it time to start
if (rsp_process$is_alive()) {
  cat(" OK\n")
} else {
  cat(" FAILED\n")
  cat("RSP app error:", rsp_process$read_error(), "\n")
}

# Start National app in background (port 3838)
cat("Starting National app on port 3838...")
national_process <- run_app_background(app_national_path, 3838)
Sys.sleep(2)  # Give it time to start
if (national_process$is_alive()) {
  cat(" OK\n")
} else {
  cat(" FAILED\n")
  cat("National app error:", national_process$read_error(), "\n")
}

# Start Summary app in background (port 3840)
cat("Starting Summary app on port 3840...")
summary_process <- run_app_background(app_summary_path, 3840)
Sys.sleep(2)  # Give it time to start
if (summary_process$is_alive()) {
  cat(" OK\n")
} else {
  cat(" FAILED\n")
  cat("Summary app error:", summary_process$read_error(), "\n")
}

# Start Observed Performance app in background (port 3841)
cat("Starting Observed Performance app on port 3841...")
observed_process <- run_app_background(app_observed_path, 3841)
Sys.sleep(2)  # Give it time to start
if (observed_process$is_alive()) {
  cat(" OK\n")
} else {
  cat(" FAILED\n")
  cat("Observed app error:", observed_process$read_error(), "\n")
}

cat("\n")
cat("================================================================\n")
cat("  All CFSR Apps Running!\n")
cat("================================================================\n\n")
cat("App URLs:\n")
cat("  National (state-by-state): http://localhost:3838/?state=MD\n")
cat("  RSP (risk-standardized):   http://localhost:3839/?state=MD\n")
cat("  Summary (performance):     http://localhost:3840/?state=MD\n")
cat("  Observed Performance:      http://localhost:3841/?state=MD&indicator=overview\n\n")
cat("Full platform:\n")
cat("  file:///D:/repo_childmetrix/cm-reports/app.html\n\n")
cat("Keep this R session running! Close it to stop all apps.\n")
cat("================================================================\n\n")

# Keep session alive and monitor processes
cat("Press Ctrl+C to stop all apps and exit.\n\n")

# Monitor loop - keeps R session alive
tryCatch({
  while (TRUE) {
    Sys.sleep(5)

    # Check if processes died unexpectedly
    if (!national_process$is_alive() && !rsp_process$is_alive() &&
        !summary_process$is_alive() && !observed_process$is_alive()) {
      cat("\nAll apps have stopped.\n")
      break
    }
  }
}, interrupt = function(e) {
  cat("\n\nShutting down apps...\n")
})

# Cleanup on exit
if (exists("national_process") && national_process$is_alive()) {
  national_process$kill()
  cat("National app stopped.\n")
}
if (exists("rsp_process") && rsp_process$is_alive()) {
  rsp_process$kill()
  cat("RSP app stopped.\n")
}
if (exists("summary_process") && summary_process$is_alive()) {
  summary_process$kill()
  cat("Summary app stopped.\n")
}
if (exists("observed_process") && observed_process$is_alive()) {
  observed_process$kill()
  cat("Observed Performance app stopped.\n")
}

cat("Done.\n")
