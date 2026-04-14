# ChildMetrix CFSR Extraction Pipeline
# Runs R-based data extraction from Azure Blob Storage
#
# Build: docker build -t cm-extraction -f infrastructure/docker/extraction/Dockerfile .
# Run:   docker run -e CM_DATA_SOURCE=azure -e AZURE_BLOB_ENDPOINT=... cm-extraction

FROM rocker/r-ver:4.3.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libpoppler-cpp-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c( \
    'tidyverse', 'pdftools', 'readxl', 'openxlsx', \
    'lubridate', 'janitor', 'AzureStor', 'DBI', \
    'odbc', 'jsonlite', 'httr' \
  ), repos='https://cloud.r-project.org/')"

WORKDIR /app

COPY domains/cfsr/extraction/ /app/domains/cfsr/extraction/
COPY domains/cfsr/functions/ /app/domains/cfsr/functions/
COPY domains/cfsr/data/ /app/domains/cfsr/data/
COPY shared/utils/ /app/shared/utils/
COPY CLAUDE.md /app/CLAUDE.md

ENV CM_DATA_SOURCE=azure
ENV CM_REPORTS_ROOT=/app

ENTRYPOINT ["Rscript", "/app/domains/cfsr/extraction/run.R"]
