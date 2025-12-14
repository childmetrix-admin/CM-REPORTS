# app.R - Observed Performance Dashboard
# Displays CFSR observed performance with tabs for different aggregations

# Load required libraries (in case global.R doesn't load first)
library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(ggplot2)

# Define indicator and state code data (since we're not loading external data yet)
indicators <- data.frame(
  indicator_num = 1:8,
  indicator_name = c(
    "Entry Rate",
    "Maltreatment in Care",
    "Recurrence of Maltreatment",
    "Permanency in 12mo - Entries",
    "Permanency in 12mo - 12-23mo",
    "Permanency in 12mo - 24+mo",
    "Reentry to Foster Care",
    "Placement Stability"
  ),
  indicator_short = c(
    "Entry Rate",
    "Maltreatment",
    "Recurrence",
    "Perm 12mo - Entries",
    "Perm 12mo - 12-23mo",
    "Perm 12mo - 24+mo",
    "Reentry",
    "Placement"
  ),
  category = c(
    "Other",
    "Safety",
    "Safety",
    "Permanency",
    "Permanency",
    "Permanency",
    "Permanency",
    "Well-Being"
  ),
  stringsAsFactors = FALSE
)

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

# Define %||% operator if not available
`%||%` <- function(a, b) if (is.null(a)) b else a

#####################################
# UI ----
#####################################

