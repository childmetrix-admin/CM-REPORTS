# ShinyProxy - Manages Shiny app containers with authentication
# Build: docker build -t cm-shinyproxy -f infrastructure/docker/shinyproxy/Dockerfile infrastructure/docker/shinyproxy/

FROM openjdk:21-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

ARG SHINYPROXY_VERSION=3.1.1
RUN curl -L -o /opt/shinyproxy.jar \
    "https://www.shinyproxy.io/downloads/shinyproxy-${SHINYPROXY_VERSION}.jar"

COPY application.yml /opt/application.yml

WORKDIR /opt

EXPOSE 8080

CMD ["java", "-jar", "/opt/shinyproxy.jar"]
