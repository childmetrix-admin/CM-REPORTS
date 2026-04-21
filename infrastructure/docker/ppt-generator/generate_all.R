# generate_all.R — Container entrypoint for batch PPT generation with screenshots
#
# Usage: Rscript generate_all.R <state> <period1> [period2] [period3] ...
# Example: Rscript generate_all.R md 2025_02 2025_08 2026_02
#
# Environment variables required:
#   AZURE_BLOB_ENDPOINT, AZURE_STORAGE_KEY, AZURE_BLOB_CONTAINER_PROCESSED
#   CM_PUBLIC_MEASURES_URL, CM_PUBLIC_SUMMARY_URL

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript generate_all.R <state> <period1> [period2] ...")
}

state <- args[1]
periods <- args[-1]

root <- Sys.getenv("CM_REPORTS_ROOT", "/app")
setwd(root)

message("==============================================")
message("ChildMetrix CFSR PowerPoint Generator")
message("==============================================")
message(sprintf("State: %s", toupper(state)))
message(sprintf("Periods: %s", paste(periods, collapse = ", ")))
message(sprintf("Working directory: %s", getwd()))
message("")

# Verify Chrome is available
chrome_path <- Sys.getenv("CHROMOTE_CHROME", "/usr/bin/google-chrome")
if (!file.exists(chrome_path)) {
  stop("Chrome not found at: ", chrome_path)
}
message(sprintf("Chrome: %s", chrome_path))

# Verify Azure config
blob_endpoint <- Sys.getenv("AZURE_BLOB_ENDPOINT", "")
if (blob_endpoint == "") {
  stop("AZURE_BLOB_ENDPOINT not set")
}
message(sprintf("Blob endpoint: %s", blob_endpoint))
message("")

# Headless Chrome in Azure Container Instances / Docker requires no-sandbox and small /dev/shm
Sys.setenv(
  GOOGLE_CHROME = chrome_path,
  CHROMOTE_CHROME = chrome_path
)
tryCatch(
  {
    if (requireNamespace("chromote", quietly = TRUE)) {
      base_args <- tryCatch(
        chromote::default_chrome_args(),
        error = function(e) c("--headless=new", "--remote-debugging-port=0")
      )
      chromote::set_chrome_args(unique(c(
        base_args,
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--window-size=1200,800"
      )))
      message("chromote: Chrome args set for container (no-sandbox, disable-dev-shm-usage)")
    } else {
      warning("chromote not installed — webshot2 may fail in ACI")
    }
  },
  error = function(e) {
    warning("Could not configure chromote: ", conditionMessage(e))
  }
)

# Load required packages
suppressPackageStartupMessages({
  library(AzureStor)
})

# Source the PPT generator
source(file.path(root, "domains", "cfsr", "functions", "functions_cfsr_profile_ppt.R"))

# Process each period
results <- list()
for (period in periods) {
  message("----------------------------------------------")
  message(sprintf("Processing: %s - %s", toupper(state), period))
  message("----------------------------------------------")
  
  tryCatch({
    # Generate with auto-capture enabled
    ppt_path <- generate_cfsr_presentation(
      state = state,
      period = period,
      auto_capture = TRUE
    )
    
    results[[period]] <- list(success = TRUE, path = ppt_path)
    message(sprintf("SUCCESS: %s", ppt_path))
    
    # Upload to blob storage
    message("Uploading to Azure Blob Storage...")
    
    storage_key <- Sys.getenv("AZURE_STORAGE_KEY", "")
    container_name <- Sys.getenv("AZURE_BLOB_CONTAINER_PROCESSED", "processed")
    
    if (nzchar(storage_key)) {
      endpoint <- storage_endpoint(blob_endpoint, key = storage_key)
      container <- storage_container(endpoint, container_name)
      
      blob_path <- sprintf(
        "%s/cfsr/presentations/%s/%s",
        tolower(state),
        period,
        basename(ppt_path)
      )
      
      storage_upload(container, ppt_path, blob_path)
      message(sprintf("Uploaded to: %s/%s", container_name, blob_path))
    } else {
      message("AZURE_STORAGE_KEY not set - skipping blob upload")
    }
    
  }, error = function(e) {
    results[[period]] <<- list(success = FALSE, error = conditionMessage(e))
    message(sprintf("FAILED: %s", conditionMessage(e)))
    message("----------------------------------------------")
    print(e)
    if (length(sys.calls()) > 0) {
      try(traceback(2L), silent = TRUE)
    }
  })
  
  message("")
}

# Summary
message("==============================================")
message("SUMMARY")
message("==============================================")
successes <- sum(sapply(results, function(x) x$success))
failures <- length(results) - successes
message(sprintf("Total: %d | Success: %d | Failed: %d", length(results), successes, failures))

if (failures > 0) {
  message("")
  message("Failed periods:")
  for (period in names(results)) {
    if (!results[[period]]$success) {
      message(sprintf("  %s: %s", period, results[[period]]$error))
    }
  }
  quit(status = 1)
}

message("")
message("All presentations generated successfully!")
quit(status = 0)
