# ChildMetrix CFSR Summary Shiny App
# Build: docker build -t cm-app-summary -f infrastructure/docker/shiny/app_summary/Dockerfile .
# Run:   docker run -p 3840:3840 -e CM_DATA_SOURCE=azure ... cm-app-summary

FROM rocker/shiny:4.3.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Use Posit Package Manager for faster binary installs
RUN R -e "options(repos = c(CRAN = 'https://p3m.dev/cran/__linux__/jammy/latest')); \
    install.packages(c( \
    'dplyr', 'tidyr', 'htmltools', 'reactable', 'reactablefmtr', \
    'sparkline', 'AzureStor', 'jsonlite' \
  ))"

WORKDIR /app

# Copy app files to /app (working directory)
COPY domains/cfsr/apps/app_summary/ /app/

# Recreate monorepo structure so paths work correctly
COPY domains/cfsr/data/ /app/domains/cfsr/data/
COPY shared/ /app/shared/
COPY CLAUDE.md /app/CLAUDE.md

ENV CM_DATA_SOURCE=azure
ENV CM_REPORTS_ROOT=/app

# Note: Data is loaded from Azure Blob (CM_DATA_SOURCE=azure), not local files

EXPOSE 3840

CMD ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3840)"]
