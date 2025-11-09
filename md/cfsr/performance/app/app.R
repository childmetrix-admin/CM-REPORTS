# app.R - Main Shiny application file
# CFSR Statewide Data Indicators Dashboard

# Load required libraries (in case global.R doesn't load first)
library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(ggplot2)

# Source helper functions and load data
source("functions/utils.R")
source("functions/data_prep.R")
source("functions/chart_builder.R")
source("modules/indicator_page.R")

#####################################
# DATA LOADING FUNCTION ----
#####################################

# Function to load data based on state and profile period
load_cfsr_data <- function(state_code = "MD", profile_period = "latest") {
  # Base directory for production data
  data_dir <- "D:/repo_childmetrix/cm-reports/md/cfsr/performance/app/data"

  # Try different file naming patterns
  possible_paths <- c(
    # State-specific period file (preferred)
    file.path(data_dir, paste0(state_code, "_cfsr_indicators_", profile_period, ".rds")),
    # State-specific latest
    file.path(data_dir, paste0(state_code, "_cfsr_indicators_latest.rds")),
    # Generic latest (fallback for backward compatibility)
    file.path(data_dir, "cfsr_indicators_latest.rds"),
    # Legacy location
    "D:/repo_childmetrix/cfsr-profile/shiny_app/data/cfsr_indicators_latest.rds"
  )

  # Try each path
  for (path in possible_paths) {
    if (file.exists(path)) {
      message("Loading CFSR data from: ", path)
      return(readRDS(path))
    }
  }

  # If nothing found, throw helpful error
  stop("No CFSR data found for state=", state_code, " and profile=", profile_period,
       "\n\nTried paths:\n", paste(possible_paths, collapse = "\n"),
       "\n\nPlease run cfsr-profile.R and prepare_app_data.R first.")
}

# Load initial data (will be replaced when user-specific parameters are available in server)
# For now, use defaults that work for UI construction
app_data <- load_cfsr_data("MD", "latest")

