# Feature: Improve Vertical Chart Data Label Spacing

**Type**: Enhancement
**Priority**: Low
**Status**: Deferred
**Created**: 2026-01-26

## Problem

In the vertical bar charts (By Age and By Race), data labels appear too close to the top of the bars. Users would prefer the labels to have more breathing room above the bars for better readability.

**Example**: See screenshot from user showing Entry Rate by Race chart where labels sit directly on bar tops.

## Current Implementation

**Location**: `domains/cfsr/modules/indicator_detail.R`
- Age chart: lines 401-501
- Race chart: lines 503-618

**Current approach**:
```r
plot_ly(
  ...
  text = data_labels,
  textposition = "outside",
  textfont = list(size = 13, color = "#666666", family = "Arial"),
  ...
)
```

Uses plotly's built-in `textposition = "outside"` which automatically positions labels just above bars, but provides no control over the exact offset distance.

## Attempted Solutions

### Attempt 1: Adjust y-axis range
- **Method**: Increased `y_axis_max` padding from 1.20 to 1.25 to 1.35
- **Result**: No effect - affects scale but not label position
- **Why it failed**: Y-axis range controls chart bounds, not label offset from bars

### Attempt 2: Adjust top margin
- **Method**: Increased top margin from `t = 10` to `t = 40`
- **Result**: Added space between title and chart, but labels still close to bars
- **Why it failed**: Margin affects whitespace around plot area, not label positioning within plot

### Attempt 3: Leading line breaks in labels
- **Method**: Added `\n` at start of data labels to create invisible padding
- **Result**: No effect - plotly appears to trim leading whitespace
- **Why it failed**: Text rendering engines typically normalize whitespace

### Attempt 4: Increase chart height
- **Method**: Increased height from 500 to 550 pixels
- **Result**: More vertical space overall, but labels still tight to bars
- **Why it failed**: Height affects overall canvas, not relative label positioning

### Attempt 5: Manual annotations (reverted)
- **Method**: Replaced built-in text labels with plotly annotations, manually positioning each label at `y = performance + label_offset`
- **Result**: Labels moved up with custom offset (5% of max value)
- **Why it was reverted**: Felt like a hack; user preferred to defer this issue
- **Code example**:
```r
annotations_list <- lapply(1:nrow(data), function(i) {
  list(
    x = data$dimension_value[i],
    y = performance[i] + label_offset,  # Custom offset
    text = data_labels[i],
    showarrow = FALSE,
    font = list(size = 13, color = "#666666", family = "Arial"),
    xanchor = "center",
    yanchor = "bottom"
  )
})
```

## Potential Solutions (Not Yet Tried)

### Option 1: Plotly textfont.standoff
- **Research needed**: Check if plotly R supports `standoff` parameter (available in plotly.js)
- **Approach**: `textfont = list(size = 13, standoff = 10, ...)`
- **Likelihood**: Low - may not be exposed in R plotly

### Option 2: CSS transforms
- **Approach**: Apply CSS `transform: translateY(-10px)` to rendered text elements
- **Pros**: Clean, non-invasive
- **Cons**: Requires targeting specific SVG/HTML elements after render, fragile

### Option 3: Custom plotly layout settings
- **Research needed**: Explore undocumented plotly layout parameters
- **Approach**: Deep dive into plotly.js documentation for text positioning options

### Option 4: Accept annotation approach
- **Pros**: Works, gives precise control
- **Cons**: More code, feels like a workaround
- **Consideration**: If no cleaner solution exists, this may be acceptable

## Related Code

**Files involved**:
- `domains/cfsr/modules/indicator_detail.R` - Chart rendering logic
- `domains/cfsr/apps/app_observed/app.R` - CSS styling

**Similar patterns**:
- Horizontal bar charts use similar approach but don't have this issue (labels to the right of bars have natural spacing)

## Notes

- User feedback: "That seems like a hack" (regarding annotation approach)
- This is a visual polish issue, not a functional bug
- Current implementation is acceptable, just not optimal
- May revisit if plotly library updates or cleaner solution found

## Next Steps

1. Research plotly R documentation for text positioning parameters
2. Check plotly GitHub issues for similar requests
3. Consider posting to plotly community forums
4. If no native solution, re-evaluate annotation approach vs. accepting current state

---

**Related Issues**: None
**Labels**: enhancement, ui-polish, plotly, deferred
