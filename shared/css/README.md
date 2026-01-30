# ChildMetrix Design System

Centralized CSS design system for consistent styling across all CFSR Shiny apps and R Markdown reports.

## Files

- **design-tokens.css** - CSS variables for colors, typography, spacing, etc.
- **components.css** - Reusable component classes (pills, KPI cards, headers, etc.)

## Usage in Shiny Apps

Import these files at the top of your `ui` definition:

```r
ui <- dashboardPage(
  dashboardHeader(...),
  dashboardSidebar(...),
  dashboardBody(
    tags$head(
      # Import design system (order matters!)
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "../../../../shared/css/design-tokens.css"
      ),
      tags$link(
        rel = "stylesheet",
        type = "text/css",
        href = "../../../../shared/css/components.css"
      )
    ),
    ...
  )
)
```

## Component Examples

### Page Container

Replaces: `.indicator-page-container`, `.viz-export-container`

```r
div(
  class = "cm-page-container",
  # Your content here
)
```

### Page Title

Replaces: Inline styles with `font-size: 16px; font-weight: 700; color: #4472C4;`

```r
h2(class = "cm-page-title", "CFSR Performance Trends")
```

### Section Title and Description

Replaces: `.viz-title`, `.viz-description`

```r
div(
  class = "cm-section-title",
  "Risk-Standardized Performance — CFSR Statewide Data Indicators"
),
div(
  class = "cm-section-description",
  "RSP is the state's observed performance, with risk-adjustment"
)
```

### Context Header with Divider

Replaces: `.viz-context-header` with inline `padding-bottom` and `margin-bottom`

```r
div(
  class = "cm-context-header",
  div(class = "cm-section-title", "Risk-Standardized Performance"),
  div(class = "cm-section-description", "Description text"),
  div(class = "cm-pills-row",
    div(class = "cm-pill cm-pill--period", "Oct '21 - Sep '22"),
    div(class = "cm-pill cm-pill--state", "Maryland")
  )
)
```

### Pills

Replaces: `.viz-period-pill`, `.viz-state-pill`, `.viz-legend-pill`

```r
# Period pill (blue)
div(class = "cm-pill cm-pill--period", "Oct '21 - Sep '22")

# State pill (orange)
div(class = "cm-pill cm-pill--state", "Maryland")

# Legend pill (transparent with icon)
div(
  class = "cm-pill cm-pill--legend",
  span(class = "cm-legend-line"),
  "National Performance"
)

# Status pills
div(class = "cm-pill cm-pill--status cm-pill--better", "Better")
div(class = "cm-pill cm-pill--status cm-pill--worse", "Worse")
div(class = "cm-pill cm-pill--status cm-pill--nodiff", "No Difference")
div(class = "cm-pill cm-pill--status cm-pill--dq", "DQ")
```

### Pills Row

Replaces: Inline `display: flex; gap: 8px;`

```r
div(
  class = "cm-pills-row",
  div(class = "cm-pill cm-pill--period", "Oct '21 - Sep '22"),
  div(class = "cm-pill cm-pill--state", "Maryland")
)
```

### KPI Card

Replaces: `.kpi-box` with inline styles

```r
div(
  class = "cm-kpi-card",

  # Status dot (top-right)
  div(class = "cm-status-dot cm-status-dot--better"),

  # Title
  div(class = "cm-kpi-title", "Entry rate"),

  # Subtitle
  div(class = "cm-kpi-subtitle", "per 1,000 child-days"),

  # Value
  div(
    div(
      class = "cm-kpi-value",
      "5.2 ",
      span(class = "cm-kpi-unit", "per 1,000")
    )
  ),

  # Interpretation (optional)
  div(
    class = "cm-kpi-interpretation",
    # Interpretation content
  )
)
```

### KPI Grid

Replaces: Inline `display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 350px));`

```r
div(
  class = "cm-kpi-grid",
  # KPI cards go here
  div(class = "cm-kpi-card", ...),
  div(class = "cm-kpi-card", ...),
  div(class = "cm-kpi-card", ...)
)
```

### Source Footnote

Replaces: `.viz-source` with inline styles

```r
div(
  class = "cm-source",
  HTML("Source: AFCARS, NCANDS")
)
```

### Chart Footnote

Replaces: `.chart-footnote` with inline styles

```r
div(
  class = "cm-footnote",
  "Note: Data represents fiscal year 2023."
)
```

### Download Button

Replaces: Inline `position: absolute; top: 16px; right: 16px;`

```r
div(
  class = "cm-download-btn",
  actionButton(
    ns("download_btn"),
    "Download",
    icon = icon("download")
  )
)
```

### Tab Content Spacing

Replaces: Inline `margin-top: 20px;` or `margin-top: 22px;`

```r
div(
  class = "cm-tab-content",
  # Tab content goes here
)
```

## Design Tokens Reference

### Colors

#### Brand Colors
```css
--cm-primary: #4472C4           /* ChildMetrix primary blue */
--cm-primary-light: #52C8FA     /* Light blue accent */
```

