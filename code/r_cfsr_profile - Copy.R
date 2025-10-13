# Title:          Process data from 
                  # National - Supplemental Context Date - [Month YYYY] .xlsx

# Purpose:        Joy

#####################################
# NOTES ----
#####################################

# This file is provided to every state about every 6 months (usually February
# & August). It show state-by-state performance and trends on the CFSR 
# statewide data indicators and entry rates. Also shows national performance by
# age, race/ethnicity.

#####################################
# TODO ----
#####################################


#####################################
# OTHER DEPENDENCIES (e.g., files) 
#####################################

# 1. Manually copy to raw folder:
# - National - Supplemental Context Date - [Month YYYY] .xlsx

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
source("D:/repo_childmetrix/r_utilities/loader.R")

# Load functions specific to this project
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"), chdir = FALSE)

########################################
# FOLDER PATHS & DIRECTORY STRUCTURE ----
########################################

# Base data folder
base_data_dir <- "D:/repo_childmetrix/r_cfsr_profile/data"

# File name elements (e.g., 2024_01 - [commitment] - [commitment_description] - 2024-02-15.csv")
# e.g., save_to_folder_run(claiming_df)
commitment <- "cfsr profile"
commitment_description <- "national"

# Establish current period and set up folders and global variables
my_setup <- setup_folders("2025_02")

########################################
# CREATE FIELDS, FLAGS, CALCULATIONS ----
########################################

# --------------------------------------
# Entry rate & meta profile details
# --------------------------------------

data_df <- find_file(keyword = "National", 
                     directory_type = "raw", 
                     file_type = "excel",
                     sheet_name = "Entry rates")

# 1) Profile month/year and citation
ver <- cfsr_profile_version()
ver$profile_version  # e.g., "August 2024"
ver$month            # e.g., "August"
ver$year             # e.g., "2024"
ver$source           # prebuilt citation string

# 2) AFCARS/NCANDS "as of" date
asof <- cfsr_profile_extract_asof_date(data_df)
asof$header_text     # full header line
asof$date_string     # e.g., "08-15-2024"
asof$as_of_date      # Date object

# Select only columns and rows for entry rate and related data
# --------------------------------------

# Select only relevant columns and rows for entry rate and related data
keep_cols <- c(1:16)
data_df   <- data_df[, keep_cols, drop = FALSE]

# Select relevant rows
data_df <- extract_relevant_rows(data_df)

# Process then reshape wide to long
# --------------------------------------

# Extract metadata dynamically
metadata <- data_df[1, ]
years <- metadata[2:6] %>% as.numeric()  # Dynamically capture the years (columns 2 - 6)
periods <- metadata[7:11] %>% as.character()  # Dynamically capture the period labels (columns 7 - 11)

# Remove the first row since it only contains metadata
data_clean <- data_df[-1, ]

# Dynamically rename the columns based on extracted years and periods
# Construct child population, foster care entry, and entry rate column names
den_cols <- paste0("den_", years)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)

# Assign new column names to `data_clean`
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# Convert relevant columns to numeric
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

# Reshape the child population columns dynamically
child_pop_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("den"),
    names_to = "year",  # Capture the year component
    names_pattern = "den_(\\d{4})"  # Dynamically extract the year
  ) %>%
  rename(denominator = value)  # Rename the value column to `denominator`

# Reshape the foster care entries and entry rates dynamically
data_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("num") | starts_with("per"),
    names_to = c(".value", "period"),  # Capture `.value` and `period`
    names_pattern = "(num|per)_(\\d+[A-Z]\\d+[A-Z])"  # Extract prefix and period label
  ) %>%
  rename(numerator = num, performance = per)  # Rename columns for clarity

# Create a dynamic mapping between `period` and `year`
period_to_year <- tibble(
  period = periods,
  year = as.character(years)
)

# Merge the reshaped `entry_rate_long` data with `period_to_year` to add the `year` column
data_long <- data_long %>%
  left_join(period_to_year, by = "period")

# Merge `child_pop_long` with `entry_rate_long` using `state` and `year`
final_df <- data_long %>%
  left_join(child_pop_long, by = c("state", "year"))

# Create `census_year` and `indicator` columns, and reorder dynamically
# Create the `final_df` with dynamic period_meaningful calculation
# --------------------------------------

# returns list with $source and $profile_version
# source conflicts with a dyplry function, hence the need to extract it vs. 
# using source = source
ver <- cfsr_profile_version()  

