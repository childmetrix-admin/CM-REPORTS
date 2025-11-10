# Launch CFSR Dashboard
#
# This script starts the CFSR Statewide Data Indicators interactive dashboard
# on http://localhost:3838
#
# INSTRUCTIONS:
# 1. Open this file in R or RStudio
# 2. Click "Source" or press Ctrl+Shift+S (RStudio) or Ctrl+Shift+Enter (R)
# 3. Keep R running - don't close this window!
# 4. Open your browser to: file:///D:/repo_childmetrix/cm-reports/md/index.html#/cfsr
#
# To stop the dashboard: Press Ctrl+C or close R

# Load shiny package
if (!require("shiny")) {
  install.packages("shiny")
  library(shiny)
}

# Path to the CFSR dashboard app
app_path <- "D:/repo_childmetrix/cm-reports/md/cfsr/performance/app"

# Check if app directory exists
if (!dir.exists(app_path)) {
  stop("App directory not found: ", app_path)
}

# Check if data file exists
data_file <- file.path(app_path, "data", "cfsr_indicators_latest.rds")
if (!file.exists(data_file)) {
  warning("Data file not found: ", data_file,
          "\n\nYou may need to run cfsr-profile.R first to generate data.")
}

# Launch the app
cat("\n===============================================\n")
cat("  CFSR Dashboard Starting...\n")
cat("===============================================\n\n")
cat("Once you see 'Listening on http://127.0.0.1:3838',\n")
cat("open your browser to:\n\n")
cat("  file:///D:/repo_childmetrix/cm-reports/md/index.html#/cfsr\n\n")
cat("Or access directly at:\n\n")
cat("  http://localhost:3838/?state=MD\n\n")
cat("Keep this R session running!\n")
cat("Press Ctrl+C to stop the dashboard.\n\n")
cat("===============================================\n\n")

# Run the app
shiny::runApp(app_path, port = 3838, launch.browser = FALSE)
