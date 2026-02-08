# R Code Style Guide - ChildMetrix cm-reports

## Purpose

This guide establishes consistent structure and organization for R scripts across the cm-reports codebase to improve readability, maintainability, and collaboration.

## Scope

**Applies to:**
- Data extraction scripts (`domains/cfsr/extraction/`)
- Analysis scripts (`domains/cfsr/functions/`)
- State-specific scripts (`states/{state}/scripts/`)
- Utility scripts

**Does NOT apply to:**
- Shiny app.R files (these have different structure needs)
- Test files (testthat has its own conventions)
- Simple utility functions (<50 lines)

---

## Script Structure

### Template

Use the template file: `templates/r_script_template.R`

### Required Sections

All R scripts should include these sections in this order:

#### 1. Title Section

```r
#####################################
#####################################
# Script Title ----
#####################################
#####################################

# Purpose: Brief 1-3 sentence description of what this script does
#
# Inputs: List key input files, data sources, or parameters
# Outputs: List key output files or artifacts
#
# Author: Your Name (optional)
# Last Updated: YYYY-MM-DD (optional)
```

**Guidelines:**
- Title should be descriptive but concise
- Purpose statement explains **what** and **why**, not **how**
- Document key inputs/outputs for easier troubleshooting
- Include author/date if script is shared across team members

#### 2. Notes Section (Optional but Recommended)

```r
#####################################
# NOTES ----
#####################################

# Important context, background, or caveats
# - Point 1
# - Point 2
```

**Use this section for:**
- Background context (where does the data come from?)
- Important assumptions or limitations
- Dependencies on external systems or files
- Common pitfalls or gotchas

#### 3. Libraries & Configuration

```r
#####################################
# LIBRARIES & CONFIGURATION ----
#####################################

# Load required packages
library(tidyverse)
library(pdftools)

# Source dependencies
source("path/to/functions.R")

# Set configuration variables
state_code <- "MD"
output_folder <- "output/cfsr/"
```

**Guidelines:**
- Load ALL packages at the top (not scattered throughout script)
- Source external functions here
- Define configuration variables (file paths, constants, parameters)
- Add comments for non-obvious settings

#### 4. Main Processing Sections

```r
#####################################
# MAIN PROCESSING ----
#####################################

# --------------------------------------
# Section 1: Descriptive Heading ----
# --------------------------------------

# Code here

# --------------------------------------
# Section 2: Descriptive Heading ----
# --------------------------------------

# Code here
```

**Guidelines:**
- Use descriptive section names (not "Step 1", "Step 2")
- Good: "Extract table from PDF", "Calculate performance metrics"
- Bad: "Process data", "Do stuff"
- Break large sections into logical subsections

#### 5. Cleanup & Finalize (Optional)

```r
#####################################
# CLEANUP & FINALIZE ----
#####################################

# Remove temporary objects
rm(temp_var)

# Save outputs
write_csv(output_data, "path/to/output.csv")
```

---

## Heading Hierarchy

Use this consistent hierarchy for all R scripts:

### Level 1: Major Sections

```r
#####################################
# MAJOR SECTION ----
#####################################
```

- All caps
- 5 hash marks on each side
- Four space dashes after title
- Used for: LIBRARIES, MAIN PROCESSING, CLEANUP, etc.

### Level 2: Subsections

```r
# --------------------------------------
# Subsection Title ----
# --------------------------------------
```

- Title case
- 38 dashes above and below
- Four space dashes after title
- Used for: logical groupings within major sections

### Level 3: Minor Subsections (Optional)

```r
# Subsection title
# -----------------------------------
```

- Sentence case
- Dashes below only
- Used for: small subsections or clarifying comments

### Level 4: Inline Comments

```r
# Simple inline comment (no dashes)
```

---

## Naming Conventions

### Variables and Functions

Follow **tidyverse style guide**:

```r
# GOOD: snake_case
user_name <- "Kurt"
calculate_performance <- function(numerator, denominator) {}

# BAD: camelCase or PascalCase
userName <- "Kurt"
CalculatePerformance <- function(numerator, denominator) {}
```

### Constants

