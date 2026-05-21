FROM ongres/patroni:latest

USER root

# Install gosu for dropping privileges — supports both amd64 and arm64 (Apple Silicon)
ARG TARGETARCH
RUN case "${TARGETARCH:-amd64}" in \
        arm64) gosu_arch="arm64" ;; \
        *)     gosu_arch="amd64" ;; \
    esac && \
    curl -fsSL "https://github.com/tianon/gosu/releases/download/1.17/gosu-${gosu_arch}" \
         -o /usr/local/bin/gosu && \
    chmod +x /usr/local/bin/gosu

COPY docker-entrypoint.sh /
COPY init.sh /docker-entrypoint-initdb.d/init.sh
COPY init_databases.sql /scripts/init_databases.sql
COPY pg_functions.sql /scripts/pg_functions.sql
COPY pgsql_init.sql /scripts/pgsql_init.sql
COPY create_users.sql /scripts/create_users.sql

RUN chmod +x /docker-entrypoint.sh /docker-entrypoint-initdb.d/init.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["patroni"]
