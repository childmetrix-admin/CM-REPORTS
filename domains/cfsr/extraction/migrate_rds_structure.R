# migrate_rds_structure.R - Migrate RDS files to new hierarchical structure
#
# OLD STRUCTURE:
# domains/cfsr/data/rds/
# ├── cfsr_profile_national_2025_02.rds
# ├── MD_cfsr_profile_rsp_2025_02.rds
# ├── KY_cfsr_profile_observed_2025_08.rds
# └── ...
#
# NEW STRUCTURE:
# domains/cfsr/data/rds/
# ├── national/
# │   ├── cfsr_profile_national_2025_02.rds
# │   └── cfsr_profile_national_2025_08.rds
# ├── md/
# │   ├── 2025_02/
# │   │   ├── MD_cfsr_profile_rsp_2025_02.rds
# │   │   ├── MD_cfsr_profile_observed_2025_02.rds
# │   │   └── MD_cfsr_profile_state_2025_02.rds
# │   └── 2025_08/
# └── ky/
#     └── ...

library(dplyr)

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

  root <- Sys.getenv("CM_REPORTS_ROOT")
  if (root != "") return(root)

  stop("Cannot detect monorepo root. Set CM_REPORTS_ROOT environment variable.")
}

# Set paths
MONOREPO_ROOT <- detect_monorepo_root()
RDS_DIR <- file.path(MONOREPO_ROOT, "domains/cfsr/data/rds")

message("==============================================")
message("RDS Structure Migration Script")
message("==============================================")
message("RDS Directory: ", RDS_DIR)
message("")

# Get all RDS files in root directory
all_rds_files <- list.files(RDS_DIR, pattern = "\\.rds$", full.names = TRUE)

if (length(all_rds_files) == 0) {
  message("No RDS files found in ", RDS_DIR)
  stop("Migration aborted.")
}

message("Found ", length(all_rds_files), " RDS files to migrate:")
for (file in all_rds_files) {
  message("  - ", basename(file))
}
message("")

# Parse filenames and categorize
files_to_migrate <- data.frame(
  original_path = all_rds_files,
  filename = basename(all_rds_files),
  stringsAsFactors = FALSE
)

# Categorize files
files_to_migrate <- files_to_migrate %>%
  mutate(
    # Extract components from filename
    is_national = grepl("^cfsr_profile_national_", filename),
    state_code = if_else(
      is_national,
      NA_character_,
      toupper(sub("^([A-Z]{2})_.*", "\\1", filename))
    ),
    type = case_when(
      is_national ~ "national",
      grepl("_rsp_", filename) ~ "rsp",
      grepl("_observed_", filename) ~ "observed",
      grepl("_state_", filename) ~ "state",
      TRUE ~ NA_character_
    ),
    period = sub(".*_([0-9]{4}_[0-9]{2})\\.rds$", "\\1", filename),
    # Build new path
    new_path = if_else(
      is_national,
      file.path(RDS_DIR, "national", filename),  # National goes to national/ subdirectory
      file.path(RDS_DIR, tolower(state_code), period, filename)  # State-specific goes to subdirectory
    )
  )

# Show migration plan
message("Migration Plan:")
message("==============================================")
for (i in 1:nrow(files_to_migrate)) {
  row <- files_to_migrate[i, ]
  message("")
  message("File ", i, " of ", nrow(files_to_migrate))
  message("  Type: ", row$type)
  if (!row$is_national) {
    message("  State: ", row$state_code)
  }
  message("  Period: ", row$period)
  message("  FROM: ", row$original_path)
  message("  TO:   ", row$new_path)

  # Check if already in correct location
  if (row$original_path == row$new_path) {
    message("  ACTION: Already in correct location (SKIP)")
  } else if (file.exists(row$new_path)) {
    message("  ACTION: Destination already exists (SKIP)")
  } else {
    message("  ACTION: MOVE")
  }
}

message("")
message("==============================================")
cat("Proceed with migration? (yes/no): ")
response <- tolower(trimws(readLines(con = stdin(), n = 1)))

if (response != "yes") {
  message("Migration cancelled.")
  stop("User cancelled migration.")
}

# Perform migration
message("")
message("Starting migration...")
message("==============================================")

moved_count <- 0
skipped_count <- 0

for (i in 1:nrow(files_to_migrate)) {
  row <- files_to_migrate[i, ]

  # Skip if already in correct location
  if (row$original_path == row$new_path) {
    message("SKIP: ", row$filename, " (already in correct location)")
    skipped_count <- skipped_count + 1
    next
  }

  # Skip if destination exists
  if (file.exists(row$new_path)) {
    message("SKIP: ", row$filename, " (destination exists)")
    skipped_count <- skipped_count + 1
    next
  }

  # Create destination directory
  dest_dir <- dirname(row$new_path)
  if (!dir.exists(dest_dir)) {
    message("CREATE DIR: ", dest_dir)
    dir.create(dest_dir, recursive = TRUE)
  }

  # Move file
  message("MOVE: ", row$filename)
  message("  FROM: ", row$original_path)
  message("  TO:   ", row$new_path)

  success <- file.rename(row$original_path, row$new_path)

  if (success) {
    moved_count <- moved_count + 1
    message("  SUCCESS")
  } else {
    message("  FAILED - file.rename returned FALSE")
  }
}

message("")
message("==============================================")
message("Migration Complete!")
message("  Moved: ", moved_count, " files")
message("  Skipped: ", skipped_count, " files")
message("==============================================")
message("")
message("Verification:")

# Verify new structure
states <- unique(files_to_migrate$state_code[!is.na(files_to_migrate$state_code)])
for (state in states) {
  state_dir <- file.path(RDS_DIR, tolower(state))
  if (dir.exists(state_dir)) {
    period_dirs <- list.dirs(state_dir, full.names = FALSE, recursive = FALSE)
    message("  State: ", state, " -> ", length(period_dirs), " periods")
    for (period in period_dirs) {
      files_in_period <- list.files(file.path(state_dir, period), pattern = "\\.rds$")
      message("    Period: ", period, " -> ", length(files_in_period), " files")
    }
  }
}

# Check national files
national_dir <- file.path(RDS_DIR, "national")
if (dir.exists(national_dir)) {
  national_files <- list.files(national_dir, pattern = "^cfsr_profile_national_.*\\.rds$")
  message("  National files in national/: ", length(national_files))
} else {
  message("  National directory not found")
}

message("")
message("Migration script complete!")
