# syntax=docker/dockerfile:1.7

# --- Build stage ---
FROM golang:1.24 AS build
WORKDIR /src
# Copy local source code
COPY go.mod go.sum ./
COPY *.go ./
# Build the proxy binary from local source
RUN CGO_ENABLED=0 go build -o strava-heatmap-proxy .

# --- Runtime stage ---
FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY --from=build /src/strava-heatmap-proxy ./
EXPOSE 8080
USER nonroot:nonroot
# Looks for cookies at /config/strava-cookies.json by default (mount it read-only)
ENTRYPOINT ["/app/strava-heatmap-proxy"]
CMD ["--port","8080","--cookies","/config/strava-cookies.json"]
