# prepare_app_data.R
# Run this script to prepare data for the Shiny app after running r_cfsr_profile.R
#
# This script can be:
# 1. Auto-run by r_cfsr_profile.R (uses profile_period from parent script)
# 2. Run manually (uses most recent YYYY_MM folder if profile_period not set)

library(dplyr)

# Set the data directory path
data_dir <- "D:/repo_childmetrix/r_cfsr_profile/data"

cat("Looking for data in:", data_dir, "\n")

# Check if directory exists
if (!dir.exists(data_dir)) {
  stop("Data directory not found: ", data_dir,
       "\n\nPlease check the path and try again.")
}

# Determine which profile period to use
if (exists("profile_period")) {
  # If called from r_cfsr_profile.R, use the specified profile_period
  latest_period <- profile_period
  message("Using profile period from r_cfsr_profile.R: ", latest_period)
} else {
  # If run manually, find most recent YYYY_MM folder
  processed_dirs <- list.dirs(data_dir, recursive = FALSE)

  # Filter to YYYY_MM format only (exclude cumulative, CY, Q folders)
  period_dirs <- processed_dirs[grepl("^\\d{4}_\\d{2}$", basename(processed_dirs))]

  if (length(period_dirs) == 0) {
    cat("Available folders in", data_dir, ":\n")
    print(basename(processed_dirs))
    stop("No YYYY_MM data folders found in: ", data_dir,
         "\nPlease run r_cfsr_profile.R first.")
  }

  # Get most recent period (sorted alphabetically works for YYYY_MM format)
  latest_period <- sort(basename(period_dirs), decreasing = TRUE)[1]
  message("Using most recent period found: ", latest_period)
}

# Find CSV in processed folder
processed_path <- file.path(data_dir, latest_period, "processed")
cat("Looking in processed folder:", processed_path, "\n")

run_dirs <- list.dirs(processed_path, recursive = FALSE)

if (length(run_dirs) == 0) {
  stop("No processed data found in ", processed_path)
}

latest_run <- sort(basename(run_dirs), decreasing = TRUE)[1]
message("Using run date: ", latest_run)

csv_files <- list.files(file.path(processed_path, latest_run),
                        pattern = "\\.csv$", full.names = TRUE)

if (length(csv_files) == 0) {
  stop("No CSV files found in ", file.path(processed_path, latest_run))
}

# Load the data
message("Loading data from: ", csv_files[1])
ind_data <- read.csv(csv_files[1], stringsAsFactors = FALSE)
message("Loaded ", nrow(ind_data), " rows")

# Load dictionary
dict_path <- "D:/repo_childmetrix/r_cfsr_profile/code/cfsr_round4_indicators_dictionary.csv"
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

# Save for Shiny app
output_dir <- "D:/repo_childmetrix/r_cfsr_profile/shiny_app/data"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}
output_file <- file.path(output_dir, "cfsr_indicators_latest.rds")
saveRDS(app_data, output_file)
message("Saved prepared data to: ", output_file)

# Print summary
message("\n=== SUMMARY ===")
message("Total rows: ", nrow(app_data))
message("Unique indicators: ", length(unique(app_data$indicator)))
message("Unique states: ", length(unique(app_data$state)))
message("Profile version: ", unique(app_data$profile_version)[1])
message("\nData ready for Shiny app!")
