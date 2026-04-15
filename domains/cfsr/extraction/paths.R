# paths.R - Centralized path configuration for monorepo
# Supports dual-mode: local ShareFile (S: drive) or Azure Blob Storage

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
CFSR_ROOT <- file.path(MONOREPO_ROOT, "domains/cfsr")
SHARED_ROOT <- file.path(MONOREPO_ROOT, "shared")

# Derived paths
CFSR_EXTRACTION_DIR <- file.path(CFSR_ROOT, "extraction")
CFSR_FUNCTIONS_DIR <- file.path(CFSR_ROOT, "functions")
CFSR_DATA_DIR <- file.path(CFSR_ROOT, "data")
CFSR_PROCESSED_DIR <- file.path(CFSR_DATA_DIR, "csv")
CFSR_APP_DATA_DIR <- file.path(CFSR_DATA_DIR, "rds")
SHARED_UTILS_DIR <- file.path(SHARED_ROOT, "utils")

# --- Data source configuration (ShareFile or Azure Blob) ---
CM_DATA_SOURCE <- Sys.getenv("CM_DATA_SOURCE", "sharefile")

if (CM_DATA_SOURCE == "azure") {
  AZURE_BLOB_ENDPOINT <- Sys.getenv("AZURE_BLOB_ENDPOINT", "")
  AZURE_BLOB_CONTAINER_RAW <- Sys.getenv("AZURE_BLOB_CONTAINER_RAW", "raw")
  AZURE_BLOB_CONTAINER_PROCESSED <- Sys.getenv("AZURE_BLOB_CONTAINER_PROCESSED", "processed")
  AZURE_STORAGE_KEY <- Sys.getenv("AZURE_STORAGE_KEY", "")

  if (AZURE_BLOB_ENDPOINT == "") {
    stop("CM_DATA_SOURCE is 'azure' but AZURE_BLOB_ENDPOINT is not set.")
  }

  SHAREFILE_BASE <- NULL
  message("Data source: Azure Blob Storage (", AZURE_BLOB_ENDPOINT, ")")
} else {
  SHAREFILE_BASE <- Sys.getenv("SHAREFILE_BASE", "S:/Shared Folders")
  AZURE_BLOB_ENDPOINT <- NULL
  message("Data source: ShareFile (", SHAREFILE_BASE, ")")
}

#' Initialize Azure Blob client (lazy-loaded)
#' @return AzureStor blob endpoint object, or NULL if not using Azure
get_blob_endpoint <- function() {
  if (CM_DATA_SOURCE != "azure") return(NULL)

  if (!requireNamespace("AzureStor", quietly = TRUE)) {
    stop("AzureStor package required for Azure mode. Install with: install.packages('AzureStor')")
  }

  AzureStor::blob_endpoint(
    endpoint = AZURE_BLOB_ENDPOINT,
    key = AZURE_STORAGE_KEY
  )
}

#' Download a blob to a local temp file
#' @param container_name Blob container name ("raw" or "processed")
#' @param blob_path Path within the container
#' @return Local file path to the downloaded file
download_blob <- function(container_name, blob_path) {
  endpoint <- get_blob_endpoint()
  container <- AzureStor::blob_container(endpoint, container_name)

  local_path <- file.path(tempdir(), basename(blob_path))
  dir.create(dirname(local_path), showWarnings = FALSE, recursive = TRUE)

  AzureStor::download_blob(container, blob_path, local_path, overwrite = TRUE)
  return(local_path)
}

#' Upload a local file to Azure Blob
#' @param local_path Path to local file
#' @param container_name Blob container name
#' @param blob_path Destination path within container
upload_blob <- function(local_path, container_name, blob_path) {
  endpoint <- get_blob_endpoint()
  container <- AzureStor::blob_container(endpoint, container_name)
  AzureStor::upload_blob(container, local_path, blob_path)
  message("Uploaded to blob: ", container_name, "/", blob_path)
}

