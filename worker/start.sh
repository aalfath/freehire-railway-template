#!/bin/sh
# freehire worker loop for Railway. Upstream runs each job as a run-once systemd timer; here
# one long-running service runs them in order:
#   1. migrate (shares an advisory lock with the API, so the two never race)
#   2. register the job sources in INGEST_PROVIDERS in the board catalogue (once each)
#   3. wait for Meilisearch, enable the experimental "edit documents by function" feature
#      upstream's search-drain needs (it marks closed and duplicate postings), and create
#      the search indexes
#   4. every INGEST_INTERVAL_MINUTES: crawl each source, push new and closed postings into
#      search (search-drain, upstream's routine path), recount companies; once a day rebuild
#      the companies index and the search-box suggestions.
set -u
INGEST_PROVIDERS="${INGEST_PROVIDERS:-remoteok remotive weworkremotely himalayas jobicy arbeitnow workingnomads}"
INGEST_INTERVAL_MINUTES="${INGEST_INTERVAL_MINUTES:-60}"
REBUILD_EVERY_HOURS="${REBUILD_EVERY_HOURS:-24}"
export REINDEX_MIN_FREE_GB="${REINDEX_MIN_FREE_GB:-0}"
export INGEST_RUN_TIMEOUT_SECONDS="${INGEST_RUN_TIMEOUT_SECONDS:-1800}"

log() { echo "freehire worker: $*"; }
run() { log "run $*"; "$@" || log "$1 exited with $?"; }

until /app/migrate -dir /app/migrations; do log "migrate failed, retrying in 10s"; sleep 10; done

for p in $INGEST_PROVIDERS; do
  # Boardless aggregators need one catalogue row; a second insert is refused as a duplicate.
  /app/add-board --provider="$p" --company="$p" --apply >/dev/null 2>&1 && log "registered source $p"
done

i=0
until curl -fsS -o /dev/null "${MEILI_URL}/health"; do
  i=$((i + 1)); [ "$i" -lt 60 ] || break
  log "waiting for Meilisearch"; sleep 5
done
curl -fsS -o /dev/null -X PATCH "${MEILI_URL}/experimental-features" \
  -H "Authorization: Bearer ${MEILI_MASTER_KEY}" -H "Content-Type: application/json" \
  --data '{"editDocumentsByFunction": true}' && log "Meilisearch edit-documents-by-function enabled"
# On a fresh deploy, create the jobs index with its settings (reindex of the still-empty
# catalogue). Upstream treats the full rebuild as a manual step and keeps the index current
# with search-drain, so a restart with an existing index skips it.
if ! curl -fsS -o /dev/null -H "Authorization: Bearer ${MEILI_MASTER_KEY}" "${MEILI_URL}/indexes/jobs"; then
  run /app/reindex
fi
run /app/reindex-companies
last_rebuild=0

while :; do
  for p in $INGEST_PROVIDERS; do run /app/ingest "$p"; done
  if [ -n "${LLM_BASE_URL:-}" ] && [ -n "${LLM_MODEL:-}" ]; then run /app/enrich; fi
  run /app/search-drain
  run /app/recount-companies
  now=$(date +%s)
  if [ $((now - last_rebuild)) -ge $((REBUILD_EVERY_HOURS * 3600)) ]; then
    run /app/reindex-companies
    run /app/build-suggestions
    last_rebuild=$now
  fi
  log "cycle done; next in ${INGEST_INTERVAL_MINUTES} min"
  sleep $((INGEST_INTERVAL_MINUTES * 60))
done
