# freehire web frontend (SvelteKit SSR behind nginx). Builds upstream's web/ at the pinned
# release commit (tag deploy-20261119-1635), like upstream's web/Dockerfile.
FROM golang:1.27-trixie@sha256:f18c3d73a184fb0582828510722e723b63a93f7188d11dd223d9be6f6880e65d AS src
ARG FREEHIRE_REF=378e6899bf246531bb256e6cc819742603007838
RUN git init -q /src && cd /src \
 && git fetch -q --depth 1 https://github.com/strelov1/freehire.git "${FREEHIRE_REF}" \
 && git checkout -q FETCH_HEAD

FROM node:24-trixie-slim@sha256:af02d57b57719b9657a45199a79264a9437940cd55b3c7b3fc99615654f124a0 AS ds-build
RUN corepack enable && corepack prepare pnpm@11.7.0 --activate
WORKDIR /design-system
COPY --from=src /src/design-system/ ./
RUN pnpm install --frozen-lockfile && pnpm build

FROM node:24-trixie-slim@sha256:af02d57b57719b9657a45199a79264a9437940cd55b3c7b3fc99615654f124a0 AS build
RUN corepack enable && corepack prepare pnpm@11.7.0 --activate
WORKDIR /src
COPY --from=ds-build /design-system /design-system
COPY --from=src /src/web/package.json /src/web/pnpm-lock.yaml /src/web/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY --from=src /src/web/ ./
# ORIGIN is left empty on purpose: the SSR server then derives the public origin per request
# from nginx's X-Forwarded-* headers, so one image serves any Railway or custom domain.
ENV ORIGIN=""
RUN NODE_OPTIONS=--max-old-space-size=3072 pnpm run build && pnpm prune --prod

FROM node:24-trixie-slim@sha256:af02d57b57719b9657a45199a79264a9437940cd55b3c7b3fc99615654f124a0
RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static \
 && rm -rf /var/lib/apt/lists/* \
 && chmod 0755 /var/lib/nginx /var/log/nginx
WORKDIR /app
COPY --from=build /src/build ./build
COPY --from=build /src/node_modules ./node_modules
COPY --from=build /src/package.json ./package.json
# Upstream's nginx site config, patched at start for Railway (port, API host, resolver).
COPY --from=src /src/web/nginx.conf /etc/nginx/freehire-site.conf
COPY --from=src /src/web/nginx-main.conf /etc/nginx/freehire-main.conf
COPY start.sh /usr/local/bin/start.sh
ENV NODE_PORT=3000 \
    PROTOCOL_HEADER=x-forwarded-proto \
    HOST_HEADER=x-forwarded-host \
    HOME=/tmp/freehire-web/home
USER node
EXPOSE 8080
CMD ["/usr/local/bin/start.sh"]
