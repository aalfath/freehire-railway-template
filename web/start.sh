#!/bin/sh
# Starts the SvelteKit SSR server and nginx (the public face) for Railway.
# nginx serves on $PORT, sends /api, /health and /cv to the freehire API over Railway's
# private network ($API_HOST:$API_PORT), and everything else to Node on 127.0.0.1:3000.
set -e
PORT="${PORT:-8080}"
API_HOST="${API_HOST:?API_HOST must point at the API service}"
API_PORT="${API_PORT:-8080}"
RESOLVER=$(awk '/^nameserver / { print $2; exit }' /etc/resolv.conf)
RESOLVER=${RESOLVER:-127.0.0.11}
case "$RESOLVER" in *:*) RESOLVER="[$RESOLVER]";; esac
mkdir -p /tmp/freehire-web "$HOME"
sed -e "s|resolver 127\.0\.0\.11 valid=30s ipv6=off;|resolver ${RESOLVER} valid=30s ipv6=on;|" \
    -e "s|listen 8080;|listen ${PORT}; listen [::]:${PORT};|" \
    -e "s|http://app:8080|http://${API_HOST}:${API_PORT}|g" \
    /etc/nginx/freehire-site.conf > /tmp/freehire-web/default.conf
# Railway's edge terminates TLS and sends X-Forwarded-Proto: https. Upstream's config forwards
# nginx's own \$scheme (http), which would make the SSR build http:// canonical URLs.
sed -i 's|proxy_set_header X-Forwarded-Proto \$scheme;|proxy_set_header X-Forwarded-Proto $fwd_proto;|' /tmp/freehire-web/default.conf
printf 'map $http_x_forwarded_proto $fwd_proto { default $http_x_forwarded_proto; "" $scheme; }\n' > /tmp/freehire-web/proto.conf
cat /tmp/freehire-web/proto.conf /tmp/freehire-web/default.conf > /tmp/freehire-web/site.conf
mv /tmp/freehire-web/site.conf /tmp/freehire-web/default.conf
# One nginx worker per CPU the container really has, not per host CPU.
# Debian keeps dynamic modules (brotli) in modules-enabled, Alpine in modules.
sed -e "s|worker_processes auto;|worker_processes ${NGINX_WORKERS:-2};|" \
    -e "s|include /etc/nginx/modules/\*.conf;|include /etc/nginx/modules-enabled/*.conf;|" \
    /etc/nginx/freehire-main.conf > /tmp/freehire-web/nginx.conf
API_INTERNAL_URL="http://${API_HOST}:${API_PORT}" PORT="${NODE_PORT:-3000}" HOST=127.0.0.1 node build &
exec nginx -c /tmp/freehire-web/nginx.conf -e stderr -g 'daemon off;'
