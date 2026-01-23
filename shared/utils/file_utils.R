# file_utils.R - File output utilities
# Internalized from utilities-core for self-containment

#' Save data frame to versioned folder structure
#'
#' Creates date-stamped output folders and saves data as CSV or Excel.
#' Uses global variables: folder_run, folder_date, commitment,
#' commitment_description, run_date
#'
#' @param df Data frame to save
#' @param ext File extension ("csv" or "xlsx")
#' @return Invisibly returns the output path
#' @export
save_to_folder_run <- function(df, ext = "csv") {

  # Build output path using global variables
  output_path <- file.path(
    folder_run,
    paste0(
      folder_date, " - ",
      commitment, " - ",
      commitment_description, " - ",
      run_date, ".", ext
    )
  )

  # Create directory if needed
  if (!dir.exists(dirname(output_path))) {
    dir.create(dirname(output_path), recursive = TRUE)
  }

  # Save based on extension
  if (ext == "csv") {
    # CSV with UTF-8 BOM for Excel compatibility
    write.csv(
      df,
      output_path,
      row.names = FALSE,
      fileEncoding = "UTF-8",
      na = ""
    )
  } else if (ext %in% c("xlsx", "xls")) {
    # Excel output - try openxlsx first, fallback to writexl, then CSV
    if (requireNamespace("openxlsx", quietly = TRUE)) {
      openxlsx::write.xlsx(df, output_path, asTable = FALSE)
      # Auto-width columns
      tryCatch({
        wb <- openxlsx::loadWorkbook(output_path)
        openxlsx::setColWidths(wb, 1, cols = 1:ncol(df), widths = "auto")
        openxlsx::saveWorkbook(wb, output_path, overwrite = TRUE)
      }, error = function(e) {
        message("Could not auto-width columns: ", e$message)
      })
    } else if (requireNamespace("writexl", quietly = TRUE)) {
      writexl::write_xlsx(df, output_path)
    } else {
      warning(
        "Neither openxlsx nor writexl available. Saving as CSV instead."
      )
      output_path <- gsub("\\.xlsx?$", ".csv", output_path)
      write.csv(
        df,
        output_path,
        row.names = FALSE,
        fileEncoding = "UTF-8",
        na = ""
      )
    }
  } else {
    stop("Unsupported file extension: ", ext)
  }

  message("Saved: ", output_path)
  return(invisible(output_path))
}