final_df <- final_df %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),
    census_year = as.numeric(year),
    indicator = "Foster care entry rate per 1,000",
    as_of_date = as_of_date,
    source = ver$source, # source = source
    # Use the function to generate a meaningful period label
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  ) 

# Rank each state
# -------------------------------------

final_df <- rank_states_by_performance(final_df)

# Save
# -------------------------------------

# keep only these variables
ind_entrate_df <- final_df %>%
  select(state, indicator, period, period_meaningful, denominator, numerator, 
         performance, state_rank, census_year, as_of_date, profile_version, 
         source)

#commitment_description <- "entry_rate"
#save_to_folder_run(final_df)

# --------------------------------------
# Re-Entry
# --------------------------------------

data_df <- find_file(keyword = "National", 
                     directory_type = "raw", 
                     file_type = "excel",
                     sheet_name = "Reentry to FC")

# Select only columns and rows for indicator and related data
# --------------------------------------

# Select only relevant columns
keep_cols <- c(1:10)
data_df   <- data_df[, keep_cols, drop = FALSE]

# Select relevant rows
data_df <- extract_relevant_rows(data_df)

# Process then reshape wide to long
# --------------------------------------

# Extract metadata dynamically
metadata <- data_df[1, ]
# years <- metadata[2:4] %>% as.numeric()  # Dynamically capture the years (columns 2 - 4)
periods <- metadata[2:4] %>% as.character()  # Dynamically capture the period labels (columns 2 - 4)

# Remove the first row since it only contains metadata
data_clean <- data_df[-1, ]

# Dynamically rename the columns based on extracted years and periods
# Construct child population, foster care entry, and entry rate column names
den_cols <- paste0("den_", periods)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)

# Assign new column names to `data_clean`
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# Convert relevant columns to numeric
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

# Reshape the foster care entries and entry rates dynamically
data_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("den") | starts_with("num") | starts_with("per"),
    names_to = c(".value", "period"),  # Capture `.value` and `period`
    names_pattern = "(den|num|per)_(\\d+[A-Z]\\d+[A-Z])"  # Extract prefix and period label
  ) %>%
  rename(denominator = den, numerator = num, performance = per)  # Rename columns for clarity

# Create `indicator` columns, and reorder dynamically
# Create the `final_df` with dynamic period_meaningful calculation

ver <- cfsr_profile_version()  

final_df <- data_long %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),  
    denominator = as.numeric(denominator),
    numerator = as.numeric(numerator),
    performance = as.numeric(performance),
    indicator = "Re-entry into foster care after exiting to reunification or guardianship",
    as_of_date = as_of_date,
    source = ver$source,
    # Use the function to generate a meaningful period label
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  ) 

# Rank each state
# ---------------------------------------

final_df <- rank_states_by_performance(final_df)

# Save
# ---------------------------------------

ind_reentry_df <- final_df %>%
  select(state, indicator, period, period_meaningful, denominator, numerator, 
         performance, state_rank, as_of_date, profile_version, source)

# --------------------------------------
# Perm in 12 (entries)
# --------------------------------------

data_df <- find_file(keyword = "National", 
                     directory_type = "raw", 
                     file_type = "excel",
                     sheet_name = "Perm in 12 (entries)")

# Select only columns and rows for indicator and related data
# --------------------------------------

# Select only relevant columns
keep_cols <- c(1:10)
data_df   <- data_df[, keep_cols, drop = FALSE]

# Select relevant rows
data_df <- extract_relevant_rows(data_df)

# Process then reshape wide to long
# --------------------------------------

# Extract metadata dynamically
metadata <- data_df[1, ]
# years <- metadata[2:4] %>% as.numeric()  # Dynamically capture the years (columns 2 - 4)
periods <- metadata[2:4] %>% as.character()  # Dynamically capture the period labels (columns 2 - 4)

# Remove the first row since it only contains metadata
data_clean <- data_df[-1, ]

# Dynamically rename the columns based on extracted years and periods
# Construct child population, foster care entry, and entry rate column names
den_cols <- paste0("den_", periods)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)

# Assign new column names to `data_clean`
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# Convert relevant columns to numeric
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

# Reshape the foster care entries and entry rates dynamically
data_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("den") | starts_with("num") | starts_with("per"),
    names_to = c(".value", "period"),  # Capture `.value` and `period`
    names_pattern = "(den|num|per)_(\\d+[A-Z]\\d+[A-Z])"  # Extract prefix and period label
  ) %>%
  rename(denominator = den, numerator = num, performance = per)  # Rename columns for clarity

