# prepare_app_data.R
# Run this script to prepare data for the Shiny app after running cfsr-profile.R
#
# This script can be:
# 1. Auto-run by cfsr-profile.R (uses profile_period and state_code from parent script)
# 2. Run manually (uses most recent state/period if not set)

library(dplyr)

# Set the data directory path
data_dir <- "D:/repo_childmetrix/cfsr-profile/data"

cat("\n")
cat("="=rep("=", 70), sep="")
cat("\nPreparing Shiny App Data\n")
cat("="=rep("=", 70), sep="")
cat("\n\n")

# Check if directory exists
if (!dir.exists(data_dir)) {
  stop("Data directory not found: ", data_dir,
       "\n\nPlease check the path and try again.")
}

# Determine which state and profile period to use
if (exists("state_code") && exists("profile_period")) {
  # If called from cfsr-profile.R, use the specified values
  use_state <- tolower(state_code)  # Ensure lowercase
  use_period <- profile_period
  message("Using state/period from cfsr-profile.R: ", use_state, " - ", use_period)
} else {
  # If run manually, find most recent state/period
  processed_base <- file.path(data_dir, "processed")

  if (!dir.exists(processed_base)) {
    stop("Processed folder not found: ", processed_base,
         "\nPlease run cfsr-profile.R first.")
  }

  # Get all state directories
  state_dirs <- list.dirs(processed_base, full.names = FALSE, recursive = FALSE)

  if (length(state_dirs) == 0) {
    stop("No state folders found in: ", processed_base,
         "\nPlease run cfsr-profile.R first.")
  }

  # Use first state found (already lowercase from folder structure)
  use_state <- state_dirs[1]

  # Get all periods for this state
  state_path <- file.path(processed_base, use_state)
  period_dirs <- list.dirs(state_path, full.names = FALSE, recursive = FALSE)

  if (length(period_dirs) == 0) {
    stop("No period folders found in: ", state_path,
         "\nPlease run cfsr-profile.R first.")
  }

  # Get most recent period (sorted alphabetically works for YYYY_MM format)
  use_period <- sort(period_dirs, decreasing = TRUE)[1]
  message("Using most recent state/period found: ", use_state, " - ", use_period)
}

# Find CSV in processed folder (national subdirectory)
processed_path <- file.path(data_dir, "processed", use_state, use_period)
cat("Looking in processed folder:", processed_path, "\n")

if (!dir.exists(processed_path)) {
  stop("Processed folder not found: ", processed_path)
}

run_dirs <- list.dirs(processed_path, recursive = FALSE)

if (length(run_dirs) == 0) {
  stop("No processed data found in ", processed_path)
}

latest_run <- sort(basename(run_dirs), decreasing = TRUE)[1]
message("Using run date: ", latest_run)

# Look for CSV in national/ subdirectory
national_path <- file.path(processed_path, latest_run, "national")
if (!dir.exists(national_path)) {
  stop("National data folder not found: ", national_path,
       "\nExpected structure: data/processed/{state}/{period}/{date}/national/")
}

csv_files <- list.files(national_path, pattern = "\\.csv$", full.names = TRUE)

if (length(csv_files) == 0) {
  stop("No CSV files found in ", national_path)
}

# Load the data
message("Loading data from: ", basename(csv_files[1]))
ind_data <- read.csv(csv_files[1], stringsAsFactors = FALSE)
message("Loaded ", nrow(ind_data), " rows")

# Load dictionary
dict_path <- "D:/repo_childmetrix/cfsr-profile/code/cfsr_round4_indicators_dictionary.csv"
if (!file.exists(dict_path)) {
  stop("Dictionary not found at: ", dict_path)
}
dict <- read.csv(dict_path, stringsAsFactors = FALSE)
message("Loaded dictionary with ", nrow(dict), " indicators")

# Filter to most recent period per indicator
app_data <- ind_data %>%
  group_by(indicator) %>%
  filter(period == max(period, na.rm = TRUE)) %>%
  ungroup()

message("Filtered to latest period: ", nrow(app_data), " rows")

# Join dictionary metadata
app_data <- app_data %>%
  left_join(
    dict %>% select(
      indicator,
      indicator_sort,
      indicator_short,
      indicator_very_short,
      category,
      description,
      denominator_def = denominator,
      numerator_def = numerator,
      national_standard,
      direction_rule,
      direction_desired,
      direction_legend,
      decimal_precision,
      scale,
      format,
      risk_adjustment,
      exclusions,
      notes
    ),
    by = "indicator"
  )

message("Joined dictionary metadata")

# Check for missing joins
missing_joins <- app_data %>%
  filter(is.na(category)) %>%
  distinct(indicator)

if (nrow(missing_joins) > 0) {
  warning("The following indicators did not match the dictionary:")
  print(missing_joins$indicator)
}

cat("\n")
cat("-"=rep("-", 70), sep="")
cat("\nSaving RDS Files\n")
cat("-"=rep("-", 70), sep="")
cat("\n\n")

# Save for Shiny app
# National data is identical across states, so save WITHOUT state prefix
# This avoids duplicate files (MD_...national = KY_...national = etc.)

output_dir_prod <- "D:/repo_childmetrix/cm-reports/shared/cfsr/performance/data"
if (!dir.exists(output_dir_prod)) {
  dir.create(output_dir_prod, recursive = TRUE)
}

# PROD: Period-specific file (no state prefix - shared across all states)
# Note: No _latest.rds file needed - app dynamically finds most recent profile
output_file_prod_period <- file.path(output_dir_prod,
  paste0("cfsr_profile_national_", use_period, ".rds"))
saveRDS(app_data, output_file_prod_period)
message("Saved to PROD: ", output_file_prod_period)

# Print summary
cat("\n")
cat("-"=rep("-", 70), sep="")
cat("\nSummary\n")
cat("-"=rep("-", 70), sep="")
cat("\n\n")
message("State: ", use_state)
message("Profile period: ", use_period)
message("Total rows: ", nrow(app_data))
message("Unique indicators: ", length(unique(app_data$indicator)))
message("Unique states: ", length(unique(app_data$state)))
message("Profile version: ", unique(app_data$profile_version)[1])
cat("\n")
message("✓ Data ready for Shiny app!")
message("  - Multiple periods can now coexist")
message("  - Switch profiles via URL parameter: ?state=", use_state, "&profile=", use_period)
cat("\n")
cat("="=rep("=", 70), sep="")
cat("\n\n")
