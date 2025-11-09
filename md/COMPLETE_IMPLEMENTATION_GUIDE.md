# CFSR Tertiary Navigation - Complete Implementation Guide

## Summary

This guide completes three tasks:
1. ✅ Add tertiary navigation menu bar (State vs National, State-by-State, County-by-County)
2. Remove Shiny app header and Data Dictionary
3. Wire up all the JavaScript handlers

## Files Already Created

1. ✅ `cfsr/performance/state_vs_national.html` - Placeholder page
2. ✅ `cfsr/performance/county_by_county.html` - Placeholder page
3. ✅ Tertiary navigation HTML added to `index.html` (lines 198-205)
4. ✅ JavaScript variables and `setTertiaryActive()` function added to `index.html`

## Step 1: Complete JavaScript in index.html

Open `D:\repo_childmetrix\r_cm_reports\md\index.html` and make these edits:

### Edit 1: Update navigate() function (around line 363-368)

**FIND:**
```javascript
        // Show/hide period selector based on category and subsection
        if (currentCategory === 'cfsr' && currentSubsection === 'performance') {
          periodSelector.style.display = 'block';
        } else {
          periodSelector.style.display = 'none';
        }
```

**REPLACE WITH:**
```javascript
        // Show/hide period selector and tertiary nav based on category and subsection
        if (currentCategory === 'cfsr' && currentSubsection === 'performance') {
          periodSelector.style.display = 'block';
          cfsrTertiaryNav.style.display = 'flex';
          setTertiaryActive(currentTertiary);
        } else {
          periodSelector.style.display = 'none';
          cfsrTertiaryNav.style.display = 'none';
        }
```

### Edit 2: Update secondaryPerformance handler (around line 380-390)

**FIND:**
```javascript
      secondaryPerformance.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr') {
          currentSubsection = 'performance';
          const period = periodSelect.value;
          // Load the interactive Shiny dashboard with profile parameter
          frame.src = `cfsr/performance/index_auto.html?profile=${period}`;
          periodSelector.style.display = 'block';
          setSecondaryActive('performance');
        }
      });
```

**REPLACE WITH:**
```javascript
      secondaryPerformance.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr') {
          currentSubsection = 'performance';
          currentTertiary = 'state_by_state';
          const period = periodSelect.value;
          frame.src = `cfsr/performance/index_auto.html?profile=${period}`;
          periodSelector.style.display = 'block';
          cfsrTertiaryNav.style.display = 'flex';
          setSecondaryActive('performance');
          setTertiaryActive(currentTertiary);
        }
      });
```

### Edit 3: Update other secondary menu handlers (around lines 392-420)

Add `cfsrTertiaryNav.style.display = 'none';` to each of these three handlers:

**secondaryPresentations:**
```javascript
      secondaryPresentations.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr') {
          currentSubsection = 'presentations';
          frame.src = 'cfsr/presentations/index.html';
          periodSelector.style.display = 'none';
          cfsrTertiaryNav.style.display = 'none';  // ADD THIS LINE
          setSecondaryActive('presentations');
        }
      });
```

**secondaryDataDict:**
```javascript
      secondaryDataDict.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr') {
          currentSubsection = 'data_dictionary';
          frame.src = 'cfsr/data_dictionary/index.html';
          periodSelector.style.display = 'none';
          cfsrTertiaryNav.style.display = 'none';  // ADD THIS LINE
          setSecondaryActive('data_dictionary');
        }
      });
```

**secondaryNotes:**
```javascript
      secondaryNotes.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr') {
          currentSubsection = 'notes';
          frame.src = 'cfsr/notes/index.html';
          periodSelector.style.display = 'none';
          cfsrTertiaryNav.style.display = 'none';  // ADD THIS LINE
          setSecondaryActive('notes');
        }
      });
```

### Edit 4: Add tertiary navigation handlers (after period selector handler, around line 428)

**INSERT THIS NEW CODE** after the period selector change handler:

```javascript
      // Tertiary navigation click handlers
      tertiaryStateVsNational.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr' && currentSubsection === 'performance') {
          currentTertiary = 'state_vs_national';
          setTertiaryActive(currentTertiary);
          frame.src = 'cfsr/performance/state_vs_national.html';
        }
      });

      tertiaryStateByState.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr' && currentSubsection === 'performance') {
          currentTertiary = 'state_by_state';
          setTertiaryActive(currentTertiary);
          const period = periodSelect.value;
          frame.src = `cfsr/performance/index_auto.html?profile=${period}`;
        }
      });

      tertiaryCountyByCounty.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr' && currentSubsection === 'performance') {
          currentTertiary = 'county_by_county';
          setTertiaryActive(currentTertiary);
          frame.src = 'cfsr/performance/county_by_county.html';
        }
      });
```

