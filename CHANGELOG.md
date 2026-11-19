# Changelog

## deploy-20261119-1635 (2026-11-19)

First release of the template.

- freehire at upstream commit `378e6899bf246531bb256e6cc819742603007838` (tag `deploy-20261119-1635`).
- Services: Web (public), API, Worker, Meilisearch 1.49.0 (`sha256:bdc7d7e7…`), Railway Postgres, Redis and a bucket.
- Default job sources: remoteok, remotive, weworkremotely, himalayas, jobicy, workingnomads (arbeitnow is left out because it answers HTTP 429 to crawls from Railway).
- Base images pinned by digest: `golang:1.27-trixie`, `debian:trixie-slim`, `node:24-trixie-slim`.
