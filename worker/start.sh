#!/bin/sh
# freehire worker loop for Railway. Upstream runs each job as a run-once systemd timer; here
# one long-running service runs them in order:
#   1. migrate (shares an advisory lock with the API, so the two never race)
#   2. register the job sources in INGEST_PROVIDERS in the board catalogue (once each)
#   3. build the Meilisearch indexes, so search works before the first crawl finishes
#   4. every INGEST_INTERVAL_MINUTES: crawl each source, push new postings into search,
#      recount companies; once a day rebuild the full indexes and search suggestions.
set -u
INGEST_PROVIDERS="${INGEST_PROVIDERS:-remoteok remotive weworkremotely himalayas jobicy arbeitnow workingnomads}"
INGEST_INTERVAL_MINUTES="${INGEST_INTERVAL_MINUTES:-60}"
REINDEX_EVERY_HOURS="${REINDEX_EVERY_HOURS:-24}"
export REINDEX_MIN_FREE_GB="${REINDEX_MIN_FREE_GB:-0}"
export INGEST_RUN_TIMEOUT_SECONDS="${INGEST_RUN_TIMEOUT_SECONDS:-1800}"

log() { echo "freehire worker: $*"; }
run() { log "run $*"; "$@" || log "$1 exited with $?"; }

until /app/migrate -dir /app/migrations; do log "migrate failed, retrying in 10s"; sleep 10; done

for p in $INGEST_PROVIDERS; do
  # Boardless aggregators need one catalogue row; a second insert is refused as a duplicate.
  /app/add-board --provider="$p" --company="$p" --apply >/dev/null 2>&1 && log "registered source $p"
done

run /app/reindex
run /app/reindex-companies
last_reindex=$(date +%s)

while :; do
  for p in $INGEST_PROVIDERS; do run /app/ingest "$p"; done
  if [ -n "${LLM_BASE_URL:-}" ] && [ -n "${LLM_MODEL:-}" ]; then run /app/enrich; fi
  run /app/search-drain
  run /app/recount-companies
  now=$(date +%s)
  if [ $((now - last_reindex)) -ge $((REINDEX_EVERY_HOURS * 3600)) ] || [ ! -f /tmp/first-cycle-done ]; then
    run /app/reindex
    run /app/reindex-companies
    run /app/build-suggestions
    last_reindex=$now
    touch /tmp/first-cycle-done
  fi
  log "cycle done; next in ${INGEST_INTERVAL_MINUTES} min"
  sleep $((INGEST_INTERVAL_MINUTES * 60))
done
