# Test script to verify state_rank and reporting_states columns
# are correctly added to observed RDS files

# Load test observed RDS file
test_file <- "D:/repo_childmetrix/cm-reports/shared/cfsr/data/MD_cfsr_profile_observed_2025_02.rds"

if (file.exists(test_file)) {
  cat("Loading test file:", test_file, "\n")
  observed <- readRDS(test_file)

  # Check if rank columns exist
  has_state_rank <- "state_rank" %in% names(observed)
  has_reporting_states <- "reporting_states" %in% names(observed)

  cat("\n=== Column Check ===\n")
  cat("state_rank column present:", has_state_rank, "\n")
  cat("reporting_states column present:", has_reporting_states, "\n")

  if (has_state_rank && has_reporting_states) {
    cat("\n\u2713 SUCCESS: Both rank columns are present!\n")

    # Show sample data
    cat("\n=== Sample Data ===\n")
    sample_data <- observed %>%
      select(indicator_short, period, observed_performance,
             state_rank, reporting_states) %>%
      head(5)
    print(sample_data)

    # Check for NA values
    n_rank_na <- sum(is.na(observed$state_rank))
    n_states_na <- sum(is.na(observed$reporting_states))

    cat("\n=== Data Quality ===\n")
    cat("Total rows:", nrow(observed), "\n")
    cat("state_rank NA count:", n_rank_na, "\n")
    cat("reporting_states NA count:", n_states_na, "\n")

    if (n_rank_na == 0 && n_states_na == 0) {
      cat("\n\u2713 All rank data populated (no NAs)\n")
    } else {
      cat("\n\u26A0 Some NA values found (may be expected for certain periods)\n")
    }
  } else {
    cat("\n\u2717 FAILED: Rank columns are missing!\n")
    cat("This file needs to be regenerated after updating profile_observed.R\n")
  }

  # Show all column names
  cat("\n=== All Columns (", length(names(observed)), ") ===\n")
  print(names(observed))

} else {
  cat("Test file not found:", test_file, "\n")
  cat("Run the extraction pipeline first to generate observed RDS files.\n")
}