# State code mapping
state_codes <- c(
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

# Create mapping from indicator names to tab names
indicator_to_tab <- c(
  "Foster care entry rate (entries / 1,000 children)" = "entry_rate",
  "Maltreatment in care (victimizations / 100,000 days in care)" = "maltreatment",
  "Permanency in 12 months for children entering care" = "perm12_entries",
  "Permanency in 12 months for children in care 12-23 months" = "perm12_12_23",
  "Permanency in 12 months for children in care 24 months or more" = "perm12_24",
  "Placement stability (moves / 1,000 days in care)" = "placement",
  "Reentry to foster care within 12 months" = "reentry",
  "Maltreatment recurrence within 12 months" = "recurrence"
)

# Get ordered indicator list for sidebar
sidebar_indicators <- app_data %>%
  distinct(indicator, indicator_very_short, indicator_sort) %>%
  arrange(indicator_sort)

#####################################
# UI ----
#####################################

ui <- dashboardPage(
  skin = "blue",

  # Header - disabled to remove top bar
  dashboardHeader(disable = TRUE),

  # Sidebar
  dashboardSidebar(
    width = 200,
    sidebarMenu(
      id = "sidebar_menu",

      menuItem("Overview", tabName = "overview", icon = icon("chart-bar")),

      # Dynamically generate indicator menu items
      lapply(1:nrow(sidebar_indicators), function(i) {
        ind <- sidebar_indicators[i, ]
        tab_name <- indicator_to_tab[[ind$indicator]]
        menuItem(ind$indicator_very_short, tabName = tab_name)
      })
    )
  ),

  # Body
  dashboardBody(
    # Custom CSS
    tags$head(
      tags$style(HTML("
        .content-wrapper { background-color: #f4f4f4; }
        .box { box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .chart-title { font-size: 20px; font-weight: bold; margin-bottom: 5px; }
        .chart-period { font-size: 16px; font-style: italic; color: #666; margin-bottom: 10px; }
        .chart-description { font-size: 13px; color: #333; margin-bottom: 10px; line-height: 1.5; }
        .chart-target { font-size: 13px; color: #666; margin-bottom: 10px; }
        .chart-footnote { font-size: 11px; color: #666; margin-top: 5px; }
        .state-badge { background-color: #4472C4; color: white; padding: 5px 10px;
                       border-radius: 4px; font-weight: bold; }
        .profile-badge { background-color: #f0f0f0; padding: 5px 10px;
                         border-radius: 4px; font-size: 13px; }
        /* Reduce spacing between sidebar menu items */
        .sidebar-menu li { margin-bottom: 2px; }
        .sidebar-menu li a { padding-top: 8px; padding-bottom: 8px; }
        /* Reduce top whitespace/padding */
        .content-wrapper, .right-side { padding-top: 0 !important; }
        .main-sidebar { padding-top: 0 !important; margin-top: 0 !important; }
        .sidebar { padding-top: 5px !important; }
        body, html { margin-top: 0 !important; padding-top: 0 !important; }
      "))
    ),

    tabItems(
      # Overview tab
      tabItem(
        tabName = "overview",

        # State performance summary
        fluidRow(
          column(12,
            h2(textOutput("state_performance_title", inline = TRUE)),
            p("Most recent period available. Lower rank is better.")
          )
        ),
        fluidRow(
          column(12,
            box(
              width = 12,
              DT::dataTableOutput("state_performance_table"),
              p(style = "font-size: 11px; color: #666; margin-top: 10px;",
                "DQ = Not calculated due to data quality issues. Reporting States = The number of states whose performance could be calculated.")
            )
          )
        ),

        # All states rankings table (collapsible)
        fluidRow(
          column(12,
            box(
              width = 12,
              title = "View Rankings for All States",
              collapsible = TRUE,
              collapsed = TRUE,
              status = "primary",
              solidHeader = TRUE,
              DT::dataTableOutput("overview_rankings_table")
            )
          )
        )
      ),

      # Entry Rate
      tabItem(
        tabName = "entry_rate",
        indicator_page_ui("entry_rate")
      ),

      # Maltreatment in Care
      tabItem(
        tabName = "maltreatment",
        indicator_page_ui("maltreatment")
      ),

      # Perm 12 (entries)
      tabItem(
        tabName = "perm12_entries",
        indicator_page_ui("perm12_entries")
      ),

      # Perm 12 (12-23 months)
      tabItem(
        tabName = "perm12_12_23",
        indicator_page_ui("perm12_12_23")
      ),

      # Perm 12 (24+ months)
      tabItem(
        tabName = "perm12_24",
        indicator_page_ui("perm12_24")
      ),

      # Placement Stability
      tabItem(
        tabName = "placement",
        indicator_page_ui("placement")
      ),

      # Reentry
      tabItem(
        tabName = "reentry",
        indicator_page_ui("reentry")
      ),

      # Recurrence
      tabItem(
        tabName = "recurrence",
        indicator_page_ui("recurrence")
      )

    )
  )
)

#####################################
# SERVER ----
#####################################

server <- function(input, output, session) {

  # Detect profile period from URL
  selected_profile <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    profile <- query$profile
    if (is.null(profile) || profile == "") {
      profile <- "latest"
    }
    profile
  })

  # Detect state from URL
  selected_state <- reactive({
    get_state_from_url(session, state_codes)
  })

  # Reactive data loading based on URL parameters
  current_data <- reactive({
    state_code <- names(state_codes)[state_codes == selected_state()]
    if (length(state_code) == 0) {
      state_code <- "MD"  # Default fallback
    }
    profile_period <- selected_profile()

    # Load the appropriate data file
    load_cfsr_data(state_code, profile_period)
  })

  # Get profile version from current data
  profile_ver <- reactive({
    data <- current_data()
    if (!is.null(data$profile_version[1])) {
      data$profile_version[1]
    } else {
      NULL
    }
  })

  # Get all indicators in order from current data
  all_indicators <- reactive({
    get_all_indicators(current_data())
  })

  # ===== OVERVIEW PAGE =====

  # State performance title
  output$state_performance_title <- renderText({
    state <- selected_state()
    if (!is.null(state)) {
      paste0(state, "'s Performance on CFSR Statewide Data Indicators")
    } else {
      "State Performance on CFSR Statewide Data Indicators"
    }
  })

  # Render state performance summary table
  output$state_performance_table <- DT::renderDataTable({
    table_data <- build_state_performance_table(current_data(), selected_state())

    if (is.null(table_data)) {
      return(NULL)
    }

    DT::datatable(
      table_data,
      options = list(
        dom = 't',  # Only show table (no search, pagination, etc.)
        ordering = FALSE,  # Disable sorting
        columnDefs = list(
          list(className = 'dt-center', targets = 1:4)  # Center align Rank, Reporting States, Performance, National Standard
        ),
        initComplete = JS(
          "function(settings, json) {",
          "  $(this.api().table().container()).css({'font-size': '12px'});",
          "  $(this.api().table().header()).css({'font-size': '12px', 'padding': '4px'});",
          "  $(this.api().table().body()).find('td').css({'padding': '4px 8px'});",
          "}"
        )
      ),
      rownames = FALSE,
      selection = 'none',
      class = 'cell-border stripe compact hover'
    )
  })

  # Render overview rankings table
  output$overview_rankings_table <- DT::renderDataTable({
    table_data <- build_overview_rankings_table(current_data(), selected_state())

    DT::datatable(
      table_data,
      options = list(
        pageLength = 52,  # Show all states
        dom = 't',  # Only show table (no search, pagination, etc.)
        scrollY = "600px",
        scrollCollapse = TRUE,
        ordering = TRUE,
        order = list(list(0, 'asc')),  # Sort by State column
        columnDefs = list(
          list(className = 'dt-center', targets = 1:(ncol(table_data) - 1))  # Center align rank columns
        ),
        initComplete = JS(
          "function(settings, json) {",
          "  $(this.api().table().container()).css({'font-size': '12px'});",
          "  $(this.api().table().header()).css({'font-size': '12px', 'padding': '4px'});",
          "  $(this.api().table().body()).find('td').css({'padding': '4px 8px'});",
          "}"
        )
      ),
      rownames = FALSE,
      selection = 'none',
      class = 'cell-border stripe compact hover'
    ) %>%
      DT::formatStyle(
        'State',
        target = 'row',
        backgroundColor = DT::styleEqual(selected_state(), '#E8F4FD')  # Highlight selected state row
      )
  })

  # ===== INDICATOR PAGES =====

  # Entry Rate
  indicator_page_server(
    "entry_rate",
    indicator_name = "Foster care entry rate (entries / 1,000 children)",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

  # Maltreatment in Care
  indicator_page_server(
    "maltreatment",
    indicator_name = "Maltreatment in care (victimizations / 100,000 days in care)",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

  # Perm 12 (entries)
  indicator_page_server(
    "perm12_entries",
    indicator_name = "Permanency in 12 months for children entering care",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

  # Perm 12 (12-23 months)
  indicator_page_server(
    "perm12_12_23",
    indicator_name = "Permanency in 12 months for children in care 12-23 months",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

  # Perm 12 (24+ months)
  indicator_page_server(
    "perm12_24",
    indicator_name = "Permanency in 12 months for children in care 24 months or more",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

  # Placement Stability
  indicator_page_server(
    "placement",
    indicator_name = "Placement stability (moves / 1,000 days in care)",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

  # Reentry
  indicator_page_server(
    "reentry",
    indicator_name = "Reentry to foster care within 12 months",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

  # Recurrence
  indicator_page_server(
    "recurrence",
    indicator_name = "Maltreatment recurrence within 12 months",
    app_data = current_data,  # Pass reactive
    selected_state = selected_state,
    profile_version = profile_ver
  )

}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
