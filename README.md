[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/freehire?utm_medium=integration&utm_source=button&utm_campaign=freehire)

# Deploy and Host freehire on Railway

freehire is an open-source (MIT) job search engine. It crawls postings straight from job boards and company career sites, normalises and de-duplicates them, and serves faceted full-text search by region, work mode, seniority, skills and salary. On top it offers accounts, saved jobs, an application board, a CV builder and a public JSON API.

## About Hosting freehire

freehire is a Go API, a SvelteKit web app and a set of run-once workers that crawl sources and keep the search index current, backed by PostgreSQL with pgvector, Redis, Meilisearch and S3-compatible storage for CVs. This template wires all of it on Railway's private network: the web service is the only public one, the API applies its database migrations at start, and a worker service runs the crawl and indexing jobs in a loop (upstream runs them from cron). Secrets are generated at deploy time, Meilisearch keeps its index on a volume, and CVs go to a Railway bucket. The first jobs appear a few minutes after the deploy finishes.

## Common Use Cases

* Run your own job search site over public remote-job feeds, with search, filters and saved jobs
* Track your own applications and CVs on a private instance
* Build on a self-hosted job catalogue through freehire's keyless JSON API

## Dependencies for freehire Hosting

* PostgreSQL (Railway Postgres, which ships pgvector) for jobs, companies, users and the board catalogue
* Meilisearch for job, company and suggestion search; Redis for rate limiting and caches; a Railway bucket for CV files

### Deployment Dependencies

* freehire source and docs: https://github.com/strelov1/freehire
* Release this template builds: https://github.com/strelov1/freehire/releases/tag/deploy-20261119-1635
* Template repo (Dockerfiles, start scripts, changelog): https://github.com/aalfath/freehire-railway-template
* Meilisearch: https://www.meilisearch.com/docs

### Implementation Details

Services in this template:

* **Web** (public): SvelteKit SSR behind nginx. It serves the site and forwards `/api`, `/health` and `/cv` to the API over the private network, so sign-in cookies stay same-origin.
* **API**: the Go server. It applies pending migrations, then serves on port 8080. Health check: `/health`.
* **Worker**: registers the job sources in `INGEST_PROVIDERS` (by default remoteok, remotive, weworkremotely, himalayas, jobicy and workingnomads, which need no API key), creates the search indexes, then every `INGEST_INTERVAL_MINUTES` (60) crawls them and pushes new and closed postings into Meilisearch. It rebuilds the company index and search suggestions once a day.
* **Meilisearch** 1.49.0 (the version upstream runs), with its data on a volume and a generated master key.
* **Postgres**, **Redis** and a **Bucket** (Railway's own).

After deploy: open the Web service's domain and sign up. Accounts are open to anyone who can reach the site, and the first account has no special role. AI features (fit analysis, CV tailoring, the assistant), OAuth sign-in and e-mail are off until you set their variables on the API service (`LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL`; `OAUTH_GITHUB_CLIENT_ID`/`_SECRET` and similar). See upstream's `.env.example`. If you add a custom domain, set `FRONTEND_ORIGIN` on the API service to `https://YOUR-DOMAIN`.

Updates: the template builds from `aalfath/freehire-railway-template`, which pins upstream's release commit and every base image by digest. When we bump the version, Railway shows an update in your project; read `CHANGELOG.md` before you apply it.

## Why Deploy freehire on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying freehire on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

---

## Template repo notes

Folders: `api/`, `web/`, `worker/`, `meilisearch/`. Each is one Railway service with its root directory set to its folder. Upstream publishes no container image, so `api/`, `web/` and `worker/` fetch upstream's source at the pinned commit (`FREEHIRE_REF`) and build it the way upstream's own Dockerfiles do. Railway-specific changes are small and visible in the start scripts: the API listens dual-stack (Fiber defaults to IPv4 only) and trusts `X-Real-IP` from the private IPv6 range; nginx listens on `$PORT`, uses Railway's DNS and points at the API's private domain; the worker enables Meilisearch's `editDocumentsByFunction` feature, which upstream's search drain needs.

Variables, in short:

| Service | Variable | Value |
|---|---|---|
| API | `DATABASE_URL`, `REDIS_URL` | references to Postgres and Redis |
| API | `MEILI_URL`, `MEILI_MASTER_KEY` | references to Meilisearch |
| API | `JWT_SECRET` | generated, 64 characters |
| API | `FRONTEND_ORIGIN` | `https://` + the Web service's public domain |
| API | `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` | references to the bucket |
| Worker | `DATABASE_URL`, `REDIS_URL`, `MEILI_URL`, `MEILI_MASTER_KEY` | references |
| Web | `API_HOST`, `API_PORT` | the API's private domain and port |
| Meilisearch | `MEILI_MASTER_KEY` | generated, 48 characters |

Optional worker settings: `INGEST_PROVIDERS` (space-separated provider names from upstream's `internal/ingest/sources`), `INGEST_INTERVAL_MINUTES`, `REBUILD_EVERY_HOURS`.
