# Debug script for maltreatment indicator
# Run this to diagnose the issue

source("D:/repo_childmetrix/r_utilities/loader.R")
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"))

# Setup
commitment <- "cfsr profile"
commitment_description <- "national"
my_setup <- setup_folders("2025_02")

# Extract metadata
ver <- cfsr_profile_version()
data_df_temp <- find_file(keyword = "National",
                          directory_type = "raw",
                          file_type = "excel",
                          sheet_name = "Entry rates")
asof <- cfsr_profile_extract_asof_date(data_df_temp)

# Load maltreatment sheet
data_df <- find_file(
  keyword = "National",
  directory_type = "raw",
  file_type = "excel",
  sheet_name = "Maltreatment in care"
)

# Select columns
keep_cols <- c(1:10)
data_df <- data_df[, keep_cols, drop = FALSE]

# Check what we have so far
print("=== STEP 1: After selecting columns ===")
print(paste("Dimensions:", nrow(data_df), "rows x", ncol(data_df), "cols"))
print("Column names:")
print(names(data_df))

# Extract relevant rows
data_df <- extract_relevant_rows(data_df)

print("\n=== STEP 2: After extracting relevant rows ===")
print(paste("Dimensions:", nrow(data_df), "rows x", ncol(data_df), "cols"))
print("First row (metadata):")
print(data_df[1, ])

# Extract metadata
metadata <- data_df[1, ]
period_cols <- 2:4
periods <- metadata[period_cols] %>% as.character()

print("\n=== STEP 3: Extracted periods ===")
print("Periods:")
print(periods)

# Remove first row
data_clean <- data_df[-1, ]

# Create column names
den_cols <- paste0("den_", periods)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)

print("\n=== STEP 4: Generated column names ===")
print("Denominator cols:")
print(den_cols)
print("Numerator cols:")
print(num_cols)
print("Performance cols:")
print(per_cols)

# Combine all column names
all_new_cols <- c("state", den_cols, num_cols, per_cols)
print("\nAll new column names:")
print(all_new_cols)

# Check for duplicates
print("\n=== CHECKING FOR DUPLICATES ===")
if (any(duplicated(all_new_cols))) {
  print("WARNING: Duplicate column names detected!")
  print("Duplicates:")
  print(all_new_cols[duplicated(all_new_cols)])
} else {
  print("No duplicates found in column names")
}

# Apply column names
colnames(data_clean) <- all_new_cols

print("\n=== STEP 5: After renaming columns ===")
print("Column names:")
print(names(data_clean))
print("First few rows:")
print(head(data_clean, 3))

# Try the conversion step
print("\n=== STEP 6: Converting to numeric ===")
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

print("Conversion successful!")
print("Column names after conversion:")
print(names(data_clean))

# Try the pivot step
print("\n=== STEP 7: Attempting pivot_longer ===")
try({
  data_long <- data_clean %>%
    pivot_longer(
      cols = starts_with("den") | starts_with("num") | starts_with("per"),
      names_to = c(".value", "period"),
      names_pattern = "(den|num|per)_(.+)"
    ) %>%
    rename(denominator = den, numerator = num, performance = per)

  print("Pivot successful!")
  print("Column names after pivot:")
  print(names(data_long))
  print("First few rows:")
  print(head(data_long, 3))
}, silent = FALSE)