# Create `indicator` columns, and reorder dynamically
# Create the `final_df` with dynamic period_meaningful calculation

ver <- cfsr_profile_version()  

final_df <- data_long %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),  
    denominator = as.numeric(denominator),
    numerator = as.numeric(numerator),
    performance = as.numeric(performance),
    indicator = "Permanency in 12 mos (entries)",
    as_of_date = as_of_date,
    source = ver$source,
    # Use the function to generate a meaningful period label
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  ) 

# Rank each state
# ---------------------------------------

final_df <- rank_states_by_performance(final_df)

# Save
# ---------------------------------------

ind_perm12_df <- final_df %>%
  select(state, indicator, period, period_meaningful, denominator, numerator, 
         performance, state_rank, as_of_date, profile_version, source)

# --------------------------------------
# Perm in 12 (12-23)
# --------------------------------------

data_df <- find_file(keyword = "National", 
                     directory_type = "raw", 
                     file_type = "excel",
                     sheet_name = "Perm in 12 (12-23 mos)")

# Select only columns and rows for indicator and related data
# --------------------------------------

# Select only relevant columns
keep_cols <- c(1:10)
data_df   <- data_df[, keep_cols, drop = FALSE]

# Select relevant rows
data_df <- extract_relevant_rows(data_df)

# Process then reshape wide to long
# --------------------------------------

# Extract metadata dynamically
metadata <- data_df[1, ]
# years <- metadata[2:4] %>% as.numeric()  # Dynamically capture the years (columns 2 - 4)
periods <- metadata[2:4] %>% as.character()  # Dynamically capture the period labels (columns 2 - 4)

# Remove the first row since it only contains metadata
data_clean <- data_df[-1, ]

# Dynamically rename the columns based on extracted years and periods
# Construct child population, foster care entry, and entry rate column names
den_cols <- paste0("den_", periods)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)

# Assign new column names to `data_clean`
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# Convert relevant columns to numeric
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

# Reshape the foster care entries and entry rates dynamically
data_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("den") | starts_with("num") | starts_with("per"),
    names_to = c(".value", "period"),  # Capture `.value` and `period`
    names_pattern = "(den|num|per)_(\\d+[A-Z]\\d+[A-Z])"  # Extract prefix and period label
  ) %>%
  rename(denominator = den, numerator = num, performance = per)  # Rename columns for clarity

# Create `indicator` columns, and reorder dynamically
# Create the `final_df` with dynamic period_meaningful calculation

ver <- cfsr_profile_version()  

final_df <- data_long %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),  
    denominator = as.numeric(denominator),
    numerator = as.numeric(numerator),
    performance = as.numeric(performance),
    indicator = "Permanency in 12 mos (12-23 mos)",
    as_of_date = as_of_date,
    source = ver$source,
    # Use the function to generate a meaningful period label
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  ) 

# Rank each state
# ---------------------------------------

final_df <- rank_states_by_performance(final_df)

# Save
# ---------------------------------------

ind_perm1223_df <- final_df %>%
  select(state, indicator, period, period_meaningful, denominator, numerator, 
         performance, state_rank, as_of_date, profile_version, source)

# --------------------------------------
# Perm in 12 (24+ mos)
# --------------------------------------

data_df <- find_file(keyword = "National", 
                     directory_type = "raw", 
                     file_type = "excel",
                     sheet_name = "Perm in 12 (24+ mos)")

# Select only columns and rows for indicator and related data
# --------------------------------------

# Select only relevant columns
keep_cols <- c(1:10)
data_df   <- data_df[, keep_cols, drop = FALSE]

# Select relevant rows
data_df <- extract_relevant_rows(data_df)

# Process then reshape wide to long
# --------------------------------------

# Extract metadata dynamically
metadata <- data_df[1, ]
# years <- metadata[2:4] %>% as.numeric()  # Dynamically capture the years (columns 2 - 4)
periods <- metadata[2:4] %>% as.character()  # Dynamically capture the period labels (columns 2 - 4)

# Remove the first row since it only contains metadata
data_clean <- data_df[-1, ]

# Dynamically rename the columns based on extracted years and periods
# Construct child population, foster care entry, and entry rate column names
den_cols <- paste0("den_", periods)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)

