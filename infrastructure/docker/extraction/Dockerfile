# ChildMetrix CFSR Extraction Pipeline
# Runs R-based data extraction from Azure Blob Storage + PPT generation
#
# Build: docker build -t cm-extraction -f infrastructure/docker/extraction/Dockerfile .
# Run:   docker run -e AZURE_BLOB_ENDPOINT=... -e AZURE_STORAGE_KEY=... cm-extraction
#
# For PPT with screenshots (optional):
#   docker run -e AUTO_CAPTURE=1 -e AZURE_BLOB_ENDPOINT=... cm-extraction

FROM rocker/r-ver:4.3.2

# System dependencies for PDF extraction, PPT generation, and optional screenshot capture
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpoppler-cpp-dev \
    zlib1g-dev \
    # For officer (PPT generation)
    libfontconfig1-dev \
    libfreetype6-dev \
    # For webshot2/chromote (optional screenshot capture)
    chromium \
    chromium-driver \
    && rm -rf /var/lib/apt/lists/*

# Use Posit Package Manager for faster binary installs
RUN R -e "options(repos = c(CRAN = 'https://p3m.dev/cran/__linux__/jammy/latest')); \
    install.packages(c( \
    # Data extraction
    'tidyverse', 'pdftools', 'readxl', 'openxlsx', \
    'lubridate', 'janitor', 'AzureStor', 'DBI', \
    'odbc', 'jsonlite', 'httr', \
    # PPT generation
    'officer', 'yaml', 'glue', \
    # Screenshot capture (optional, for AUTO_CAPTURE=1)
    'webshot2', 'chromote' \
  ))"

# Set Chrome path for webshot2/chromote
ENV CHROMOTE_CHROME=/usr/bin/chromium
ENV GOOGLE_CHROME=/usr/bin/chromium

WORKDIR /app

# Copy extraction scripts and functions
COPY domains/cfsr/extraction/ /app/domains/cfsr/extraction/
COPY domains/cfsr/functions/ /app/domains/cfsr/functions/
COPY domains/cfsr/data/ /app/domains/cfsr/data/
COPY shared/utils/ /app/shared/utils/

# Copy PPT templates
COPY domains/cfsr/templates/ /app/domains/cfsr/templates/
COPY states/md/_assets/*.pptx /app/states/md/_assets/
COPY states/ky/_assets/*.pptx /app/states/ky/_assets/

# Copy YAML content for talking points
COPY domains/cfsr/content/ /app/domains/cfsr/content/

COPY CLAUDE.md /app/CLAUDE.md

ENV CM_REPORTS_ROOT=/app

ENTRYPOINT ["Rscript", "/app/domains/cfsr/extraction/run.R"]
