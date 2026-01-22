# Testing Requirements

## Minimum Test Coverage: 80%

Test Types (when applicable):
1. **Unit Tests** - Individual functions, data transformations (`testthat`)
2. **Integration Tests** - Shiny app interactions (`shinytest2`)
3. **Manual Testing** - Shiny apps require visual/interactive validation

## R Testing with testthat

Use `testthat` package for R testing:

```r
library(testthat)

test_that("load_cfsr_data returns valid data frame", {
  result <- load_cfsr_data("test_file.rds")

  expect_s3_class(result, "data.frame")
  expect_gt(nrow(result), 0)
  expect_true("indicator" %in% names(result))
})

test_that("calculate_rsp handles missing data", {
  data <- data.frame(value = c(1, NA, 3))

  result <- calculate_rsp(data)

  expect_false(anyNA(result))
})
```

## Shiny App Testing

Use `shinytest2` for Shiny app integration tests:

```r
library(shinytest2)

test_that("app loads and displays data", {
  app <- AppDriver$new(app_dir = "path/to/app")

  # Check initial state
  app$expect_values()

  # Interact with app
  app$set_inputs(state = "MD")
  app$set_inputs(profile = "2025_02")

  # Verify outputs
  app$expect_values(output = "summary_table")
})
```

## Test-Driven Development (TDD)

RECOMMENDED workflow for new functions:
1. Write test first (RED)
2. Run test - it should FAIL
3. Write minimal implementation (GREEN)
4. Run test - it should PASS
5. Refactor (IMPROVE)
6. Verify coverage (80%+)

**Note**: Shiny apps require manual testing alongside automated tests.

## Test Coverage

Check coverage with `covr` package:

```r
library(covr)

# Check package coverage
cov <- package_coverage()
report(cov)

# Check specific files
cov <- file_coverage("R/functions.R", "tests/testthat/test-functions.R")
```

## Troubleshooting Test Failures

1. Check test isolation (tests shouldn't depend on each other)
2. Verify mock data matches expected structure
3. Ensure file paths are correct (use `testthat::test_path()`)
4. Fix implementation, not tests (unless tests are wrong)

## Testing Checklist

Before marking work complete:
- [ ] Unit tests written for new functions
- [ ] Tests use `test_that()` blocks with descriptive names
- [ ] Assertions use `expect_*()` functions
- [ ] All tests pass
- [ ] Coverage is 80%+ (for non-Shiny code)
- [ ] Shiny apps manually tested locally
