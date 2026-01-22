# Coding Style

## R Style Guidelines (CRITICAL)

ALWAYS follow tidyverse style guide:

```r
# WRONG: camelCase, = assignment, inconsistent spacing
myFunction=function(userName,userAge){
result<-userName
return(result)
}

# CORRECT: snake_case, <- assignment, proper spacing
my_function <- function(user_name, user_age) {
  result <- user_name
  return(result)
}
```

## Naming Conventions

- **Functions**: `snake_case` (e.g., `load_cfsr_data`, `render_quarterly_memos`)
- **Variables**: `snake_case` (e.g., `user_name`, `data_frame`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `MAX_ITERATIONS`, `DEFAULT_PORT`)
- **Assignment**: Prefer `<-` over `=` for assignment
- **Spacing**: Space around operators, after commas

## File Organization

MANY SMALL FILES > FEW LARGE FILES:
- High cohesion, low coupling
- 200-400 lines typical, 800 max
- Extract utilities to `functions/` directory
- Organize by feature/domain: `shared/cfsr/`, `shared/cps/`, etc.

## Shiny App Structure

MODULARIZE Shiny UI/server logic:

```r
# WRONG: Everything in one file
ui <- fluidPage(
  # 500 lines of UI code...
)

server <- function(input, output, session) {
  # 800 lines of server code...
}

# CORRECT: Use modules
ui <- fluidPage(
  filterModuleUI("filters"),
  chartModuleUI("chart")
)

server <- function(input, output, session) {
  filtered_data <- filterModuleServer("filters", data)
  chartModuleServer("chart", filtered_data)
}
```

## Tidyverse Patterns

USE tidyverse verbs over base R when appropriate:

```r
# WRONG: Base R (harder to read)
subset(data, age > 18 & status == "active")

# CORRECT: Tidyverse (clearer intent)
data %>%
  filter(age > 18, status == "active")
```

## Error Handling

ALWAYS handle errors comprehensively:

```r
# Use tryCatch for error handling
result <- tryCatch(
  {
    risky_operation()
  },
  error = function(e) {
    message("Operation failed: ", e$message)
    return(NULL)
  }
)

# In Shiny: Use req() and validate()
output$plot <- renderPlot({
  req(input$file)  # Require input before proceeding

  validate(
    need(nrow(data()) > 0, "No data available")
  )

  create_plot(data())
})
```

## Code Formatting

- **Indentation**: 2 spaces (not tabs)
- **Line length**: Max 80 characters
- **Braces**: `{` on same line, `}` on new line
- **Pipes**: Each pipe (`%>%`) on new line when chaining multiple operations

```r
# CORRECT formatting
result <- data %>%
  filter(status == "active") %>%
  select(id, name, value) %>%
  arrange(desc(value))
```

## Code Quality Checklist

Before marking work complete:
- [ ] Code uses `snake_case` naming consistently
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling with `tryCatch`, `req()`, `validate()`
- [ ] No `print()` or `cat()` debugging statements
- [ ] No hardcoded values (use parameters or config)
- [ ] Tidyverse verbs used appropriately
- [ ] Shiny modules used for reusable components