#### Status Colors
```css
--cm-status-better: #4472C4     /* Better than target */
--cm-status-worse: #ef4444      /* Worse than target */
--cm-status-nodiff: #6b7280     /* No difference */
--cm-status-dq: #f59e0b         /* Data quality issue */
--cm-status-national: #10b981   /* National standard line */
```

#### Text Colors
```css
--cm-text-primary: #1f2937      /* Main text */
--cm-text-dark: #111827         /* Headings */
--cm-text-muted: #6b7280        /* Secondary text */
--cm-text-light: #374151        /* Table content */
--cm-text-label: #666666        /* Chart labels */
```

#### Background Colors
```css
--cm-bg-page: #f9fafb           /* Page background */
--cm-bg-card: #ffffff           /* Cards */
--cm-bg-nav: #2c3e50            /* Sidebar */
--cm-bg-subtle: #f8f9fa         /* Subtle backgrounds */
```

### Typography

#### Font Sizes
```css
--cm-text-xs: 11px              /* Footnotes */
--cm-text-sm: 12px              /* Pills */
--cm-text-base: 13px            /* Descriptions */
--cm-text-md: 14px              /* Secondary content */
--cm-text-lg: 15px              /* Section titles */
--cm-text-xl: 16px              /* Page titles */
--cm-text-2xl: 18px             /* Large headers */
--cm-text-3xl: 20px             /* Chart titles */
```

#### Font Weights
```css
--cm-font-normal: 400
--cm-font-medium: 500
--cm-font-semibold: 600
--cm-font-bold: 700
```

### Spacing

```css
--cm-space-1: 4px
--cm-space-2: 8px
--cm-space-3: 12px
--cm-space-4: 16px
--cm-space-5: 20px
--cm-space-6: 24px
--cm-space-8: 32px
--cm-space-10: 40px
```

### Border Radius

```css
--cm-radius-sm: 6px             /* Small cards */
--cm-radius-md: 8px             /* Summary cards */
--cm-radius-lg: 10px            /* KPI cards */
--cm-radius-pill: 12px          /* Pills */
--cm-radius-full: 50%           /* Status dots */
```

## Migration Guide

### Before (Inline Styles)

```r
div(
  style = "background: white; border: 1px solid #e5e7eb; border-radius: 6px; padding: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.08);",
  h2(style = "font-size: 16px; font-weight: 700; color: #4472C4; margin: 0; letter-spacing: -0.5px;",
     "CFSR Performance Trends"),
  div(style = "display: flex; gap: 8px; margin-top: 12px;",
    div(style = "background: #4472C4; color: white; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600;",
        "Oct '21 - Sep '22"),
    div(style = "background: #f59e0b; color: white; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600;",
        "Maryland")
  )
)
```

### After (Component Classes)

```r
div(
  class = "cm-page-container",
  h2(class = "cm-page-title", "CFSR Performance Trends"),
  div(class = "cm-pills-row",
    div(class = "cm-pill cm-pill--period", "Oct '21 - Sep '22"),
    div(class = "cm-pill cm-pill--state", "Maryland")
  )
)
```

**Result**: 90% less code, easier to maintain, automatically consistent.

## Utility Classes

### Spacing

```r
# Margin top
div(class = "cm-mt-1", ...)  # 4px
div(class = "cm-mt-2", ...)  # 8px
div(class = "cm-mt-3", ...)  # 12px
div(class = "cm-mt-4", ...)  # 16px
div(class = "cm-mt-5", ...)  # 20px
div(class = "cm-mt-6", ...)  # 24px

# Margin bottom
div(class = "cm-mb-1", ...)  # 4px
# ... same pattern
```

### Text Alignment

```r
div(class = "cm-text-center", ...)
div(class = "cm-text-right", ...)
```

### Visibility

```r
div(class = "cm-hidden", ...)  # display: none
```

## Chart Builder Integration

When building charts with plotly, use design tokens for consistency:

```r
plot_ly(...) %>%
  layout(
    plot_bgcolor = "white",
    paper_bgcolor = "white",
    font = list(
      family = "Arial, sans-serif",
      size = 11,
      color = "#666666"
    ),
    xaxis = list(
      gridcolor = "#E5E5E5",
      tickfont = list(size = 11)
    )
  )
```

These values match the design tokens:
- `#666666` = `--cm-text-label`
- `#E5E5E5` = `--cm-grid`
- `11px` = `--cm-text-xs`

## Best Practices

1. **Always import design-tokens.css first**, then components.css
2. **Use component classes** instead of inline styles whenever possible
3. **Only use inline styles** for truly unique, one-off styling
4. **Combine classes** for common patterns (e.g., `cm-pill cm-pill--period`)
5. **Use utility classes** for quick spacing adjustments instead of custom margins

## Updating the Design System

When you need to add new patterns:

1. **Add tokens first** - Update `design-tokens.css` with new variables
2. **Create component** - Add new class to `components.css`
3. **Document usage** - Update this README with examples
4. **Refactor existing code** - Replace inline styles with new class

## Questions?

See examples in:
- `domains/cfsr/apps/app_measures/app.R` (after refactoring)
- `domains/cfsr/apps/app_summary/app.R` (after refactoring)
- `domains/cfsr/modules/indicator_detail.R` (after refactoring)
