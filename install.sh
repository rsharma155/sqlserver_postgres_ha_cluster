#!/usr/bin/env bash
# One-line bootstrap for the DB HA Cluster CRUD Load Generator.
#
#   curl -fsSL https://raw.githubusercontent.com/rsharma155/sqlserver_postgres_ha_cluster/main/install.sh | bash
#
# Extra launcher flags are forwarded to start_servers.sh:
#
#   curl -fsSL .../install.sh | bash -s -- --skip-sql-server
#
# Environment:
#   HA_CLUSTER_HOME  Install directory (default: ~/sqlserver_postgres_ha_cluster)
#   HA_CLUSTER_REF   Git branch / tag / commit (default: main)
#   HA_CLUSTER_REPO  Git clone URL
set -euo pipefail

REPO_URL="${HA_CLUSTER_REPO:-https://github.com/rsharma155/sqlserver_postgres_ha_cluster.git}"
REPO_REF="${HA_CLUSTER_REF:-main}"
INSTALL_DIR="${HA_CLUSTER_HOME:-$HOME/sqlserver_postgres_ha_cluster}"
RAW_BASE="https://raw.githubusercontent.com/rsharma155/sqlserver_postgres_ha_cluster/${REPO_REF}"
ARCHIVE_URL="https://github.com/rsharma155/sqlserver_postgres_ha_cluster/archive/${REPO_REF}.tar.gz"

info()  { printf "\033[36m%s\033[0m\n" "$*"; }
ok()    { printf "\033[32m[+] %s\033[0m\n" "$*"; }
warn()  { printf "\033[33m[~] %s\033[0m\n" "$*"; }
err()   { printf "\033[31m[!] %s\033[0m\n" "$*"; exit 1; }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "'$1' is required. Install it and re-run this command."
}

info "=== DB HA Cluster — one-line setup ==="
info "  Install dir: $INSTALL_DIR"
info "  Ref:         $REPO_REF"
echo ""

need_cmd curl
need_cmd tar

if ! command -v docker >/dev/null 2>&1; then
    err "Docker is required. Install Docker Desktop / Engine, then re-run."
fi
if ! docker info >/dev/null 2>&1; then
    err "Docker is installed but not running. Start Docker and re-run."
fi
if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
    err "Docker Compose v2 is required (docker compose)."
fi
ok "Prerequisites OK (curl, Docker)"

fetch_repo() {
    mkdir -p "$(dirname "$INSTALL_DIR")"
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        warn "Existing git checkout found — updating..."
        git -C "$INSTALL_DIR" fetch --depth 1 origin "$REPO_REF" 2>/dev/null || git -C "$INSTALL_DIR" fetch origin "$REPO_REF"
        git -C "$INSTALL_DIR" checkout "$REPO_REF" 2>/dev/null || git -C "$INSTALL_DIR" checkout -B "$REPO_REF"
        git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_REF" 2>/dev/null || true
        ok "Updated $INSTALL_DIR"
        return
    fi
    if [[ -f "$INSTALL_DIR/start_servers.sh" ]]; then
        warn "Directory already exists with launcher scripts — skipping download."
        return
    fi
    if [[ -e "$INSTALL_DIR" ]] && [[ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null || true)" ]]; then
        err "Directory exists and is not this project: $INSTALL_DIR (set HA_CLUSTER_HOME to another path)"
    fi

    if command -v git >/dev/null 2>&1; then
        info "Cloning $REPO_URL ..."
        git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$INSTALL_DIR" \
            || git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
        ok "Cloned into $INSTALL_DIR"
        return
    fi

    warn "git not found — downloading source archive..."
    tmpdir=$(mktemp -d)
    curl -fsSL "$ARCHIVE_URL" -o "$tmpdir/src.tar.gz" || err "Failed to download $ARCHIVE_URL"
    tar -xzf "$tmpdir/src.tar.gz" -C "$tmpdir"
    extracted=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    mkdir -p "$INSTALL_DIR"
    # portable copy (busybox-friendly)
    cp -R "$extracted"/. "$INSTALL_DIR/"
    rm -rf "$tmpdir"
    ok "Extracted into $INSTALL_DIR"
}

fetch_repo

if [[ ! -f "$INSTALL_DIR/start_servers.sh" ]]; then
    err "Launcher missing after download: $INSTALL_DIR/start_servers.sh"
fi

chmod +x "$INSTALL_DIR/start_servers.sh" "$INSTALL_DIR/stop_servers.sh" 2>/dev/null || true

info ""
info "Launching clusters (this may take a few minutes on first run)..."
info "Web UI will be at http://localhost:5002"
echo ""

# curl | bash occupies stdin; attach the real terminal so the engine menu works.
if [[ -e /dev/tty ]]; then
    exec bash "$INSTALL_DIR/start_servers.sh" "$@" </dev/tty
fi
exec bash "$INSTALL_DIR/start_servers.sh" "$@"
