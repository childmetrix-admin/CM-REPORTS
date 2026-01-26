# paths.R - Centralized path configuration for monorepo

# Detect monorepo root by finding CLAUDE.md or .git
detect_monorepo_root <- function() {
  current <- getwd()

  while (current != dirname(current)) {  # Stop at filesystem root
    if (file.exists(file.path(current, "CLAUDE.md")) ||
        file.exists(file.path(current, ".git"))) {
      return(current)
    }
    current <- dirname(current)
  }

  # Fallback to environment variable
  root <- Sys.getenv("CM_REPORTS_ROOT")
  if (root != "") return(root)

  stop("Cannot detect monorepo root. Set CM_REPORTS_ROOT environment variable.")
}

# Set base paths
MONOREPO_ROOT <- detect_monorepo_root()
CFSR_ROOT <- file.path(MONOREPO_ROOT, "cfsr")
SHARED_ROOT <- file.path(MONOREPO_ROOT, "shared")

# Derived paths
CFSR_EXTRACTION_DIR <- file.path(CFSR_ROOT, "extraction")
CFSR_FUNCTIONS_DIR <- file.path(CFSR_ROOT, "functions")
CFSR_DATA_DIR <- file.path(CFSR_ROOT, "data")
CFSR_PROCESSED_DIR <- file.path(CFSR_DATA_DIR, "csv")
CFSR_APP_DATA_DIR <- file.path(CFSR_DATA_DIR, "rds")
SHARED_UTILS_DIR <- file.path(SHARED_ROOT, "utils")
SHAREFILE_BASE <- "S:/Shared Folders"

# Helper function to build RDS output path with new hierarchical structure
# New structure:
# - National: cfsr/data/rds/national/cfsr_profile_national_{period}.rds
# - State-specific: cfsr/data/rds/{state}/{period}/{STATE}_cfsr_profile_{type}_{period}.rds
build_rds_path <- function(state_code, period, type) {
  # Validate type
  valid_types <- c("national", "rsp", "observed", "state")
  if (!type %in% valid_types) {
    stop("Invalid type '", type, "'. Must be one of: ", paste(valid_types, collapse = ", "))
  }

  # National files go in national/ subdirectory (shared across all states)
  if (type == "national") {
    national_dir <- file.path(CFSR_APP_DATA_DIR, "national")
    if (!dir.exists(national_dir)) {
      dir.create(national_dir, recursive = TRUE)
    }
    filename <- paste0("cfsr_profile_national_", period, ".rds")
    return(file.path(national_dir, filename))
  }

  # State-specific files go in state/period subdirectories
  state_code <- toupper(state_code)
  state_dir <- file.path(CFSR_APP_DATA_DIR, tolower(state_code), period)

  # Create directory if it doesn't exist
  if (!dir.exists(state_dir)) {
    dir.create(state_dir, recursive = TRUE)
  }

  filename <- paste0(state_code, "_cfsr_profile_", type, "_", period, ".rds")
  return(file.path(state_dir, filename))
}

# Output message
message("Monorepo paths configured:")
message("  Root: ", MONOREPO_ROOT)
message("  CFSR: ", CFSR_ROOT)
message("  Data: ", CFSR_DATA_DIR)
