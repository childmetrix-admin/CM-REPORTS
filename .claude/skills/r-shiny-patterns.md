# R Shiny Architecture Patterns

## App Structure

- Separate `global.R` (data loading), `ui.R`/`server.R` or single `app.R`
- Use Shiny modules (`moduleUI`/`moduleServer`) for reusable components
- Keep reactive logic in server, UI definition in ui
- Minimize reactivity - use `eventReactive`, `observeEvent` over `reactive`/`observe`

## Data Loading

- Load static data in global.R (shared across sessions)
- Use reactive data sources in server (user-specific filtering)
- Cache expensive computations with `bindCache()`
- Prefer RDS files over CSV for R data structures

## Shared Functions

- Extract chart/viz logic to standalone functions in `shared/*/functions/`
- Use function factories for parameterized plot builders
- Document function parameters with roxygen2 comments

## Multi-App Architecture

- Run apps on different ports (3838, 3839, 3840, 3841)
- Use iframe embedding for integration into static sites
- Pass state via URL parameters (`?state=MD&profile=2025_02`)
- Share utility functions across apps via sourced R files

## Performance

- Use `req()` to prevent cascading errors
- Debounce user inputs with `debounce()`
- Minimize re-rendering with `isolate()`
- Profile with `profvis` to identify bottlenecks

## DRY Principles

- Consolidate duplicate chart code into `chart_builder.R`
- Create reusable modules for common UI patterns (filters, tables)
- Share data prep logic in `data_prep.R`
- Use theme functions for consistent styling

## Reactive Programming Best Practices

```r
# WRONG: Too reactive, re-renders unnecessarily
output$plot <- renderPlot({
  data()  # Re-renders whenever data() changes
  input$color  # AND whenever color changes
  create_plot(data(), input$color)
})

# CORRECT: Use eventReactive for explicit triggers
plot_data <- eventReactive(input$update_button, {
  create_plot(data(), input$color)
})

output$plot <- renderPlot({
  plot_data()
})
```

## Module Pattern

```r
# UI Module
filterModuleUI <- function(id) {
  ns <- NS(id)
  tagList(
    selectInput(ns("state"), "State", choices = c("MD", "KY")),
    selectInput(ns("period"), "Period", choices = NULL)
  )
}

# Server Module
filterModuleServer <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    # Update period choices based on state
    observe({
      periods <- unique(data()$period[data()$state == input$state])
      updateSelectInput(session, "period", choices = periods)
    })

    # Return reactive filtered data
    reactive({
      req(input$state, input$period)
      data() %>% filter(state == input$state, period == input$period)
    })
  })
}
```

## Error Handling in Shiny

```r
# Use req() to require inputs
output$table <- renderTable({
  req(input$file)  # Don't render until file is uploaded
  read.csv(input$file$datapath)
})

# Use validate() for custom validation messages
output$plot <- renderPlot({
  validate(
    need(nrow(data()) > 0, "No data available to plot"),
    need(!anyNA(data()$value), "Data contains missing values")
  )
  create_plot(data())
})

# Use tryCatch for external operations
data <- reactive({
  tryCatch(
    readRDS(file_path()),
    error = function(e) {
      showNotification(paste("Error loading data:", e$message), type = "error")
      return(NULL)
    }
  )
})
```
