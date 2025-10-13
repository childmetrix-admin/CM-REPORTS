# Quick diagnostic to see sheet structure
source("D:/repo_childmetrix/r_utilities/loader.R")
source(file.path(util_root, "project_specific", "functions_cfsr_profile.R"))

commitment <- "cfsr profile"
commitment_description <- "national"
my_setup <- setup_folders("2025_02")

# Load the Maltreatment in care sheet
data_df <- find_file(
  keyword = "National",
  directory_type = "raw",
  file_type = "excel",
  sheet_name = "Maltreatment in care"
)

print("=== RAW DATA (First 10 columns, First 5 rows) ===")
print(data_df[1:5, 1:10])

print("\n=== After extract_relevant_rows ===")
data_df <- extract_relevant_rows(data_df)
print("First row (should contain period labels):")
print(data_df[1, 1:15])  # Show first 15 columns

print("\n=== Checking each column ===")
for (i in 1:min(15, ncol(data_df))) {
  val <- as.character(data_df[1, i])
  print(paste0("Column ", i, ": '", val, "'"))
}
