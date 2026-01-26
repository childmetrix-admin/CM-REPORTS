# Feature: Isolate Missing and Unknown Bars in Race Chart

**Type**: Enhancement
**Priority**: Low
**Status**: Deferred
**Created**: 2026-01-26

## Problem

In the vertical bar chart for race/ethnicity breakdowns, the "Missing" and "Unknown" bars are currently sorted by performance along with the main race categories (Total, Black or AA, Hispanic, White, Two or More, Other). This mixing makes it harder to visually distinguish data quality/completeness categories from actual race/ethnicity categories.

**Current behavior**: All bars sorted by performance descending:
```
Total | Black or AA | White | Missing | Hispanic | Unknown | Two or More | Other
```

**Issue**: Missing and Unknown appear interspersed with actual race categories based on their performance values, reducing chart clarity.

## Desired Outcome

Move "Missing" and "Unknown" bars to the right side of the chart to visually isolate them from the main race categories.

**Proposed layout**:
```
Total | Black or AA | Hispanic | White | Two or More | Other | [gap?] | Missing | Unknown
```

**Benefits**:
- Clearer visual separation of substantive race categories from data quality indicators
- Easier to scan main race categories without DQ interruptions
- Consistent positioning of Missing/Unknown across all states (not dependent on performance values)
- Better aligns with mental model: "show me race performance, then show me data completeness"

## Current Implementation

**Location**: `domains/cfsr/modules/indicator_detail.R`
- Race data reactive: lines 870-1009
- Race chart rendering: lines 553-693

**Current sorting logic** (line 998-1003):
```r
# Sort by performance (highest first)
race_groups <- race_groups %>%
  arrange(desc(performance))

# Combine: Total first, then race groups sorted by performance
data <- bind_rows(total_calc %>% mutate(breakdown = NA_character_), race_groups)
```

**Race categories included**:
- **Total**: Aggregated sum (always first, blue bar)
- **Main races**: Black or AA, Hispanic, White, Two or More (sorted by performance, gray bars)
- **Other**: Aggregated AA/AN, Asian, NH or OPI (sorted with main races, gray bar, tooltip shows breakdown)
- **Missing**: "Missing Race/Ethnicity Data" (sorted with main races, gray bar)
- **Unknown**: "Unknown/Unable to Determine" (sorted with main races, gray bar)

**Race display recoding** (lines 980-987):
```r
race_display = case_when(
  dimension_value == "Black or African American" ~ "Black or AA",
  dimension_value == "Hispanic (of any race)" ~ "Hispanic",
  dimension_value == "White" ~ "White",
  dimension_value == "Two or More" ~ "Two or More",
  dimension_value == "Unknown/Unable to Determine" ~ "Unknown",
  dimension_value == "Missing Race/Ethnicity Data" ~ "Missing",
  TRUE ~ dimension_value
)
```

## Proposed Solution

### Option 1: Move to Right (Recommended)

**Approach**: Separate Missing/Unknown from main races, append to end

**Implementation**:
```r
# Separate Missing and Unknown from main races
dq_categories <- race_groups %>%
  filter(race_display %in% c("Missing", "Unknown"))

substantive_races <- race_groups %>%
  filter(!race_display %in% c("Missing", "Unknown"))

# Sort substantive races by performance
substantive_races <- substantive_races %>%
  arrange(desc(performance))

# Combine: Total | substantive races (sorted) | DQ categories (Missing, Unknown)
# Order DQ categories consistently: Missing first, then Unknown
dq_categories <- dq_categories %>%
  arrange(match(race_display, c("Missing", "Unknown")))

data <- bind_rows(
  total_calc %>% mutate(breakdown = NA_character_),
  substantive_races,
  dq_categories
)

# Convert race_display to factor to preserve order in plot
data <- data %>%
  mutate(race_display = factor(race_display, levels = unique(race_display)))
```

**Result**: `Total | Black or AA | White | Hispanic | Two or More | Other | Missing | Unknown`

**Pros**:
- Clean separation of substantive vs DQ categories
- Consistent positioning across states
- No visual clutter in main categories

**Cons**:
- Changes user mental model if they expect all bars sorted by performance
- May need user education ("why are these at the end?")

### Option 2: Visual Separator

**Approach**: Keep current sorting but add visual gap/divider before Missing/Unknown

**Implementation**:
- Sort all categories by performance as currently done
- Detect when Missing or Unknown appear
- Add visual spacing or divider line in chart layout
- Possibly use different color (e.g., amber #f59e0b to indicate DQ)

**Pros**:
- Maintains performance-based sorting
- Visual cue without changing order

**Cons**:
- More complex implementation (plotly layout modifications)
- Gap position varies by performance values (inconsistent across states)
- Less clear separation

### Option 3: Different Color for DQ Categories

**Approach**: Keep current sorting but color Missing/Unknown differently (e.g., amber)

**Implementation**:
```r
bar_colors <- ifelse(data$is_total, "#4472C4",  # Blue for Total
                ifelse(data$race_display %in% c("Missing", "Unknown"), "#f59e0b",  # Amber for DQ
                "#D3D3D3"))  # Gray for main races
```

**Pros**:
- Maintains sorting
- Visual distinction without position change
- Simple implementation

**Cons**:
- Doesn't isolate spatially
- May confuse users (amber = DQ warning, but not necessarily a problem)

## Recommendation

**Implement Option 1** (move to right) for clearest separation.

**Rationale**:
- Matches user request
- Provides consistent, predictable layout across all states
- Clearest visual isolation
- Low implementation complexity (~10 lines of code)

**Consider adding**:
- Footnote explaining order: "Bars sorted by performance. Missing and Unknown represent data quality/completeness."
- Consistent ordering of Missing vs Unknown (suggest: Missing first, Unknown second)

## Related Code

**Files involved**:
- `domains/cfsr/modules/indicator_detail.R` - Race data reactive and chart rendering
- `domains/cfsr/apps/app_observed/app.R` - CSS styling (if adding visual separators)

**Similar patterns**:
- Age chart always shows Total first, then ages sorted by performance
- County chart always shows state bar sorted with counties by performance
- No current precedent for "move categories to end" pattern

## Notes

- This is a visual organization enhancement, not a functional issue
- Current implementation is correct and functional
- May revisit based on user feedback after seeing prototype
- Consider applying same pattern to other demographics if implemented (e.g., age chart with "Unknown age" if it exists)

## Next Steps

1. Confirm desired behavior with user (Option 1, 2, or 3?)
2. Confirm desired ordering of Missing vs Unknown (which comes first on right?)
3. Determine if footnote explanation needed
4. Implement chosen option
5. Test with MD and KY data
6. Verify bar colors remain appropriate (Total = blue, main races = gray, DQ = gray or amber?)

---

**Related Issues**: None
**Labels**: enhancement, ui-polish, plotly, race-chart, deferred
