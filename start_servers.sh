#!/usr/bin/env bash
set -euo pipefail

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
    local ram_kb
    if [[ "$(uname -s)" == "Darwin" ]]; then
        ram_kb=$(sysctl hw.memsize | awk '{print $2}')
        ram_kb=$(( ram_kb / 1024 ))
    else
        ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null)
    fi
    if [[ -z "$ram_kb" ]]; then
        echo "8.0"
        return
    fi
    python3 -c "print(round($ram_kb / (1024*1024), 1))"
}

compute_scale() {
    local ram="$1"
    python3 -c "
ram = float('$ram')
if ram >= 32: print(1.0)
elif ram >= 16: print(0.5)
elif ram >= 8: print(0.30)
else: print(0.15)
"
}

format_gb() { python3 -c "print(str(max(round($1 * $2, 1), $3)) + 'g')"; }
format_mb() { python3 -c "print(str(max(int($1 * $2), $3)) + 'm')"; }

generate_overrides() {
    local scale="$1"

    local pg_mem sql12_mem sql3_mem
    pg_mem=$(format_gb 2 "$scale" 0.5)
    sql12_mem=$(format_gb 6 "$scale" 1)
    sql3_mem=$(format_gb 4 "$scale" 1)

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
    read -r -p "  Enter choice (1-4): " choice
    case "$choice" in
        1) SKIP_PG=false; SKIP_SQL=false ;;
        2) SKIP_PG=false; SKIP_SQL=true ;;
        3) SKIP_PG=true;  SKIP_SQL=false ;;
        4) info "  Exiting."; exit 0 ;;
        *) warn "  [!] Invalid choice. Please enter 1-4.\n"; prompt_engine_choice ;;
    esac
}

# ── PID helpers ─────────────────────────────────────────────────
PID_FILE="$WEB_DIR/app.pid"
start_web_app() {
    info "  Installing Python dependencies..."
    python3 -m pip install -r "$WEB_DIR/requirements.txt" -q 2>/dev/null || true

    local log_file="$WEB_DIR/app.log"
    export FLASK_APP=app.py
    export FLASK_DEBUG=0

    cd "$WEB_DIR"
    nohup python3 -m flask run --host=0.0.0.0 --port=5002 > "$log_file" 2>&1 &
    echo $! > "$PID_FILE"
    sleep 2
    ok "Web app starting on http://localhost:5002 (PID: $(cat "$PID_FILE"), logs: $log_file)"
    cd "$ROOT_DIR"
}

stop_web_app() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null || true
        rm -f "$PID_FILE"
        ok "Web app stopped"
    else
        warn "Web app PID file not found"
    fi
}

show_status() {
    info "=== Status ==="
    info "  PostgreSQL HA:"
    cd "$PG_DIR" && docker compose ps 2>/dev/null | tail -n +3 || echo "    (not running)"
    info "  SQL Server HA:"
    cd "$SQL_DIR" && docker compose ps 2>/dev/null | tail -n +3 || echo "    (not running)"
    if [[ -f "$PID_FILE" ]]; then
        ok "Web App: running (PID: $(cat "$PID_FILE"))"
    else
        warn "Web App: not running"
    fi
}

stop_all() {
    info "=== Stopping All Servers ==="
    info "  Stopping PostgreSQL HA..."
    cd "$PG_DIR" && docker compose down 2>/dev/null || true
    info "  Stopping SQL Server HA..."
    cd "$SQL_DIR" && docker compose down 2>/dev/null || true
    stop_web_app
    remove_overrides
    ok "All servers stopped"
}

