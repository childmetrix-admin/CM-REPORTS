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

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
source("D:/repo_childmetrix/utilities-core/loader.R")

# Load CFSR profile functions (RSP data)
source("D:/repo_childmetrix/cfsr-profile/code/functions/functions_cfsr_profile_rsp.R")

########################################
# CONFIGURATION ----
########################################

# IMPORTANT: Set the state and profile period here
# state_code: lowercase 2-letter state code (e.g., "md", "ky")
# profile_period: format "YYYY_MM" (e.g., "2025_02", "2025_08")
state_code <- "md"
profile_period <- "2025_02"

########################################
# FOLDER PATHS & DIRECTORY STRUCTURE ----
########################################

# Establish current period and set up folders and global variables
# Uses CFSR-specific setup for multi-state support
my_setup <- setup_cfsr_folders(profile_period, state_code)

# Base data folder (from ShareFile)
base_data_dir <- file.path("S:/Shared Folders", state_code, "cfsr/uploads", profile_period)

# Set file name elements for save_to_folder_run()
# Include state code in filename for multi-state support
folder_date <- paste0(state_code, "_", profile_period)
commitment <- "cfsr profile"
commitment_description <- "rsp"

########################################
# EXTRACT RSP DATA FROM TEXT FILE ----
########################################

# Look for Adobe-exported text file
txt_file <- file.path(base_data_dir, "adobe_to_accessible_text.txt")

if (file.exists(txt_file)) {
  message("\n=== Extracting RSP data from text file ===")
  message("Source: ", txt_file)

  # Extract RSP data using CFSR profile function
  rsp_data <- extract_cfsr_profile_txt(txt_file)

  # View results
  message("Extracted ", nrow(rsp_data), " indicator-period combinations")
  print(head(rsp_data, 10))

  # Save to processed data folder
  # Structure: data/processed/{state}/{period}/{date}/rsp/
  output_dir <- file.path(folder_processed, "rsp")
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  output_file <- file.path(output_dir,
                           paste0(folder_date, " - ", commitment, " - ", commitment_description, ".csv"))
  write.csv(rsp_data, output_file, row.names = FALSE)
  message("\n✓ Saved to: ", output_file)

} else {
  warning("Text file not found: ", txt_file)
  message("\nTo process RSP data:")
  message("1. Export PDF to text using Adobe Acrobat")
  message("2. File > Export To > Text (Accessible Text)")
  message("3. Save as 'adobe_to_accessible_text.txt' in:")
  message("   ", base_data_dir)
}

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
