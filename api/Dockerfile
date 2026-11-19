# freehire API (Go). Upstream publishes no container image, so this builds the pinned
# upstream release commit (tag deploy-20261119-1635) the same way upstream's own Dockerfile does.
FROM golang:1.27-trixie@sha256:f18c3d73a184fb0582828510722e723b63a93f7188d11dd223d9be6f6880e65d AS build
ARG FREEHIRE_REF=378e6899bf246531bb256e6cc819742603007838
RUN git init -q /src && cd /src \
 && git fetch -q --depth 1 https://github.com/strelov1/freehire.git "${FREEHIRE_REF}" \
 && git checkout -q FETCH_HEAD
WORKDIR /src
RUN go mod download
# Railway patches (kept tiny): listen dual-stack (IPv4 + IPv6) so Railway's private network
# reaches the API (Fiber defaults to tcp4), and trust X-Real-IP from the private IPv6 range the
# web service connects from, so rate limits key on the real visitor.
COPY patch-server.sh /patch-server.sh
RUN sh /patch-server.sh cmd/server/main.go
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/hire ./cmd/server \
 && CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/ ./cmd/migrate

# typst renders CV PDFs (same pinned binary and checksum as upstream).
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS typst
ARG TYPST_VERSION=0.15.0
ARG TYPST_SHA256=59b207df01be2dab9f13e80f73d04d7ff8273ffd46b3dd1b9eef5c60f3eeabea
RUN apt-get update && apt-get install -y --no-install-recommends curl xz-utils ca-certificates \
 && curl -fsSL "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz" -o /tmp/typst.tar.xz \
 && printf '%s  /tmp/typst.tar.xz\n' "${TYPST_SHA256}" | sha256sum -c - \
 && tar -xJf /tmp/typst.tar.xz -C /tmp \
 && install -m 0755 /tmp/typst-x86_64-unknown-linux-musl/typst /usr/local/bin/typst

FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2
WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends poppler-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system --gid 65532 nonroot \
 && useradd --system --uid 65532 --gid nonroot --home-dir /app nonroot
COPY --from=build /out/hire /out/migrate /app/
COPY --from=build /src/migrations /app/migrations
COPY --from=typst /usr/local/bin/typst /app/typst
COPY start.sh /app/start.sh
ENV TYPST_BIN=/app/typst PORT=8080
EXPOSE 8080
USER nonroot:nonroot
CMD ["/app/start.sh"]
