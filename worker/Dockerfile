# freehire background worker: the crawl, search-index and rollup jobs that upstream runs from
# cron, in one loop. Builds the pinned upstream release commit (tag deploy-20261119-1635).
FROM golang:1.27-trixie@sha256:f18c3d73a184fb0582828510722e723b63a93f7188d11dd223d9be6f6880e65d AS build
ARG FREEHIRE_REF=378e6899bf246531bb256e6cc819742603007838
RUN git init -q /src && cd /src \
 && git fetch -q --depth 1 https://github.com/strelov1/freehire.git "${FREEHIRE_REF}" \
 && git checkout -q FETCH_HEAD
WORKDIR /src
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/ \
      ./cmd/migrate ./cmd/add-board ./cmd/ingest ./cmd/search-drain ./cmd/reindex \
      ./cmd/reindex-companies ./cmd/recount-companies ./cmd/build-suggestions ./cmd/enrich

FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2
WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system --gid 65532 nonroot \
 && useradd --system --uid 65532 --gid nonroot --home-dir /app nonroot
COPY --from=build /out/ /app/
COPY --from=build /src/migrations /app/migrations
COPY start.sh /app/start.sh
USER nonroot:nonroot
CMD ["/app/start.sh"]
