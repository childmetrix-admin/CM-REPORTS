# generate_ppt.R — CLI entrypoint for CFSR profile PowerPoint generation
#
# Purpose: Load domains/cfsr/functions/functions_cfsr_profile_ppt.R and run generate_cfsr_presentation().
# Inputs: state, period as trailing args; optional env flags (see below).
# Outputs: states/{state}/cfsr/presentations/{period}/{STATE}_CFSR_Presentation_{period}.pptx
#
# Requires: officer, tidyverse, glue, yaml, AzureStor + AZURE_* when not using local RDS.
# Optional auto-capture: webshot2 + Chrome; set AUTO_CAPTURE=1
#
# Usage (from monorepo root):
#   Rscript domains/cfsr/scripts/generate_ppt.R md 2025_02
#   $env:CFSR_PPT_USE_LOCAL_RDS="1"; Rscript domains/cfsr/scripts/generate_ppt.R md 2025_02
#   $env:AUTO_CAPTURE="1"; Rscript domains/cfsr/scripts/generate_ppt.R md 2025_02

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript domains/cfsr/scripts/generate_ppt.R <state> <period>  e.g. md 2025_02")
}

state <- args[[1]]
period <- args[[2]]

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
script_dir <- if (length(file_arg)) {
  dirname(sub("^--file=", "", file_arg[[1]]))
} else {
  getwd()
}
root <- normalizePath(file.path(script_dir, "..", "..", ".."), winslash = "/", mustWork = TRUE)
setwd(root)

source(file.path(root, "domains", "cfsr", "functions", "functions_cfsr_profile_ppt.R"))

auto_capture <- tolower(Sys.getenv("AUTO_CAPTURE", "")) %in% c("1", "true", "yes")

generate_cfsr_presentation(
  state = state,
  period = period,
  auto_capture = auto_capture
)
