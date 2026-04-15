#####################################
# CFSR Shiny apps — deployment note ----
#####################################
#
# Purpose: This file previously launched Shiny apps from R for local development.
# The platform now uses Azure Blob Storage only; apps run in Azure Container Apps
# (or locally via Docker with Azure credentials). Do not source this file expecting
# a local http server — use the Dockerfiles under infrastructure/docker/shiny/ instead.
#
# See README.md and CLAUDE.md ("Docker Containers", "Running CFSR Apps").

stop(
  "CFSR Shiny apps are not started from this R script.\n",
  "Build and run: infrastructure/docker/shiny/app_measures/ and app_summary/\n",
  "with AZURE_BLOB_ENDPOINT and related storage environment variables set.",
  call. = FALSE
)
