# state_utils.R - State code utilities

#' CFSR State Codes
#'
#' Single source of truth for state code to name mapping
#' 52 jurisdictions: 50 states + DC + PR
#'
#' Format: c("CODE" = "Full Name")
STATE_CODES <- c(
  "AL" = "Alabama", "AK" = "Alaska", "AZ" = "Arizona", "AR" = "Arkansas",
  "CA" = "California", "CO" = "Colorado", "CT" = "Connecticut", "DE" = "Delaware",
  "FL" = "Florida", "GA" = "Georgia", "HI" = "Hawaii", "ID" = "Idaho",
  "IL" = "Illinois", "IN" = "Indiana", "IA" = "Iowa", "KS" = "Kansas",
  "KY" = "Kentucky", "LA" = "Louisiana", "ME" = "Maine", "MD" = "Maryland",
  "MA" = "Massachusetts", "MI" = "Michigan", "MN" = "Minnesota", "MS" = "Mississippi",
  "MO" = "Missouri", "MT" = "Montana", "NE" = "Nebraska", "NV" = "Nevada",
  "NH" = "New Hampshire", "NJ" = "New Jersey", "NM" = "New Mexico", "NY" = "New York",
  "NC" = "North Carolina", "ND" = "North Dakota", "OH" = "Ohio", "OK" = "Oklahoma",
  "OR" = "Oregon", "PA" = "Pennsylvania", "RI" = "Rhode Island", "SC" = "South Carolina",
  "SD" = "South Dakota", "TN" = "Tennessee", "TX" = "Texas", "UT" = "Utah",
  "VT" = "Vermont", "VA" = "Virginia", "WA" = "Washington", "WV" = "West Virginia",
  "WI" = "Wisconsin", "WY" = "Wyoming", "DC" = "D.C.", "PR" = "Puerto Rico"
)

#' Convert state code to full state name
#'
#' Converts 2-letter state codes to full state names using standardized mapping.
#' Handles special case: DC -> "D.C." (not "District of Columbia")
#'
#' @param state_code Character vector of 2-letter state codes (e.g., "MD", "KY", "DC")
#' @return Character vector of full state names (e.g., "Maryland", "Kentucky", "D.C.")
#' @examples
#' state_code_to_name("MD")  # Returns "Maryland"
#' state_code_to_name("DC")  # Returns "D.C."
#' state_code_to_name(c("MD", "KY"))  # Vectorized
#' @export
state_code_to_name <- function(state_code) {
  state_code_upper <- toupper(state_code)
  state_name <- STATE_CODES[state_code_upper]

  if (any(is.na(state_name))) {
    warning("Unrecognized state code(s): ", paste(state_code[is.na(state_name)], collapse = ", "))
  }

  return(unname(state_name))
}

#' Convert full state name to state code
#'
#' Converts full state names to 2-letter state codes using standardized mapping.
#' Handles special cases: "D.C." and "District of Columbia" both -> "DC"
#'
#' @param state_name Character vector of full state names (e.g., "Maryland", "D.C.")
#' @return Character vector of 2-letter state codes (e.g., "MD", "DC")
#' @examples
#' state_name_to_code("Maryland")  # Returns "MD"
#' state_name_to_code("D.C.")  # Returns "DC"
#' state_name_to_code("District of Columbia")  # Returns "DC"
#' @export
state_name_to_code <- function(state_name) {
  # Normalize D.C. variations before lookup
  state_name_normalized <- ifelse(state_name == "District of Columbia", "D.C.", state_name)

  # Create reverse mapping from STATE_CODES
  state_names_to_codes <- setNames(names(STATE_CODES), STATE_CODES)
  state_code <- state_names_to_codes[state_name_normalized]

  if (any(is.na(state_code))) {
    warning("Unrecognized state name(s): ", paste(state_name[is.na(state_code)], collapse = ", "))
  }

  return(unname(state_code))
}

#' Validate state code
#'
#' Checks if a state code is valid (exists in STATE_CODES)
#'
#' @param state_code Character, 2-letter state code
#' @return TRUE if valid, stops with error if invalid
#' @export
validate_state <- function(state_code) {
  state_code_upper <- toupper(state_code)

  if (!state_code_upper %in% names(STATE_CODES)) {
    stop("Invalid state code: '", state_code, "'\n",
         "Valid codes: ", paste(head(names(STATE_CODES), 10), collapse = ", "), ", ...",
         call. = FALSE)
  }

  return(TRUE)
}
