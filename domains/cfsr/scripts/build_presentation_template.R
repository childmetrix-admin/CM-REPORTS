# build_presentation_template.R — generate blank officer-compatible .pptx templates
#
# Purpose: Write states/{ky,md}/_assets/*-presentation-template.pptx (16:9, default layouts).
# Inputs: None (requires Python 3 + python-pptx).
# Outputs: ky-presentation-template.pptx, md-presentation-template.pptx
#
# Run from monorepo root:
#   Rscript domains/cfsr/scripts/build_presentation_template.R

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(file_arg)) {
  dirname(sub("^--file=", "", file_arg[1]))
} else {
  getwd()
}
root <- normalizePath(file.path(script_dir, "..", "..", ".."), winslash = "/", mustWork = TRUE)
setwd(root)

py_script <- file.path(root, "domains", "cfsr", "scripts", "build_presentation_template.py")
if (!file.exists(py_script)) {
  stop("Missing: ", py_script)
}

py <- Sys.which("python")
if (py == "") py <- Sys.which("python3")
if (py == "") stop("Python not found on PATH; install Python 3 to build templates.")

rc <- system2(py, args = py_script, wait = TRUE, stdout = FALSE, stderr = FALSE)
if (rc != 0) {
  stop("build_presentation_template.py failed with exit code ", rc)
}

message("Templates OK.")
