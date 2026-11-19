#!/bin/sh
# Applies pending database migrations, then starts the freehire API.
set -e
export ENV="${ENV:-production}"
export COOKIE_SECURE="${COOKIE_SECURE:-true}"
export PORT="${PORT:-8080}"
# Optional features (LLM_*, OAUTH_*, SMTP/SES, Telegram) stay off until their variables are set.
# The worker runs the same migrations at start; both take the runner's advisory lock, and a
# loser can see "deadlock detected", so retry a few times before giving up.
echo "freehire api: applying migrations"
i=0
until /app/migrate -dir /app/migrations; do
  i=$((i + 1))
  [ "$i" -lt 10 ] || { echo "freehire api: migrations failed"; exit 1; }
  sleep 5
done
echo "freehire api: starting on :${PORT}"
exec /app/hire