#' List blobs in a container path
#' @param container_name Blob container name
#' @param prefix Path prefix to filter
#' @return Character vector of blob names
list_blobs <- function(container_name, prefix = "") {
  endpoint <- get_blob_endpoint()
  container <- AzureStor::blob_container(endpoint, container_name)
  blobs <- AzureStor::list_blobs(container, prefix = prefix)
  return(blobs$name)
}

# Helper function to build RDS output path with new hierarchical structure
# New structure:
# - National: domains/cfsr/data/rds/national/cfsr_profile_national_{period}.rds
# - State-specific: domains/cfsr/data/rds/{state}/{period}/{STATE}_cfsr_profile_{type}_{period}.rds
build_rds_path <- function(state_code, period, type) {
  # Validate type
  valid_types <- c("national", "rsp", "observed", "state")
  if (!type %in% valid_types) {
    stop("Invalid type '", type, "'. Must be one of: ", paste(valid_types, collapse = ", "))
  }

  if (CM_DATA_SOURCE == "azure") {
    # Azure mode: return blob path (relative to processed container)
    if (type == "national") {
      return(paste0("rds/national/cfsr_profile_national_", period, ".rds"))
    }
    state_code <- toupper(state_code)
    return(paste0("rds/", tolower(state_code), "/", period, "/",
                  state_code, "_cfsr_profile_", type, "_", period, ".rds"))
  }

  # Local mode: return filesystem path
  if (type == "national") {
    national_dir <- file.path(CFSR_APP_DATA_DIR, "national")
    if (!dir.exists(national_dir)) {
      dir.create(national_dir, recursive = TRUE)
    }
    filename <- paste0("cfsr_profile_national_", period, ".rds")
    return(file.path(national_dir, filename))
  }

  state_code <- toupper(state_code)
  state_dir <- file.path(CFSR_APP_DATA_DIR, tolower(state_code), period)

  if (!dir.exists(state_dir)) {
    dir.create(state_dir, recursive = TRUE)
  }

  filename <- paste0(state_code, "_cfsr_profile_", type, "_", period, ".rds")
  return(file.path(state_dir, filename))
}

#' Save RDS data - works for both local filesystem and Azure Blob
#' @param data R object to save
#' @param rds_path Path returned by build_rds_path()
save_rds_data <- function(data, rds_path) {
  if (CM_DATA_SOURCE == "azure") {
    local_tmp <- file.path(tempdir(), basename(rds_path))
    dir.create(dirname(local_tmp), showWarnings = FALSE, recursive = TRUE)
    saveRDS(data, local_tmp)
    upload_blob(local_tmp, AZURE_BLOB_CONTAINER_PROCESSED, rds_path)
    unlink(local_tmp)
  } else {
    dir.create(dirname(rds_path), showWarnings = FALSE, recursive = TRUE)
    saveRDS(data, rds_path)
  }
  message("Saved RDS: ", rds_path)
}

#' Load RDS data - works for both local filesystem and Azure Blob
#' @param rds_path Path returned by build_rds_path()
#' @return R object
load_rds_data <- function(rds_path) {
  if (CM_DATA_SOURCE == "azure") {
    local_tmp <- download_blob(AZURE_BLOB_CONTAINER_PROCESSED, rds_path)
    data <- readRDS(local_tmp)
    unlink(local_tmp)
    return(data)
  }
  return(readRDS(rds_path))
}

#' Check if RDS data exists - works for both local filesystem and Azure Blob
#' @param rds_path Path returned by build_rds_path()
#' @return Logical TRUE if exists, FALSE otherwise
rds_exists <- function(rds_path) {
  if (CM_DATA_SOURCE == "azure") {
    # Check if blob exists by listing with exact prefix
    blobs <- list_blobs(AZURE_BLOB_CONTAINER_PROCESSED, prefix = rds_path)
    return(length(blobs) > 0 && any(blobs == rds_path))
  }
  return(file.exists(rds_path))
}

# Output message
message("Monorepo paths configured:")
message("  Root: ", MONOREPO_ROOT)
message("  CFSR: ", CFSR_ROOT)
message("  Data: ", CFSR_DATA_DIR)
message("  Source: ", CM_DATA_SOURCE)
