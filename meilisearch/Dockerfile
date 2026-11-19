# Meilisearch for freehire's job and company search. 1.49.0 is the version upstream runs in
# production and pins in its docker-compose.yml.
FROM getmeili/meilisearch:v1.49.0@sha256:bdc7d7e7939911c40d88d6bcd01f9c72c81f7293135916d48bce241569f721bd
# Listen on IPv4 and IPv6 (Railway's private network is IPv6) and keep data on the volume.
ENV MEILI_HTTP_ADDR="[::]:7700" \
    MEILI_DB_PATH=/meili_data/data.ms \
    MEILI_DUMP_DIR=/meili_data/dumps \
    MEILI_SNAPSHOT_DIR=/meili_data/snapshots \
    MEILI_ENV=production \
    MEILI_NO_ANALYTICS=true
EXPOSE 7700
CMD ["/bin/meilisearch"]
