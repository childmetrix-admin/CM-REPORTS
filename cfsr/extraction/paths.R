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

# Output message
message("Monorepo paths configured:")
message("  Root: ", MONOREPO_ROOT)
message("  CFSR: ", CFSR_ROOT)
message("  Data: ", CFSR_DATA_DIR)