# ── ODBC ─────────────────────────────────────────────────────────
ensure_odbc() {
    local drivers
    drivers=$(python3 -c "import pyodbc; print([d for d in pyodbc.drivers() if 'SQL Server' in d or 'FreeTDS' in d])" 2>/dev/null || echo "[]")
    if echo "$drivers" | grep -qi "SQL Server\|FreeTDS"; then
        ok "ODBC driver found: $drivers"
        return 0
    fi

    warn "SQL Server ODBC driver not found, attempting auto-install..."

    # --- Linux ---
    if [[ "$(uname -s)" == "Linux" ]]; then
        if command -v curl &>/dev/null; then
            if ! curl -sL "https://packages.microsoft.com/keys/microsoft.asc" | sudo apt-key add - 2>/dev/null; then
                curl -sL "https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc >/dev/null 2>&1
            fi
            local os_version
            os_version=$(lsb_release -rs 2>/dev/null || echo "20.04")
            if grep -qi "alpine" /etc/os-release 2>/dev/null; then
                sudo apk add --no-cache msodbcsql18 unixodbc-dev 2>/dev/null || true
            elif command -v apt-get &>/dev/null; then
                local release_codename
                release_codename=$(lsb_release -cs 2>/dev/null || echo "focal")
                sudo bash -c "curl -sL https://packages.microsoft.com/config/ubuntu/${os_version}/prod.list > /etc/apt/sources.list.d/mssql-release.list"
                sudo apt-get update -qq && sudo ACCEPT_EULA=Y apt-get install -y -qq msodbcsql18 2>/dev/null || true
            elif command -v yum &>/dev/null || command -v dnf &>/dev/null; then
                local pkg_manager
                pkg_manager=$(command -v dnf || command -v yum)
                sudo bash -c "curl -sL https://packages.microsoft.com/config/rhel/9/prod.repo > /etc/yum.repos.d/mssql-release.repo"
                sudo $pkg_manager install -y -q msodbcsql18 2>/dev/null || sudo ACCEPT_EULA=Y $pkg_manager install -y -q msodbcsql18 2>/dev/null || true
            fi
        fi
    fi

    # --- macOS ---
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
            brew install --cask msodbcsql18 2>/dev/null || brew install unixodbc 2>/dev/null || true
        fi
    fi

    drivers=$(python3 -c "import pyodbc; print([d for d in pyodbc.drivers() if 'SQL Server' in d or 'FreeTDS' in d])" 2>/dev/null || echo "[]")
    if echo "$drivers" | grep -qi "SQL Server\|FreeTDS"; then
        ok "ODBC driver installed: $drivers"
        return 0
    fi

    err "Could not install SQL Server ODBC driver."
    err "See: https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server"
    return 1
}

# ── Main ─────────────────────────────────────────────────────────
cd "$ROOT_DIR"

$STATUS && { show_status; exit 0; }
$STOP  && { stop_all;   exit 0; }

# ── Engine Selection ─────────────────────────────────────────────
if ! $SKIP_PG && ! $SKIP_SQL; then
    # No skip flags = interactive mode
    prompt_engine_choice
fi

# ── Resource Detection & Override Generation ─────────────────────
info "=== Resource Detection ==="
TOTAL_RAM=$(get_total_ram_gb)
SCALE=$(compute_scale "$TOTAL_RAM")
show_resource_plan "$TOTAL_RAM" "$SCALE"

generate_overrides "$SCALE"
echo ""

# ensure Docker
if ! docker info &>/dev/null; then
    err "Docker is not running."
fi

# ODBC (unless skipping SQL Server)
if ! $SKIP_SQL; then
    ensure_odbc
    echo ""
fi

# 1. PostgreSQL
if ! $SKIP_PG; then
    info "[1/3] Starting PostgreSQL HA Cluster (Patroni)..."
    cd "$PG_DIR" && docker compose up -d && cd "$ROOT_DIR"
    ok "PostgreSQL HA cluster started"
    echo ""
fi

# 2. SQL Server
if ! $SKIP_SQL; then
    info "[2/3] Starting SQL Server HA Cluster..."
    cd "$SQL_DIR" && docker compose up -d && cd "$ROOT_DIR"
    ok "SQL Server HA cluster started"
    echo ""
fi

# wait
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
        info "  Press Ctrl+C to stop the web app (containers keep running)."
        echo "---"
        cd "$WEB_DIR"
        FLASK_APP=app.py FLASK_DEBUG=0 python3 -m flask run --host=0.0.0.0 --port=5002
        cd "$ROOT_DIR"
        echo ""
        info "Web app stopped."
        info "Containers are still running. To stop them:"
        info "  ./stop_servers.sh"
    fi
fi
