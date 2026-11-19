# freehire web frontend (SvelteKit SSR behind nginx). Builds upstream's web/ at the pinned
# release commit (tag deploy-20261119-1635), like upstream's web/Dockerfile.
FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf AS src
ARG FREEHIRE_REF=378e6899bf246531bb256e6cc819742603007838
RUN apk add --no-cache git \
 && git init -q /src && cd /src \
 && git fetch -q --depth 1 https://github.com/strelov1/freehire.git "${FREEHIRE_REF}" \
 && git checkout -q FETCH_HEAD

FROM node:24-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5 AS ds-build
RUN corepack enable && corepack prepare pnpm@11.7.0 --activate
WORKDIR /design-system
COPY --from=src /src/design-system/ ./
RUN pnpm install --frozen-lockfile && pnpm build

FROM node:24-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5 AS build
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

FROM node:24-alpine@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5
RUN apk add --no-cache nginx nginx-mod-http-brotli && chmod 0755 /var/lib/nginx
WORKDIR /app
COPY --from=build /src/build ./build
COPY --from=build /src/node_modules ./node_modules
COPY --from=build /src/package.json ./package.json
# Upstream's nginx site config, patched at start for Railway (port, API host, resolver).
COPY --from=src /src/web/nginx.conf /etc/nginx/freehire-site.conf
COPY --from=src /src/web/nginx-main.conf /etc/nginx/nginx.conf
COPY start.sh /usr/local/bin/start.sh
ENV NODE_PORT=3000 \
    PROTOCOL_HEADER=x-forwarded-proto \
    HOST_HEADER=x-forwarded-host \
    HOME=/tmp/freehire-web/home
USER node
EXPOSE 8080
CMD ["/usr/local/bin/start.sh"]