# Assign new column names to `data_clean`
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# Convert relevant columns to numeric
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

# Reshape the foster care entries and entry rates dynamically
data_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("den") | starts_with("num") | starts_with("per"),
    names_to = c(".value", "period"),  # Capture `.value` and `period`
    names_pattern = "(den|num|per)_(\\d+[A-Z]\\d+[A-Z])"  # Extract prefix and period label
  ) %>%
  rename(denominator = den, numerator = num, performance = per)  # Rename columns for clarity

# Create `indicator` columns, and reorder dynamically
# Create the `final_df` with dynamic period_meaningful calculation

ver <- cfsr_profile_version()  

final_df <- data_long %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),  
    denominator = as.numeric(denominator),
    numerator = as.numeric(numerator),
    performance = as.numeric(performance),
    indicator = "Permanency in 12 mos (24+ mos)",
    as_of_date = as_of_date,
    source = ver$source,
    # Use the function to generate a meaningful period label
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  ) 

# Rank each state
# ---------------------------------------

final_df <- rank_states_by_performance(final_df)

# Save
# ---------------------------------------

ind_perm24_df <- final_df %>%
  select(state, indicator, period, period_meaningful, denominator, numerator, 
         performance, state_rank, as_of_date, profile_version, source)

# --------------------------------------
# Placement Stabiltiy
# --------------------------------------

data_df <- find_file(keyword = "National", 
                     directory_type = "raw", 
                     file_type = "excel",
                     sheet_name = "Placement stability")

# Select only columns and rows for indicator and related data
# --------------------------------------

# Select only relevant columns
keep_cols <- c(1:10)
data_df   <- data_df[, keep_cols, drop = FALSE]

# Select relevant rows
data_df <- extract_relevant_rows(data_df)

# Process then reshape wide to long
# --------------------------------------

# Extract metadata dynamically
metadata <- data_df[1, ]
# years <- metadata[2:4] %>% as.numeric()  # Dynamically capture the years (columns 2 - 4)
periods <- metadata[2:4] %>% as.character()  # Dynamically capture the period labels (columns 2 - 4)

# Remove the first row since it only contains metadata
data_clean <- data_df[-1, ]

# Dynamically rename the columns based on extracted years and periods
# Construct child population, foster care entry, and entry rate column names
den_cols <- paste0("den_", periods)
num_cols <- paste0("num_", periods)
per_cols <- paste0("per_", periods)

# Assign new column names to `data_clean`
colnames(data_clean) <- c("state", den_cols, num_cols, per_cols)

# Convert relevant columns to numeric
data_clean <- data_clean %>%
  mutate(across(starts_with("den") | starts_with("num") | starts_with("per"), as.numeric))

# Reshape the foster care entries and entry rates dynamically
data_long <- data_clean %>%
  pivot_longer(
    cols = starts_with("den") | starts_with("num") | starts_with("per"),
    names_to = c(".value", "period"),  # Capture `.value` and `period`
    names_pattern = "(den|num|per)_(\\d+[A-Z]\\d+[A-Z])"  # Extract prefix and period label
  ) %>%
  rename(denominator = den, numerator = num, performance = per)  # Rename columns for clarity

# Create `indicator` columns, and reorder dynamically
# Create the `final_df` with dynamic period_meaningful calculation

ver <- cfsr_profile_version()  

final_df <- data_long %>%
  mutate(
    state = ifelse(state == "District of Columbia", "D.C.", state),  
    denominator = as.numeric(denominator),
    numerator = as.numeric(numerator),
    performance = as.numeric(performance),
    indicator = "Placement stability (moves/1,000 days in care)",
    as_of_date = as_of_date,
    source = ver$source,
    # Use the function to generate a meaningful period label
    period_meaningful = make_period_meaningful(period),
    profile_version = ver$profile_version
  ) 

# Rank each state
# ---------------------------------------

final_df <- rank_states_by_performance(final_df)

# Save
# ---------------------------------------

ind_ps_df <- final_df %>%
  select(state, indicator, period, period_meaningful, denominator, numerator, 
         performance, state_rank, as_of_date, profile_version, source)

# --------------------------------------
# Append ind_data together and save
# --------------------------------------

ind_data <- bind_rows(ind_entrate_df, ind_reentry_df, ind_perm12_df, 
                      ind_perm1223_df, ind_perm24_df, ind_ps_df)

save_to_folder_run(ind_data, "csv")