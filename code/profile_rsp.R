# Title:          CFSR Profile - Risk-Standardized Performance (RSP) Data
#                 Process RSP data from state-specific CFSR Data Profile PDFs

# Purpose:        Extract Risk-Standardized Performance metrics from
#                 state-specific CFSR 4 Data Profile PDFs (Adobe text export)

#####################################
# NOTES ----
#####################################

# This file is provided to every state about every 6 months (usually February
# & August). It shows the state's performance and trends on the CFSR
# statewide data indicators, both observed and risk-standardized.
# Also shows data quality (DQ) checks the state failed.

# The RSP (Risk-Standardized Performance) metrics adjust for state-specific
# risk factors and provide fairer state-to-state comparisons.

# INPUT: Adobe-exported text file from state PDF
# - Export PDF to text using Adobe Acrobat: File > Export To > Text (Accessible Text)
# - Save as "adobe_to_accessible_text.txt" in uploads folder

# OUTPUT: Processed CSV with RSP data by indicator and period

# IMPORTANT: This script expects state_code and profile_period to be set
# by the orchestrator (run_profile.R) or manually before sourcing.

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
if (!exists("state_code") || !exists("profile_period")) {
  message("WARNING: state_code and profile_period not set.")
  message("Either run via run_profile.R or set manually before sourcing.")
}

source("D:/repo_childmetrix/utilities-core/loader.R")

# Load CFSR profile functions (RSP data)
source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_rsp.R")

########################################
# CONFIGURATION ----
########################################

# Establish current period and set up folders and global variables
# Uses CFSR-specific setup for multi-state support
my_setup <- setup_cfsr_folders(profile_period, state_code)

# Base data folder (from ShareFile)
# base_data_dir <- file.path("S:/Shared Folders", state_code, "cfsr/uploads", profile_period)

# Set file name elements for save_to_folder_run()
# Include state code in filename for multi-state support
folder_date <- paste0(state_code, "_", profile_period)
commitment <- "cfsr profile"
commitment_description <- "rsp"

########################################
# EXTRACT SHARED METADATA (ONCE) ----
########################################

# Extract metadata common to all sources (profile version and as_of_date)
metadata <- extract_shared_metadata()

########################################
# EXTRACT RSP DATA FROM TEXT FILE ----
########################################

# Look for Adobe-exported text file
txt_file <- file.path(folder_uploads, "adobe_to_accessible_text.txt")

if (!file.exists(txt_file)) {
  message("Accessible text file not found: ", txt_file)
  message("\nAttempting automatic PDF conversion...")

  # Try to find and convert PDF automatically
  txt_file <- find_and_convert_cfsr_pdf(state_code, profile_period)

  if (is.null(txt_file) || !file.exists(txt_file)) {
    warning("Automatic PDF conversion failed")
    message("\nManual conversion options:")
    message("1. RECOMMENDED: Export PDF to text using Adobe Acrobat")
    message("   - File > Export To > Text (Accessible Text)")
    message("   - Save as 'adobe_to_accessible_text.txt' in: ", folder_uploads)
    message("\n2. ALTERNATIVE: Install Python dependencies and retry:")
    message("   - pip install pdfplumber")
    message("   - Or: pip install pymupdf")
    message("\n3. FALLBACK: Install R pdftools package:")
    message("   - install.packages('pdftools')")
    stop("Cannot proceed without accessible text file")
  } else {
    message("✓ PDF successfully converted to accessible text")
  }
}

message("\n=== Extracting RSP data from text file ===")
message("Source: ", txt_file)

# Extract raw RSP data using CFSR profile function
rsp_raw <- extract_cfsr_profile_txt(txt_file)

# View results
message("Extracted ", nrow(rsp_raw), " indicator-period combinations")
print(head(rsp_raw, 10))

########################################
# PROCESS RSP DATA ----
########################################

# Add metadata columns to match national data structure
rsp_data <- rsp_raw %>%
  mutate(
    state = toupper(state_code),
    profile_ver = metadata$profile_version,
    profile_month = metadata$profile_month,
    profile_year = metadata$profile_year,
    as_of_date = metadata$as_of_date,
    source = metadata$source,
    data_type = "rsp"  # Distinguish from observed (national) data
  )

# Reorder columns for consistency
rsp_data <- rsp_data %>%
  select(
    state,
    indicator,
    period,
    rsp_value,
    rsp_numeric,
    rsp_interval,
    interval_lower,
    interval_upper,
    national_performance,
    np_numeric,
    data_quality_issue,
    profile_ver,
    profile_month,
    profile_year,
    as_of_date,
    source,
    data_type
  )

########################################
# SAVE PROCESSED DATA ----
########################################

# Create run folder matching national structure: data/processed/STATE/PERIOD/YYYY-MM-DD/rsp/
run_date <- Sys.Date()
folder_run <- file.path(folder_processed, format(run_date, "%Y-%m-%d"), "rsp")
if (!dir.exists(folder_run)) {
  dir.create(folder_run, recursive = TRUE)
  message("Created run folder: ", folder_run)
}
assign("folder_run", folder_run, envir = .GlobalEnv)
assign("run_date", run_date, envir = .GlobalEnv)

save_to_folder_run(rsp_data, "csv")

message("\n✓ RSP data processing complete")

########################################
# AUTO-RUN PREPARE_APP_DATA (FUTURE) ----
########################################

# TODO: Create prepare_app_data_rsp.R to generate RDS files for Shiny app
# Similar to national processing, but for RSP-specific visualizations

# message("\n=== Data processing complete ===")
# message("Now preparing data for Shiny app...\n")
#
# prepare_script <- "D:/repo_childmetrix/cfsr-profile/shiny_app/prepare_app_data_rsp.R"
# if (file.exists(prepare_script)) {
#   source(prepare_script)
#   message("\n=== All done! ===")
#   message("Data ready for Shiny app at profile period: ", profile_period)
# } else {
#   warning("Could not find prepare_app_data_rsp.R at: ", prepare_script)
# }
