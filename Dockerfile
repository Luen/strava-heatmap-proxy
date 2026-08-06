# syntax=docker/dockerfile:1.7

# --- Build stage ---
# Pin to the multi-arch index digest (docker buildx imagetools inspect golang:1.24).
FROM golang:1.24@sha256:d2d2bc1c84f7e60d7d2438a3836ae7d0c847f4888464e7ec9ba3a1339a1ee804 AS build
WORKDIR /src

# Module files first so dependency download stays cached across source edits.
COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./
# Static binary: stdlib-only HTTPS proxy; strip symbols for a smaller artifact.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/strava-heatmap-proxy .

# --- Runtime stage ---
# CGO_ENABLED=0 → static binary; static-debian12 is smaller than base-debian12 and
# still ships CA certs needed for outbound HTTPS to Strava/CloudFront.
# Pin: docker buildx imagetools inspect gcr.io/distroless/static-debian12:nonroot
FROM gcr.io/distroless/static-debian12:nonroot@sha256:f5b485ea962d9bd1186b2f6b3a061191539b905b82ec395de78cbfae51f20e35
WORKDIR /app
COPY --from=build /out/strava-heatmap-proxy ./
EXPOSE 8080
USER nonroot:nonroot
# Cookies are mounted at runtime (e.g. /config/strava-cookies.json); never baked in.
ENTRYPOINT ["/app/strava-heatmap-proxy"]
CMD ["--port", "8080", "--cookies", "/config/strava-cookies.json"]
