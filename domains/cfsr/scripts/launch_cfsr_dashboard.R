# Launch CFSR Dashboard (Unified App)
#
# This script starts the unified CFSR Shiny app on http://localhost:3838
# The single app handles all 4 views via URL parameters:
#   - National comparison: ?view=national
#   - RSP (Risk-Standardized Performance): ?view=rsp
#   - Summary (Performance Summary): ?view=summary
#   - Observed Performance: ?view=observed
#
# INSTRUCTIONS:
# 1. Open this file in R or RStudio
# 2. Click "Source" or press Ctrl+Shift+S (RStudio)
# 3. Keep R running - don't close this window!
# 4. Open your browser to: file:///D:/repo_childmetrix/cm-reports/app.html
#
# To stop: Close this R session (app will terminate)

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

# Path to the unified CFSR app
app_cfsr_path <- file.path(monorepo_root, "domains/cfsr/apps/app_cfsr")
data_path <- file.path(monorepo_root, "domains/cfsr/data/rds")

# Check if app directory exists
if (!dir.exists(app_cfsr_path)) {
  stop("Unified CFSR app directory not found: ", app_cfsr_path,
       "\n\nNote: The CFSR apps have been consolidated into app_cfsr/",
       "\nOld separate apps (app_national, app_rsp, app_summary, app_observed) are deprecated.")
}

# Check if data directory exists
if (!dir.exists(data_path)) {
  warning("Data directory not found: ", data_path,
          "\n\nYou may need to run the CFSR extraction pipeline first to generate data.")
}

# Launch banner
cat("\n")
cat("================================================================\n")
cat("  CFSR Dashboard - Starting Unified App...\n")
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

# Start unified CFSR app in background (port 3838)
cat("Starting unified CFSR app on port 3838...")
cfsr_process <- run_app_background(app_cfsr_path, 3838)
Sys.sleep(3)  # Give it time to start
if (cfsr_process$is_alive()) {
  cat(" OK\n")
} else {
  cat(" FAILED\n")
  cat("CFSR app error:", cfsr_process$read_error(), "\n")
  stop("Failed to start CFSR app")
}

cat("\n")
cat("================================================================\n")
cat("  CFSR App Running!\n")
cat("================================================================\n\n")
cat("App URLs (all on port 3838 with view parameter):\n")
cat("  National (state-by-state): http://localhost:3838/?state=MD&view=national\n")
cat("  RSP (risk-standardized):   http://localhost:3838/?state=MD&view=rsp\n")
cat("  Summary (performance):     http://localhost:3838/?state=MD&view=summary\n")
cat("  Observed Performance:      http://localhost:3838/?state=MD&view=observed&indicator=overview\n\n")
cat("Full platform:\n")
cat("  file:///D:/repo_childmetrix/cm-reports/app.html\n\n")
cat("Keep this R session running! Close it to stop the app.\n")
cat("================================================================\n\n")

# Keep session alive and monitor process
cat("Press Ctrl+C to stop the app and exit.\n\n")

# Monitor loop - keeps R session alive
tryCatch({
  while (TRUE) {
    Sys.sleep(5)

    # Check if process died unexpectedly
    if (!cfsr_process$is_alive()) {
      cat("\nApp has stopped unexpectedly.\n")
      cat("Error output:\n")
      cat(cfsr_process$read_error(), "\n")
      break
    }
  }
}, interrupt = function(e) {
  cat("\n\nShutting down app...\n")
})

# Cleanup on exit
if (exists("cfsr_process") && cfsr_process$is_alive()) {
  cfsr_process$kill()
  cat("CFSR app stopped.\n")
}

cat("Done.\n")
