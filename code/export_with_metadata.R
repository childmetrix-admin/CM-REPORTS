# Optional: Create enriched export with metadata joined
# Use this if you need to share a single self-contained file

export_with_metadata <- function(ind_data_file, output_file = NULL) {

  # Load fact data
  ind_data <- read.csv(ind_data_file)

  # Load dictionary
  dict <- read.csv("code/cfsr_round4_indicators_dictionary.csv")

  # Join metadata
  enriched_data <- ind_data %>%
    left_join(
      dict %>% select(
        indicator,
        indicator_short,
        category,
        description,
        national_standard,
        direction_desired,
        direction_legend,
        decimal_precision,
        scale,
        format
      ),
      by = "indicator"
    )

  # Reorder columns (facts first, then metadata)
  enriched_data <- enriched_data %>%
    select(
      # Core identifiers
      state, indicator, indicator_short, category,
      # Performance data
      period, period_meaningful, denominator, numerator, performance, state_rank,
      # Metadata
      census_year, as_of_date, profile_version, source,
      # Dictionary metadata
      description, national_standard, direction_desired, direction_legend,
      decimal_precision, scale, format
    )

  # Save
  if (is.null(output_file)) {
    output_file <- gsub("\\.csv$", "_with_metadata.csv", ind_data_file)
  }

  write.csv(enriched_data, output_file, row.names = FALSE, fileEncoding = "UTF-8")
  message("Enriched data saved to: ", output_file)

  return(enriched_data)
}

# Example usage:
# enriched <- export_with_metadata("data/2025_02/processed/.../2025_02 - cfsr profile - national - 2025-10-09.csv")
