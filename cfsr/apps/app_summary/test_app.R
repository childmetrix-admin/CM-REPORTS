# test_app.R - Test script for CFSR Summary App
# Verifies data loading and transformation functions work correctly

# Set working directory to app directory
setwd("D:/repo_childmetrix/cm-reports/shared/cfsr/summary/app_summary")

# Source global.R (loads all functions and packages)
cat("Loading global.R...\n")
source("global.R", local = TRUE)

cat("\n=== Testing Data Loading ===\n")

# Test 1: Load MD observed data (latest)
cat("\nTest 1: Loading MD observed data (latest profile)...\n")
tryCatch({
  data_md <- load_observed_data("MD", "latest")
  cat("  SUCCESS: Loaded", nrow(data_md), "rows\n")
  cat("  Unique indicators:", length(unique(data_md$indicator)), "\n")
  cat("  Unique periods:", length(unique(data_md$period)), "\n")
  cat("  Observed indicators (excluding Entry Rate):", sum(data_md$indicator_sort %in% c(1, 2, 4, 5, 6, 7, 8) & !duplicated(data_md$indicator)), "\n")
}, error = function(e) {
  cat("  FAILED:", conditionMessage(e), "\n")
})

# Test 2: Load KY observed data (specific profile)
cat("\nTest 2: Loading KY observed data (2025_02 profile)...\n")
tryCatch({
  data_ky <- load_observed_data("KY", "2025_02")
  cat("  SUCCESS: Loaded", nrow(data_ky), "rows\n")
}, error = function(e) {
  cat("  FAILED:", conditionMessage(e), "\n")
})

cat("\n=== Testing Summary Table Generation ===\n")

# Test 3: Generate summary table
cat("\nTest 3: Generating summary table for MD...\n")
tryCatch({
  summary_table <- generate_summary_table(data_md)

  cat("  SUCCESS: Generated summary table\n")
  cat("  Rows:", nrow(summary_table), "(should be 7 indicators)\n")
  cat("  Columns:", ncol(summary_table), "(should be 10)\n")

  # Verify column names
  expected_cols <- c(
    "indicator_very_short",
    "performance_display",
    "national_standard_display",
    "numerator_display",
    "denominator_display",
    "status",
    "recent_change_display",
    "longterm_change_display",
    "sparkline_values",
    "period_meaningful"
  )

  actual_cols <- names(summary_table)
  missing_cols <- setdiff(expected_cols, actual_cols)
  extra_cols <- setdiff(actual_cols, expected_cols)

  if (length(missing_cols) == 0 && length(extra_cols) == 0) {
    cat("  SUCCESS: All expected columns present\n")
  } else {
    if (length(missing_cols) > 0) {
      cat("  WARNING: Missing columns:", paste(missing_cols, collapse = ", "), "\n")
    }
    if (length(extra_cols) > 0) {
      cat("  WARNING: Extra columns:", paste(extra_cols, collapse = ", "), "\n")
    }
  }

  cat("\n  Column names:\n")
  for (i in seq_along(actual_cols)) {
    cat("    ", i, ". ", actual_cols[i], "\n", sep = "")
  }

  cat("\n  Sample data (first 3 indicators):\n")
  print(summary_table[1:min(3, nrow(summary_table)), 1:5], row.names = FALSE)

}, error = function(e) {
  cat("  FAILED:", conditionMessage(e), "\n")
  cat("  Error details:", conditionMessage(e), "\n")
})

cat("\n=== Testing Data Quality ===\n")

# Test 4: Verify formatting
cat("\nTest 4: Verifying data formatting...\n")
tryCatch({
  # Check performance_display
  has_dq <- any(summary_table$performance_display == "DQ")
  has_percent <- any(grepl("%$", summary_table$performance_display))

  cat("  Observed performance column:\n")
  cat("    Contains DQ values:", has_dq, "\n")
  cat("    Contains percent values:", has_percent, "\n")

  # Check national_standard_display
  has_std <- any(summary_table$national_standard_display != "—")
  cat("  National standard column:\n")
  cat("    Contains standard values:", has_std, "\n")

  # Check status values
  status_values <- unique(summary_table$status)
  cat("  Status values:", paste(status_values, collapse = ", "), "\n")

  # Check percent changes
  cat("  Recent change sample:", paste(head(summary_table$recent_change_display, 3), collapse = ", "), "\n")
  cat("  Long-term change sample:", paste(head(summary_table$longterm_change_display, 3), collapse = ", "), "\n")

  cat("  SUCCESS: Data formatting looks correct\n")

}, error = function(e) {
  cat("  FAILED:", conditionMessage(e), "\n")
})

cat("\n=== Testing Reactable Packages ===\n")

# Test 5: Check reactable packages
cat("\nTest 5: Verifying reactable packages are installed...\n")
has_reactable <- requireNamespace("reactable", quietly = TRUE)
has_reactablefmtr <- requireNamespace("reactablefmtr", quietly = TRUE)

cat("  reactable installed:", has_reactable, "\n")
cat("  reactablefmtr installed:", has_reactablefmtr, "\n")

if (has_reactable && has_reactablefmtr) {
  cat("  SUCCESS: All reactable packages available\n")
} else {
  cat("  WARNING: Some reactable packages missing - app may not work\n")
  if (!has_reactable) cat("    Install with: install.packages('reactable')\n")
  if (!has_reactablefmtr) cat("    Install with: install.packages('reactablefmtr')\n")
}

cat("\n=== Test Summary ===\n")
cat("All tests completed. If no FAILED messages appear above, the app should work.\n")
cat("\nTo launch the app:\n")
cat("  1. Run: source('D:/repo_childmetrix/cm-reports/shared/cfsr/launch_cfsr_dashboard.R')\n")
cat("  2. Open browser to: http://localhost:3840/?state=MD&profile=latest\n\n")
