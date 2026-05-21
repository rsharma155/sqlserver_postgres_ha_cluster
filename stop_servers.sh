#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PG_DIR="$ROOT_DIR/Postgres_HA_docker"
SQL_DIR="$ROOT_DIR/SQL_Server_HA_Docker"
WEB_DIR="$ROOT_DIR/web_app"
PID_FILE="$WEB_DIR/app.pid"

info()  { printf "\e[36m%s\e[0m\n" "$*"; }
ok()    { printf "\e[32m[+] %s\e[0m\n" "$*"; }

cd "$ROOT_DIR"

# Clean up generated docker compose override files
rm -f "$PG_DIR/docker-compose.override.yml"
rm -f "$SQL_DIR/docker-compose.override.yml"
ok "Override files cleaned up"

# Web App
if [[ -f "$PID_FILE" ]]; then
    pid=$(cat "$PID_FILE")
    info "  Stopping web app (PID: $pid)..."
    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    ok "Web app stopped"
else
    info "  Web app: not running"
fi

info "  Stopping PostgreSQL HA..."
cd "$PG_DIR" && docker compose down 2>/dev/null || true
ok "PostgreSQL HA stopped"

info "  Stopping SQL Server HA..."
cd "$SQL_DIR" && docker compose down 2>/dev/null || true
ok "SQL Server HA stopped"

echo ""
ok "All servers stopped."
