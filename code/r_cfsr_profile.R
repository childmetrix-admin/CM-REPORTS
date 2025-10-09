# Title:          Generic starter template

# Purpose:        Joy

#####################################
# NOTES ----
#####################################


#####################################
# TO DO ----
#####################################


#####################################
# OTHER DEPENDENCIES (e.g., files) ----
#####################################

# 1. ...
# 2. ...

#####################################
# LIBRARIES & UTILITIES ----
#####################################

# Load packages and generic functions
source("D:/repo_childmetrix/r_utilities/loader.R")

# Load functions specific to this project
# source(file.path(util_root, "project_specific", "functions_mdcps.R"), chdir = FALSE)

########################################
# FOLDER PATHS & DIRECTORY STRUCTURE ----
########################################

# Base data folder
base_data_dir <- "D:/repo_mdcps_suspension_period/r_2.9.a/data"

# File name elements (e.g., 2024_01 - [commitment] - [commitment_description] - 2024-02-15.csv")
# e.g., save_to_folder_run(claiming_df)
commitment <- "cfsr"
commitment_description <- ""  # e.g. "Hotel analysis"
commitment_description <- "MIC Manual Review Verification"

# Establish current period and set up folders and global variables
my_setup <- setup_folders("2025_Q1")

########################################
# LOAD FILES ----
########################################

data_df <- find_file(keyword = "my file", "raw", file_type = "excel")

########################################
# SANITIZE AND DATA CLEANING -- 
########################################
  
# Clean names with janitor
# mdcps_df <- mdcps_df %>% clean_names()

########################################
# CREATE FIELDS, FLAGS, CALCULATIONS ----
########################################



########################################
# SAVE ----
########################################

# e.g., save_to_folder_run(claiming_df)
