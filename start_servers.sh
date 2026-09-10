#!/usr/bin/env bash
set -e
# Note: pipefail is bash-specific; we'll omit it for maximum portability or ensure bash usage.
# If running with sh -> dash, -o pipefail fails.
# We use #!/usr/bin/env bash to target bash specifically.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PG_DIR="$ROOT_DIR/Postgres_HA_docker"
SQL_DIR="$ROOT_DIR/SQL_Server_HA_Docker"
WEB_DIR="$ROOT_DIR/web_app"

# ── helpers ─────────────────────────────────────────────────────
info()  { printf "\e[36m%s\e[0m\n" "$*"; }
ok()    { printf "\e[32m[+] %s\e[0m\n" "$*"; }
warn()  { printf "\e[33m[~] %s\e[0m\n" "$*"; }
err()   { printf "\e[31m[!] %s\e[0m\n" "$*"; exit 1; }

# ── flags ───────────────────────────────────────────────────────
SKIP_PG=false
SKIP_SQL=false
NO_WEB=false
STATUS=false
STOP=false
DETACH=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --SkipPostgres|--skip-postgres) SKIP_PG=true ;;
        --SkipSqlServer|--skip-sql-server) SKIP_SQL=true ;;
        --NoWebApp|--no-web-app) NO_WEB=true ;;
        --Status|--status) STATUS=true ;;
        --Stop|--stop) STOP=true ;;
        --Detach|--detach|--Background|--background) DETACH=true ;;
        *) err "Unknown flag: $1" ;;
    esac
    shift
done

# ── Resource Advisor ────────────────────────────────────────────
get_total_ram_gb() {
    local ram_kb ram_bytes
    if [[ "$(uname -s)" == "Darwin" ]]; then
        ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || sysctl hw.memsize | awk '{print $2}')
        ram_kb=$(( ram_bytes / 1024 ))
    else
        ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
    fi
    if [[ -z "$ram_kb" || "$ram_kb" -eq 0 ]]; then
        echo "8.0"
        return
    fi
    awk -v k="$ram_kb" 'BEGIN { printf "%.1f\n", k / (1024 * 1024) }'
}

compute_scale() {
    awk -v ram="$1" 'BEGIN {
        if (ram >= 32) print "1.0";
        else if (ram >= 16) print "0.5";
        else if (ram >= 8) print "0.30";
        else print "0.15";
    }'
}

format_gb() {
    awk -v base="$1" -v scale="$2" -v min="$3" 'BEGIN {
        v = base * scale;
        if (v < min) v = min;
        printf "%.1fg\n", v;
    }'
}

format_mb() {
    awk -v base="$1" -v scale="$2" -v min="$3" 'BEGIN {
        v = int(base * scale);
        if (v < min) v = min;
        printf "%dm\n", v;
    }'
}

generate_overrides() {
    local scale="$1"

    local pg_mem sql12_mem sql3_mem
    pg_mem=$(format_gb 2 "$scale" 0.5)
    sql12_mem=$(format_gb 6 "$scale" 2)
    sql3_mem=$(format_gb 4 "$scale" 2)

    local pg_etcd pg_haproxy pg_backup pg_seaweed
    pg_etcd=$(format_mb 256 "$scale" 128)
    pg_haproxy=$(format_mb 128 "$scale" 64)
    pg_backup=$(format_mb 512 "$scale" 256)
    pg_seaweed=$(format_mb 512 "$scale" 256)

    local sb ec
    sb=$(format_mb 512 "$scale" 64 | sed 's/m$/MB/')
    ec=$(format_mb 1536 "$scale" 192 | sed 's/m$/MB/')

    # PG override
    cat > "$PG_DIR/docker-compose.override.yml" <<YAML
services:
  patroni1:
    mem_limit: ${pg_mem}
    environment:
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: ${sb}
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE: ${ec}
  patroni2:
    mem_limit: ${pg_mem}
    environment:
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: ${sb}
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE: ${ec}
  patroni3:
    mem_limit: ${pg_mem}
    environment:
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: ${sb}
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE: ${ec}
  etcd:
    mem_limit: ${pg_etcd}
  haproxy:
    mem_limit: ${pg_haproxy}
  pg_backup:
    mem_limit: ${pg_backup}
  seaweedfs:
    mem_limit: ${pg_seaweed}
YAML
    ok "Generated PG override: $PG_DIR/docker-compose.override.yml"

    # SQL override
    cat > "$SQL_DIR/docker-compose.override.yml" <<YAML
services:
  sql1:
    mem_limit: ${sql12_mem}
  sql2:
    mem_limit: ${sql12_mem}
  sql3:
    mem_limit: ${sql3_mem}
YAML
    ok "Generated SQL override: $SQL_DIR/docker-compose.override.yml"
}

show_resource_plan() {
    local ram="$1" scale="$2"
    local pg_mem sql12_mem sql3_mem sb ec
    pg_mem=$(format_gb 2 "$scale" 0.5)
    sql12_mem=$(format_gb 6 "$scale" 1)
    sql3_mem=$(format_gb 4 "$scale" 1)
    sb=$(format_mb 512 "$scale" 64 | sed 's/m$/MB/')
    ec=$(format_mb 1536 "$scale" 192 | sed 's/m$/MB/')

    warn "  System: ${ram}GB RAM | Scale: ${scale}"
    info "  PostgreSQL: ${pg_mem}/node, shared_buffers=${sb}, effective_cache=${ec}"
    info "  SQL Server: ${sql12_mem}/node (sql1,sql2), ${sql3_mem} (sql3)"
}