## Step 2: Modify Shiny App

Open `D:\repo_childmetrix\r_cm_reports\md\cfsr\performance\app\app.R`

### Edit 1: Disable header (around line 100-103)

**FIND:**
```r
  # Header
  dashboardHeader(
    title = "CFSR Statewide Data Indicators",
    titleWidth = 350
  ),
```

**REPLACE WITH:**
```r
  # Header - disabled to remove top bar
  dashboardHeader(disable = TRUE),
```

### Edit 2: Remove Data Dictionary menu item (around line 120)

**FIND:**
```r
      menuItem("Data Dictionary", tabName = "dictionary", icon = icon("book"))
    )
  ),
```

**REPLACE WITH:**
```r
    )
  ),
```

(Just remove the entire `menuItem("Data Dictionary"...)` line)

### Edit 3: Remove Data Dictionary tab (around lines 138-156)

**FIND AND DELETE** this entire section:
```r
      # Data Dictionary
      tabItem(
        tabName = "dictionary",
        fluidRow(
          column(12,
            h2("CFSR Indicators Dictionary"),
            p("Complete reference for all CFSR Round 4 indicators, including definitions, national standards, and calculation methods.")
          )
        ),
        fluidRow(
          column(12,
            box(
              width = 12,
              title = "Indicator Definitions and Metadata",
              DTOutput("dict_table")
            )
          )
        )
      )
```

### Edit 4: Remove Data Dictionary server code (around lines 360-400)

**FIND AND DELETE** this entire section:
```r
  # ===== DATA DICTIONARY PAGE =====

  output$dict_table <- renderDT({
    # Load dictionary
    dict_path <- "../code/cfsr_round4_indicators_dictionary.csv"
    if (file.exists(dict_path)) {
      dict <- read.csv(dict_path, stringsAsFactors = FALSE)

      # Select and rename columns for display
      dict_display <- dict %>%
        select(
          Indicator = indicator,
          `Short Name` = indicator_short,
          Category = category,
          Description = description,
          `National Standard` = national_standard,
          `Desired Direction` = direction_legend,
          Denominator = denominator,
          Numerator = numerator
        )

      datatable(
        dict_display,
        options = list(
          pageLength = 10,
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel'),
          scrollX = TRUE,
          columnDefs = list(
            list(width = '200px', targets = 0),  # Indicator
            list(width = '120px', targets = 1),  # Short Name
            list(width = '100px', targets = 2),  # Category
            list(width = '300px', targets = 3)   # Description
          )
        ),
        extensions = 'Buttons',
        rownames = FALSE,
        filter = 'top'
      )
    }
  })
```

## Step 3: Test

1. Make sure Shiny server is running:
   ```r
   shiny::runApp("D:/repo_childmetrix/r_cm_reports/md/cfsr/performance/app", port = 3838)
   ```

2. Open `file:///D:/repo_childmetrix/r_cm_reports/md/index.html#/cfsr`

3. You should see:
   - ✅ Three tertiary navigation links (State vs National, State-by-State, County-by-County)
   - ✅ "State-by-State Performance" is active by default
   - ✅ Shiny app loads WITHOUT header bar or hamburger menu
   - ✅ No "Data Dictionary" link in Shiny sidebar
   - ✅ Clicking "State Performance vs. National Standards" shows placeholder
   - ✅ Clicking "County-by-County Performance" shows placeholder
   - ✅ Clicking "State-by-State Performance" loads Shiny app

## Files Modified

- `D:\repo_childmetrix\r_cm_reports\md\index.html` - Added JavaScript handlers
- `D:\repo_childmetrix\r_cm_reports\md\cfsr\performance\app\app.R` - Removed header and Data Dictionary

## Files Created

- `D:\repo_childmetrix\r_cm_reports\md\cfsr\performance\state_vs_national.html` - Placeholder
- `D:\repo_childmetrix\r_cm_reports\md\cfsr\performance\county_by_county.html` - Placeholder

## Next Steps (Future)

- Implement actual "State Performance vs. National Standards" page (comparison charts)
- Implement actual "County-by-County Performance" page (county breakdown)
- Consider making tertiary nav selection persist across profile period changes
