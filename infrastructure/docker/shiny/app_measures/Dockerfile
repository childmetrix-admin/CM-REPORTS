# ChildMetrix CFSR Measures Shiny App
# Build: docker build -t cm-app-measures -f infrastructure/docker/shiny/app_measures/Dockerfile .
# Run:   docker run -p 3838:3838 -e AZURE_BLOB_ENDPOINT=... -e AZURE_STORAGE_KEY=... cm-app-measures

FROM rocker/shiny:4.3.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Use Posit Package Manager for faster binary installs
RUN R -e "options(repos = c(CRAN = 'https://p3m.dev/cran/__linux__/jammy/latest')); \
    install.packages(c( \
    'shinydashboard', 'dplyr', 'tidyr', 'ggplot2', 'plotly', 'DT', \
    'AzureStor', 'htmltools', 'jsonlite', 'scales', 'htmlwidgets' \
  ))"

WORKDIR /app

# Copy app files to /app (working directory)
COPY domains/cfsr/apps/app_measures/ /app/

# Recreate monorepo structure so paths work correctly
COPY domains/cfsr/functions/ /app/domains/cfsr/functions/
COPY domains/cfsr/modules/ /app/domains/cfsr/modules/
COPY domains/cfsr/data/ /app/domains/cfsr/data/
COPY shared/ /app/shared/
COPY CLAUDE.md /app/CLAUDE.md

ENV CM_REPORTS_ROOT=/app

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3838)"]