remove_overrides() {
    rm -f "$PG_DIR/docker-compose.override.yml"
    rm -f "$SQL_DIR/docker-compose.override.yml"
    ok "Override files cleaned up"
}

# ── Engine Choice Prompt ────────────────────────────────────────
prompt_engine_choice() {
    echo ""
    info "=== Engine Selection ==="
    echo "  Which database engine(s) would you like to start?"
    echo "    [1] Both PostgreSQL and SQL Server (recommended)"
    echo "    [2] PostgreSQL only"
    echo "    [3] SQL Server only"
    echo "    [4] Exit"
    echo ""
    # Read from the real terminal so this still works when launched via curl | bash
    if [[ -e /dev/tty ]]; then
        read -r -p "  Enter choice (1-4): " choice </dev/tty
    else
        read -r -p "  Enter choice (1-4): " choice
    fi
    case "$choice" in
        1) SKIP_PG=false; SKIP_SQL=false ;;
        2) SKIP_PG=false; SKIP_SQL=true ;;
        3) SKIP_PG=true;  SKIP_SQL=false ;;
        4) info "  Exiting."; exit 0 ;;
        *) warn "  [!] Invalid choice. Please enter 1-4.\n"; prompt_engine_choice ;;
    esac
}

# ── Web app (Docker) ────────────────────────────────────────────
web_compose() {
    local files=(-f "$WEB_DIR/docker-compose.yml")
    if ! $SKIP_PG && docker volume inspect sqloptima_wal_archive >/dev/null 2>&1; then
        files+=(-f "$WEB_DIR/docker-compose.pg.yml")
    fi
    docker compose "${files[@]}" "$@"
}

start_web_app() {
    info "  Building and starting web app container..."
    web_compose up -d --build
    sleep 2
    if docker ps --format '{{.Names}}' | grep -qx sqloptima_web; then
        ok "Web app starting on http://localhost:5002 (container: sqloptima_web)"
    else
        err "Web app container failed to start. Check: docker logs sqloptima_web"
    fi
}

stop_web_app() {
    docker compose -f "$WEB_DIR/docker-compose.yml" down 2>/dev/null || docker rm -f sqloptima_web 2>/dev/null || true
    ok "Web app stopped"
}

show_status() {
    info "=== Status ==="
    info "  PostgreSQL HA:"
    cd "$PG_DIR" && docker compose ps 2>/dev/null | tail -n +3 || echo "    (not running)"
    info "  SQL Server HA:"
    cd "$SQL_DIR" && docker compose ps 2>/dev/null | tail -n +3 || echo "    (not running)"
    info "  Web App:"
    docker compose -f "$WEB_DIR/docker-compose.yml" ps 2>/dev/null | tail -n +2 || echo "    (not running)"
}

stop_all() {
    info "=== Stopping All Servers ==="
    stop_web_app
    info "  Stopping PostgreSQL HA..."
    cd "$PG_DIR" && docker compose down 2>/dev/null || true
    info "  Stopping SQL Server HA..."
    cd "$SQL_DIR" && docker compose down 2>/dev/null || true
    remove_overrides
    ok "All servers stopped"
}

# ── Main ─────────────────────────────────────────────────────────
cd "$ROOT_DIR"

$STATUS && { show_status; exit 0; }
$STOP  && { stop_all;   exit 0; }

# ── Engine Selection ─────────────────────────────────────────────
if ! $SKIP_PG && ! $SKIP_SQL; then
    prompt_engine_choice
fi

if $SKIP_PG && ! $SKIP_SQL; then
    export ACTIVE_ENVS=sqlserver
elif $SKIP_SQL && ! $SKIP_PG; then
    export ACTIVE_ENVS=postgres
else
    export ACTIVE_ENVS=all
fi

# ── Resource Detection & Override Generation ─────────────────────
info "=== Resource Detection ==="
TOTAL_RAM=$(get_total_ram_gb)
SCALE=$(compute_scale "$TOTAL_RAM")
show_resource_plan "$TOTAL_RAM" "$SCALE"

generate_overrides "$SCALE"
echo ""

if ! docker info &>/dev/null; then
    err "Docker is not running."
fi

# 1. PostgreSQL
if ! $SKIP_PG; then
    info "[1/3] Starting PostgreSQL HA Cluster (Patroni)..."
    cd "$PG_DIR" && docker compose up -d --build && cd "$ROOT_DIR"
    ok "PostgreSQL HA cluster started"
    echo ""
fi

# 2. SQL Server
if ! $SKIP_SQL; then
    info "[2/3] Starting SQL Server HA Cluster..."
    cd "$SQL_DIR" && docker compose up -d --build && cd "$ROOT_DIR"
    ok "SQL Server HA cluster started"
    echo ""
fi

info "[*] Waiting for containers to initialize (60s)..."
sleep 60

info ""
info "============================================"
info "  All services started!"
info "============================================"
info "  Postgres HA:   localhost:5043 (direct), localhost:5000 (HAProxy write)"
info "  SQL Server:    localhost:14331 (sql1), 14332 (sql2), 14333 (sql3)"
info "  Web App:       http://localhost:5002"
info "============================================"

# 3. Web App
if ! $NO_WEB; then
    if $DETACH; then
        info "[3/3] Starting CRUD Web App (detached mode)..."
        start_web_app
        info "  Use ./stop_servers.sh to stop all services."
    else
        info "[3/3] Starting CRUD Web App (foreground mode)..."
        echo ""
        info "  Open http://localhost:5002 in your browser."
        info "  Press Ctrl+C to stop the web app (database containers keep running)."
        echo "---"
        web_compose up --build
        echo ""
        info "Web app stopped."
        info "Containers are still running. To stop them:"
        info "  ./stop_servers.sh"
    fi
fi
