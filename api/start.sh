#!/bin/sh
# Applies pending database migrations, then starts the freehire API.
set -e
export ENV="${ENV:-production}"
export COOKIE_SECURE="${COOKIE_SECURE:-true}"
export PORT="${PORT:-8080}"
# Optional features (LLM_*, OAUTH_*, SMTP/SES, Telegram) stay off until their variables are set.
echo "freehire api: applying migrations"
/app/migrate -dir /app/migrations
echo "freehire api: starting on :${PORT}"
exec /app/hire
