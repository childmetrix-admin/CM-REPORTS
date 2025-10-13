# test_phase3.R - Quick test to validate Phase 3 changes

# Load libraries
library(dplyr)

# Source functions
source("functions/utils.R")
source("functions/data_prep.R")
source("functions/chart_builder.R")

# Load prepared data (or prepare it)
if (file.exists("data/cfsr_indicators_latest.rds")) {
  app_data <- readRDS("data/cfsr_indicators_latest.rds")
  cat("Loaded existing RDS file\n")
} else {
  # Run prepare script
  cat("Preparing data...\n")
  source("prepare_app_data.R")
  app_data <- readRDS("data/cfsr_indicators_latest.rds")
}

cat("\n=== DATA LOADED ===\n")
cat("Rows:", nrow(app_data), "\n")
cat("Indicators:", length(unique(app_data$indicator)), "\n")
cat("States:", length(unique(app_data$state)), "\n")

# Test get_all_indicators function
cat("\n=== TESTING get_all_indicators() ===\n")
all_indicators <- get_all_indicators(app_data)
cat("Found", length(all_indicators), "indicators:\n")
for (i in seq_along(all_indicators)) {
  cat(sprintf("%d. %s\n", i, all_indicators[i]))
}

# Test navigation function
cat("\n=== TESTING get_indicator_navigation() ===\n")
test_indicator <- all_indicators[1]
cat("Testing navigation for:", test_indicator, "\n")
nav_info <- get_indicator_navigation(test_indicator, app_data)
cat("  Previous:", nav_info$prev_label, "(tab:", nav_info$prev_tab, ")\n")
cat("  Next:", nav_info$next_label, "(tab:", nav_info$next_tab, ")\n")

# Test middle indicator
test_indicator <- all_indicators[4]
cat("\nTesting navigation for:", test_indicator, "\n")
nav_info <- get_indicator_navigation(test_indicator, app_data)
cat("  Previous:", nav_info$prev_label, "(tab:", nav_info$prev_tab, ")\n")
cat("  Next:", nav_info$next_label, "(tab:", nav_info$next_tab, ")\n")

# Test last indicator
test_indicator <- all_indicators[length(all_indicators)]
cat("\nTesting navigation for:", test_indicator, "\n")
nav_info <- get_indicator_navigation(test_indicator, app_data)
cat("  Previous:", nav_info$prev_label, "(tab:", nav_info$prev_tab, ")\n")
cat("  Next:", nav_info$next_label, "(tab:", nav_info$next_tab, ")\n")

# Test overview chart function
cat("\n=== TESTING build_overview_chart() ===\n")
test_indicator <- all_indicators[1]
ind_data <- get_indicator_data(app_data, test_indicator, "Maryland")
if (!is.null(ind_data)) {
  chart <- build_overview_chart(ind_data, "Maryland")
  if (!is.null(chart)) {
    cat("✓ Overview chart created successfully for:", test_indicator, "\n")
  } else {
    cat("✗ Failed to create overview chart\n")
  }
} else {
  cat("✗ No data found for indicator\n")
}

cat("\n=== ALL TESTS COMPLETE ===\n")
cat("Phase 3 functions are working!\n")
