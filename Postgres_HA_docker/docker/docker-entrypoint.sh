#!/bin/bash
set -e

PGDATA="/data/postgresql"

# Fix ownership if running as root
if [ "$(id -u)" = "0" ]; then
    mkdir -p "$PGDATA"
    mkdir -p /run/postgresql
    chown -R postgres:postgres "$PGDATA"
    chmod 0700 "$PGDATA"
    chown -R postgres:postgres /run/postgresql
    chown -R postgres:postgres /wal_archive 2>/dev/null || true
    chown -R postgres:postgres /var/log/postgresql 2>/dev/null || true
    exec gosu postgres "$0" "$@"
fi

NEEDS_INIT=false
if [ "$1" = "patroni" ]; then
    if [ ! -f "$PGDATA/PG_VERSION" ]; then
        if [ -f /docker-entrypoint-initdb.d/init.sh ]; then
            echo "[entrypoint] First start detected, init script found."
            NEEDS_INIT=true
        fi
    fi
fi

echo "[entrypoint] Starting Patroni..."
patroni "$@" &
PATRONI_PID=$!

if [ "$NEEDS_INIT" = true ]; then
    echo "[entrypoint] Waiting for PostgreSQL to become ready..."
    for i in $(seq 1 120); do
        if pg_isready -U postgres -h localhost -p 5432 2>/dev/null; then
            echo "[entrypoint] PostgreSQL is ready. Running init scripts..."
            bash /docker-entrypoint-initdb.d/init.sh
            break
        fi
        if ! kill -0 $PATRONI_PID 2>/dev/null; then
            echo "[entrypoint] Patroni process exited unexpectedly!"
            exit 1
        fi
        sleep 2
    done
else
    # ── Every-boot: ensure monitoring user exists ──────────────
    echo "[entrypoint] Ensuring monitoring user exists..."
    for i in $(seq 1 60); do
        if pg_isready -U postgres -h localhost -p 5432 2>/dev/null; then
            # Run idempotent user/role creation; errors expected on replicas (read-only)
            psql -U postgres -f /scripts/pgsql_init.sql 2>/dev/null || true
            break
        fi
        if ! kill -0 $PATRONI_PID 2>/dev/null; then
            echo "[entrypoint] Patroni process exited unexpectedly!"
            exit 1
        fi
        sleep 2
    done
fi

cleanup() {
    echo "[entrypoint] Shutting down..."
    kill $PATRONI_PID 2>/dev/null
    wait $PATRONI_PID
    exit $?
}
trap cleanup SIGTERM SIGINT

wait $PATRONI_PID
