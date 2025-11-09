# CFSR Tertiary Navigation - Completion Instructions

## What's Been Done

1. ✅ **HTML Structure**: Added tertiary navigation bar (lines 198-205 in index.html)
   - Three links: State Performance vs. National Standards, State-by-State Performance, County-by-County Performance
   - Hidden by default (`display: none`)

2. ✅ **JavaScript Variables**: Added references to tertiary nav elements (lines 315-318)
   - `cfsrTertiaryNav`, `tertiaryStateVsNational`, `tertiaryStateByState`, `tertiaryCountyByCounty`

3. ✅ **JavaScript Function**: Added `setTertiaryActive()` function (lines 344-352)
   - Highlights the active tertiary link

## What Still Needs To Be Done

### Step 1: Update `navigate()` function (around line 363-368)

**Find this code:**
```javascript
        // Show/hide period selector based on category and subsection
        if (currentCategory === 'cfsr' && currentSubsection === 'performance') {
          periodSelector.style.display = 'block';
        } else {
          periodSelector.style.display = 'none';
        }
```

**Replace with:**
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

### Step 2: Update `secondaryPerformance.addEventListener` (around line 380-390)

**Find this code:**
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

**Replace with:**
```javascript
      secondaryPerformance.addEventListener('click', (e) => {
        e.preventDefault();
        if (currentCategory === 'cfsr') {
          currentSubsection = 'performance';
          currentTertiary = 'state_by_state'; // Reset to default
          const period = periodSelect.value;
          // Load based on tertiary selection
          loadTertiaryContent(currentTertiary, period);
          periodSelector.style.display = 'block';
          cfsrTertiaryNav.style.display = 'flex';
          setSecondaryActive('performance');
          setTertiaryActive(currentTertiary);
        }
      });
```

### Step 3: Update other secondary menu handlers (around line 392-420)

**Find these handlers and add tertiary nav hiding:**

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

### Step 4: Add new `loadTertiaryContent()` function (add after `setTertiaryActive()` around line 353)

```javascript
      function loadTertiaryContent(tertiary, period) {
        if (tertiary === 'state_by_state') {
          frame.src = `cfsr/performance/index_auto.html?profile=${period}`;
        } else if (tertiary === 'state_vs_national') {
          frame.src = 'cfsr/performance/state_vs_national.html';
        } else if (tertiary === 'county_by_county') {
          frame.src = 'cfsr/performance/county_by_county.html';
        }
      }
```

### Step 5: Add tertiary navigation click handlers (add after period selector handler, around line 428)

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

## Next Steps

1. Make these JavaScript edits to [index.html](D:/repo_childmetrix/r_cm_reports/md/index.html)
2. Create placeholder HTML files (see PLACEHOLDER_PAGES.md)
3. Modify Shiny app to remove header and Data Dictionary (see SHINY_MODIFICATIONS.md)

## Testing

After making these changes:
1. Open file:///D:/repo_childmetrix/r_cm_reports/md/index.html
2. Click "CFSR Data Profile"
3. You should see three tertiary navigation links appear
4. "State-by-State Performance" should be active by default and show the Shiny app
5. Clicking other tertiary links should show placeholders