ui <- dashboardPage(

  # Header
  dashboardHeader(
    title = "CFSR Observed Performance",
    titleWidth = 280
  ),

  # Sidebar with indicator navigation
  dashboardSidebar(
    width = 280,
    sidebarMenu(
      id = "indicator_menu",

      menuItem(
        "Overview",
        tabName = "overview",
        icon = icon("th")
      ),

      menuItem(
        "Entry Rate",
        tabName = "ind_1",
        icon = icon("door-open")
      ),

      menuItem(
        "Maltreatment in Care",
        tabName = "ind_2",
        icon = icon("shield-alt")
      ),

      menuItem(
        "Recurrence",
        tabName = "ind_3",
        icon = icon("rotate-right")
      ),

      menuItem(
        "Perm 12mo - Entries",
        tabName = "ind_4",
        icon = icon("home")
      ),

      menuItem(
        "Perm 12mo - 12-23mo",
        tabName = "ind_5",
        icon = icon("home")
      ),

      menuItem(
        "Perm 12mo - 24+mo",
        tabName = "ind_6",
        icon = icon("home")
      ),

      menuItem(
        "Reentry",
        tabName = "ind_7",
        icon = icon("arrow-right-to-bracket")
      ),

      menuItem(
        "Placement Stability",
        tabName = "ind_8",
        icon = icon("chart-line")
      )
    )
  ),

  # Main content
  dashboardBody(

    # Custom CSS for tabs
    tags$head(
      tags$style(HTML("
        .tab-navigation {
          background: white;
          padding: 1rem;
          border-bottom: 2px solid #e5e7eb;
          margin-bottom: 1.5rem;
        }
        .tab-btn {
          padding: 0.75rem 1.5rem;
          margin-right: 0.5rem;
          background: #f3f4f6;
          border: 1px solid #d1d5db;
          border-radius: 0.5rem 0.5rem 0 0;
          color: #374151;
          font-size: 0.875rem;
          font-weight: 500;
          cursor: pointer;
          transition: all 0.2s;
        }
        .tab-btn:hover {
          background: #e5e7eb;
        }
        .tab-btn.active {
          background: #ffffff;
          border-bottom-color: #ffffff;
          color: #0f4c75;
          font-weight: 600;
        }
        .coming-soon-box {
          padding: 1.5rem;
          background: #dbeafe;
          border: 1px solid #93c5fd;
          border-radius: 0.5rem;
          margin: 1rem;
        }
        .coming-soon-title {
          font-size: 1.125rem;
          font-weight: 600;
          color: #1e40af;
          margin-bottom: 0.5rem;
        }
        .coming-soon-text {
          font-size: 0.875rem;
          color: #1e3a8a;
        }
      "))
    ),

    # Dynamic UI output
    uiOutput("page_content")
  )
)

#####################################
# SERVER ----
#####################################

server <- function(input, output, session) {

  # Reactive: Get state from URL parameter
  selected_state <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    state_code <- query$state %||% "MD"
    state_code
  })

  # Reactive: Get profile from URL parameter
  selected_profile <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$profile %||% "latest"
  })

  # Reactive: Get indicator from URL parameter
  url_indicator <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$indicator %||% "overview"
  })

  # Reactive: Get tab from URL parameter
  url_tab <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    query$tab %||% "state_us"
  })

  # Reactive: Active tab (for horizontal tab navigation)
  active_tab <- reactiveVal("state_us")

  # Update active tab based on URL parameter
  observe({
    active_tab(url_tab())
  })

  # Update sidebar menu based on URL indicator parameter
  observe({
    ind <- url_indicator()
    if (ind == "overview") {
      updateTabItems(session, "indicator_menu", "overview")
    } else if (grepl("^\\d+$", ind)) {
      updateTabItems(session, "indicator_menu", paste0("ind_", ind))
    }
  })

  # Reactive: Current indicator info
  current_indicator_info <- reactive({
    current_tab <- input$indicator_menu

    if (current_tab == "overview") {
      return(list(
        num = 0,
        name = "Overview",
        short = "Overview"
      ))
    }

    ind_num <- as.integer(sub("ind_", "", current_tab))
    ind_data <- indicators[indicators$indicator_num == ind_num, ]

    list(
      num = ind_num,
      name = ind_data$indicator_name,
      short = ind_data$indicator_short
    )
  })

  # Render page content
  output$page_content <- renderUI({
    current_tab <- input$indicator_menu
    state_name <- state_codes[selected_state()]

    if (current_tab == "overview") {
      # OVERVIEW PAGE
      render_overview_page(state_name)

    } else {
      # INDICATOR PAGE WITH TABS
      ind_info <- current_indicator_info()

      tagList(
        # Page header
        div(
          style = "padding: 1.5rem; background: white; border-bottom: 1px solid #e5e7eb;",
          h2(ind_info$name, style = "margin: 0; font-size: 1.875rem; font-weight: 700; color: #1f2937;"),
          p(
            paste0(state_name, " | Data Period: ", selected_profile()),
            style = "margin: 0.5rem 0 0 0; color: #6b7280;"
          )
        ),

        # Horizontal tab navigation
        div(
          class = "tab-navigation",
          actionButton(
            "tab_state_us",
            "Your State & US",
            class = if (active_tab() == "state_us") "tab-btn active" else "tab-btn"
          ),
          actionButton(
            "tab_period",
            "By Period",
            class = if (active_tab() == "period") "tab-btn active" else "tab-btn"
          ),
          actionButton(
            "tab_jurisdiction",
            "By Jurisdiction",
            class = if (active_tab() == "jurisdiction") "tab-btn active" else "tab-btn"
          ),
          actionButton(
            "tab_age",
            "By Age",
            class = if (active_tab() == "age") "tab-btn active" else "tab-btn"
          ),
          actionButton(
            "tab_race",
            "By Race",
            class = if (active_tab() == "race") "tab-btn active" else "tab-btn"
          )
        ),

        # Tab content
        uiOutput("tab_content")
      )
    }
  })

  # Tab button click handlers
  observeEvent(input$tab_state_us, { active_tab("state_us") })
  observeEvent(input$tab_period, { active_tab("period") })
  observeEvent(input$tab_jurisdiction, { active_tab("jurisdiction") })
  observeEvent(input$tab_age, { active_tab("age") })
  observeEvent(input$tab_race, { active_tab("race") })

  # Render tab content
  output$tab_content <- renderUI({
    ind_info <- current_indicator_info()
    state_name <- state_codes[selected_state()]

    switch(
      active_tab(),
      "state_us" = render_state_us_tab(ind_info, state_name),
      "period" = render_period_tab(ind_info, state_name),
      "jurisdiction" = render_jurisdiction_tab(ind_info, state_name),
      "age" = render_age_tab(ind_info, state_name),
      "race" = render_race_tab(ind_info, state_name)
    )
  })
}

#####################################
# HELPER FUNCTIONS ----
#####################################

