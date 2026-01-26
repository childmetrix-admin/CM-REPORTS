# viz_container.R - Reusable visualization container with self-contained context

#' Build self-contained visualization container
#'
#' Wraps a chart with self-contained context (title, description, metadata, legend)
#' and download button for PNG export via html2canvas
#'
#' @param ns Namespace function from Shiny module
#' @param viz_id Unique ID for this visualization (e.g., "by_state", "by_county")
#' @param title Indicator title (e.g., "Maltreatment in care")
#' @param description Indicator description (full text)
#' @param period Period meaningful text (e.g., "Oct '21 - Sep '22")
#' @param profile Profile version (e.g., "Feb 2025")
#' @param state State name (e.g., "Maryland", "Kentucky")
#' @param legend HTML content for legend (e.g., national standard line)
#' @param chart_output Shiny output object (plotlyOutput or placeholder HTML)
#' @param source Source citation (e.g., "AFCARS, NCANDS")
#' @param notes Additional notes (HTML, optional)
#' @return tagList with complete viz container structure
#' @export
build_viz_container <- function(ns, viz_id, title, description,
                                period, profile, state = NULL, legend, chart_output,
                                source = NULL, notes = NULL) {

  container_id <- paste0("viz-container-", viz_id)

  tagList(
    div(
      id = container_id,
      class = "viz-export-container",

      # Download button (top-right corner, hidden during export)
      div(
        class = "viz-download-button",
        actionButton(
          ns(paste0("download_", viz_id)),
          "Download",
          icon = icon("download"),
          onclick = sprintf("downloadViz('%s', 'cfsr_viz_%s.png')",
                           container_id, viz_id)
        )
      ),

      # Context header (embedded in visualization)
      div(
        class = "viz-context-header",

        # Title (smaller and gray to differentiate from page-level title)
        div(class = "viz-title", title),

        # Description
        div(class = "viz-description", description),

        # Pills and legend row (all on same line)
        div(
          class = "viz-pills-row",
          div(class = "viz-period-pill", period),
          if (!is.null(state) && state != "") {
            div(class = "viz-state-pill", state)
          },
          if (!is.null(legend) && as.character(legend) != "" && as.character(legend) != "<span></span>") {
            div(class = "viz-legend-pill", legend)
          }
        )
      ),

      # Chart area
      div(class = "viz-chart-area", chart_output),

      # Source footnote (at bottom)
      if (!is.null(source) && source != "") {
        div(class = "viz-source", HTML(paste0("Source: ", source)))
      },

      # Notes (on separate line if provided)
      if (!is.null(notes) && notes != "") {
        div(class = "viz-notes", HTML(notes))
      }
    )
  )
}
