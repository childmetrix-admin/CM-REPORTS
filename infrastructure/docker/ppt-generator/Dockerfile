# ChildMetrix CFSR PowerPoint Generator
# Generates PPT presentations with embedded screenshots using headless Chrome
#
# Build:
#   docker build -t cm-ppt-generator -f infrastructure/docker/ppt-generator/Dockerfile .
#
# Run:
#   docker run \
#     -e AZURE_BLOB_ENDPOINT=https://stchildmetrixprod.blob.core.windows.net \
#     -e AZURE_STORAGE_KEY=... \
#     -e AZURE_BLOB_CONTAINER_PROCESSED=processed \
#     -e CM_PUBLIC_MEASURES_URL=https://ca-app-measures.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io \
#     -e CM_PUBLIC_SUMMARY_URL=https://ca-app-summary.icyforest-fe9bbf66.southcentralus.azurecontainerapps.io \
#     cm-ppt-generator md 2025_02 2025_08 2026_02

FROM rocker/r-ver:4.3.2

# Install system dependencies + Chrome
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    zlib1g-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libwebp-dev \
    wget \
    gnupg \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Use Posit Package Manager for faster binary installs
RUN R -e "options(repos = c(CRAN = 'https://p3m.dev/cran/__linux__/jammy/latest')); \
    install.packages(c( \
    'tidyverse', 'officer', 'yaml', 'glue', 'AzureStor', \
    'webshot2', 'chromote', 'jsonlite', 'httr' \
  ))"

WORKDIR /app

# Copy necessary files
COPY domains/cfsr/scripts/ /app/domains/cfsr/scripts/
COPY domains/cfsr/functions/ /app/domains/cfsr/functions/
COPY domains/cfsr/extraction/ /app/domains/cfsr/extraction/
COPY domains/cfsr/content/ /app/domains/cfsr/content/
COPY domains/cfsr/data/ /app/domains/cfsr/data/
COPY shared/utils/ /app/shared/utils/
COPY states/ /app/states/

ENV CM_REPORTS_ROOT=/app
ENV CHROMOTE_CHROME=/usr/bin/google-chrome

# Entry script handles multiple state/period combinations
COPY infrastructure/docker/ppt-generator/generate_all.R /app/generate_all.R

ENTRYPOINT ["Rscript", "/app/generate_all.R"]