# Overview page: 8 KPI trend cards
render_overview_page <- function(state_name) {
  div(
    style = "padding: 1.5rem;",
    h2("Observed Performance Overview", style = "font-size: 1.875rem; font-weight: 700; margin-bottom: 1rem;"),
    p(paste0("Showing trend cards for all 8 indicators in ", state_name),
      style = "color: #6b7280; margin-bottom: 1.5rem;"),

    div(
      class = "coming-soon-box",
      div(class = "coming-soon-title", "Coming Soon"),
      div(
        class = "coming-soon-text",
        HTML("This page will display 8 KPI trend cards showing observed performance trends for your state.<br><br>
              <strong>Data needed:</strong> Observed performance trends extracted from PDF page 4.")
      )
    )
  )
}

# Tab: Your State & US (state-by-state comparison)
render_state_us_tab <- function(ind_info, state_name) {
  div(
    style = "padding: 1.5rem;",

    div(
      class = "coming-soon-box",
      div(class = "coming-soon-title", "Coming Soon"),
      div(
        class = "coming-soon-text",
        HTML(paste0(
          "This tab will show a bar chart comparing ", state_name,
          " to all other states for <strong>", ind_info$name, "</strong> (most recent period).<br><br>",
          "<strong>Data needed:</strong> State-by-state data from National - Supplemental Context Data Excel file.<br>",
          "<strong>Implementation:</strong> Will reuse app_national indicator page logic."
        ))
      )
    )
  )
}

# Tab: By Period (trends over time)
render_period_tab <- function(ind_info, state_name) {
  div(
    style = "padding: 1.5rem;",

    # Section 1: Trends
    div(
      style = "margin-bottom: 2rem;",
      h3("Trends Over Time", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "Line chart showing ", state_name, " performance trends for <strong>", ind_info$name,
            "</strong> across all available periods.<br><br>",
            "<strong>Data needed:</strong> Historical observed performance data for this indicator."
          ))
        )
      )
    ),

    # Section 2: Most Recent
    div(
      h3("Most Recent Period", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "KPI card showing most recent performance value for <strong>", ind_info$name, "</strong>.<br><br>",
            "<strong>Data needed:</strong> Latest period observed performance value."
          ))
        )
      )
    )
  )
}

# Tab: By Jurisdiction (county breakdown)
render_jurisdiction_tab <- function(ind_info, state_name) {
  div(
    style = "padding: 1.5rem;",

    # Section 1: Trends by county
    div(
      style = "margin-bottom: 2rem;",
      h3("County Trends Over Time", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "Multi-line chart showing ", state_name, " county trends for <strong>", ind_info$name, "</strong>.<br><br>",
            "<strong>Data needed:</strong> County-level data from ", state_name, " - Supplemental Context Data Excel file."
          ))
        )
      )
    ),

    # Section 2: Most recent by county
    div(
      h3("Most Recent Period by County", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "Bar chart showing county comparison for <strong>", ind_info$name, "</strong> in most recent period.<br><br>",
            "<strong>Data needed:</strong> Latest period county-level data."
          ))
        )
      )
    )
  )
}

# Tab: By Age (age group breakdown)
render_age_tab <- function(ind_info, state_name) {
  div(
    style = "padding: 1.5rem;",

    # Section 1: Trends by age
    div(
      style = "margin-bottom: 2rem;",
      h3("Age Group Trends Over Time", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "Multi-line chart showing ", state_name, " performance trends by age group for <strong>", ind_info$name, "</strong>.<br><br>",
            "<strong>Data needed:</strong> Age-disaggregated data (if available in supplemental data)."
          ))
        )
      )
    ),

    # Section 2: Most recent by age
    div(
      h3("Most Recent Period by Age Group", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "Grouped bar chart showing age group comparison for <strong>", ind_info$name, "</strong>.<br><br>",
            "<strong>Data needed:</strong> Latest period age-disaggregated data."
          ))
        )
      )
    )
  )
}

# Tab: By Race (race/ethnicity breakdown)
render_race_tab <- function(ind_info, state_name) {
  div(
    style = "padding: 1.5rem;",

    # Section 1: Trends by race
    div(
      style = "margin-bottom: 2rem;",
      h3("Race/Ethnicity Trends Over Time", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "Multi-line chart showing ", state_name, " performance trends by race/ethnicity for <strong>", ind_info$name, "</strong>.<br><br>",
            "<strong>Data needed:</strong> Race/ethnicity-disaggregated data (if available in supplemental data)."
          ))
        )
      )
    ),

    # Section 2: Most recent by race
    div(
      h3("Most Recent Period by Race/Ethnicity", style = "font-size: 1.25rem; font-weight: 600; margin-bottom: 1rem;"),
      div(
        class = "coming-soon-box",
        div(class = "coming-soon-title", "Coming Soon"),
        div(
          class = "coming-soon-text",
          HTML(paste0(
            "Grouped bar chart showing race/ethnicity comparison for <strong>", ind_info$name, "</strong>.<br><br>",
            "<strong>Data needed:</strong> Latest period race/ethnicity-disaggregated data."
          ))
        )
      )
    )
  )
}

#####################################
# RUN APP ----
#####################################

shinyApp(ui = ui, server = server)
