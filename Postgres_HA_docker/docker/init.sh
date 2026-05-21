#!/bin/bash
set -e

PROGRESS_FILE=/tmp/init_progress.log

log() {
    echo "$(date '+%H:%M:%S') $*" | tee -a "$PROGRESS_FILE"
}

log "============================================"
log "  Initializing databases and sample data..."
log "============================================"

# Create databases if they don't exist
for db in hotel_booking e_commerce erp_system hrm_tool department_store; do
    if psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='$db'" | grep -q 1; then
        log "Database '$db' already exists, skipping."
    else
        log "Creating database '$db'..."
        psql -U postgres -c "CREATE DATABASE $db" 2>&1 | tee -a "$PROGRESS_FILE"
        log "Created database '$db'."
    fi
done

# Check if already initialized by looking for tables in one of the app databases
DB_COUNT=$(psql -U postgres -d hotel_booking -t -A -c "SELECT COUNT(*) FROM pg_tables WHERE schemaname='public'" 2>/dev/null || echo "0")
if [ "$DB_COUNT" -gt 0 ]; then
    log "Tables already exist in hotel_booking ($DB_COUNT found). Skipping table creation and data inserts."
else
    log "No tables found. Running full initialization (this may take 5-15 minutes)..."
    log "Progress: /tmp/init_progress.log"
    log ""
    log "--- Starting SQL initialization ---" | tee -a "$PROGRESS_FILE"
    psql -U postgres -f /scripts/init_databases.sql 2>&1 | tee -a "$PROGRESS_FILE"
    log "--- SQL initialization finished ---"
    log ""
    log "Initialization complete."
fi

log "Creating monitoring user and permissions..."
psql -U postgres -f /scripts/pgsql_init.sql 2>&1 | tee -a "$PROGRESS_FILE"
log "Monitoring user created."

log "============================================"
log "  Database initialization finished"
log "============================================"