Use `SCREAMING_SNAKE_CASE`:

```r
MAX_ITERATIONS <- 100
DEFAULT_STATE <- "MD"
```

### File Names

Use `snake_case.R`:

```r
# GOOD
profile_pdf_observed.R
data_prep.R
functions_cfsr_profile_shared.R

# BAD
ProfilePDFObserved.R
dataPrep.R
functions-cfsr-profile-shared.R
```

---

## Code Organization

### Keep Functions Focused

- One function should do one thing
- Aim for <50 lines per function
- Extract complex logic into helper functions

### Avoid Deep Nesting

```r
# BAD: Deep nesting (>4 levels)
if (condition1) {
  if (condition2) {
    if (condition3) {
      if (condition4) {
        # do something
      }
    }
  }
}

# GOOD: Early returns or intermediate variables
if (!condition1) return(NULL)
if (!condition2) return(NULL)

result <- some_function()
if (is.valid(result)) {
  process(result)
}
```

### Use Tidyverse Patterns

```r
# GOOD: Tidyverse pipe
data %>%
  filter(status == "active") %>%
  select(id, name, value) %>%
  arrange(desc(value))

# Avoid: Base R when tidyverse is clearer
subset(data, status == "active")[, c("id", "name", "value")]
```

---

## Documentation

### Function Documentation

Use roxygen2 style for exported functions:

```r
#' Calculate RSP score
#'
#' Calculates risk-standardized performance based on observed and expected values
#'
#' @param observed Observed performance value
#' @param expected Expected performance value
#' @param national National performance average
#' @return RSP score (numeric)
#' @export
calculate_rsp <- function(observed, expected, national) {
  # Implementation
}
```

### Inline Comments

```r
# GOOD: Explain WHY, not WHAT
# Use >= instead of > to include edge cases per CB guidance
if (performance >= threshold) {}

# BAD: Redundant comment
# Check if performance is greater than or equal to threshold
if (performance >= threshold) {}
```

---

## Error Handling

Always include error handling for:
- File operations (missing files, wrong paths)
- Data transformations (missing columns, wrong types)
- External dependencies (APIs, databases)

```r
# Check file exists
if (!file.exists(input_file)) {
  stop("Input file not found: ", input_file)
}

# Check required columns
required_cols <- c("state", "indicator", "performance")
if (!all(required_cols %in% names(data))) {
  stop("Missing required columns: ",
       paste(setdiff(required_cols, names(data)), collapse = ", "))
}

# Use tryCatch for risky operations
result <- tryCatch(
  {
    risky_operation()
  },
  error = function(e) {
    message("Operation failed: ", e$message)
    return(NULL)
  }
)
```

---

## Code Quality Checklist

Before committing code, verify:

- [ ] Script follows template structure
- [ ] All sections have descriptive headings
- [ ] Purpose statement is clear and accurate
- [ ] All packages loaded at top
- [ ] Variable names use `snake_case`
- [ ] Functions are focused (<50 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Error handling for file/data operations
- [ ] No hardcoded paths (use config variables)
- [ ] No debugging `print()` or `cat()` statements left in code

---

## Migration Strategy

### For Existing Scripts

**Gradual approach:**
1. Update scripts as you touch them (opportunistic refactoring)
2. Prioritize frequently-used scripts first
3. Don't rewrite working code just for style compliance

**When to update:**
- Adding new features
- Fixing bugs
- Code review identifies readability issues
- Script is hard to understand or maintain

### For New Scripts

**Always start with the template:**
1. Copy `templates/r_script_template.R`
2. Fill in title, purpose, inputs/outputs
3. Add your code within the structure
4. Code review will check for compliance

---

## Reference Examples

**Well-structured scripts in this codebase:**
- `domains/cfsr/extraction/profile_pdf_observed.R` - Full example with all sections
- `domains/cfsr/extraction/run_profile.R` - Orchestrator script
- `domains/cfsr/functions/data_prep.R` - Clean function library

**Review these before creating new scripts.**

---

## Questions or Suggestions

See something that could be improved? Open an issue or discuss with the team.

**Last Updated:** February 2026
