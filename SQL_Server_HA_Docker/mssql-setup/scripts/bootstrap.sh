#!/bin/bash
set -e

LOG_FILE="/var/opt/mssql/log/ha-bootstrap.log"
STATE_DIR="/var/opt/mssql/bootstrap"
BOOTSTRAP_MARKER="$STATE_DIR/bootstrap_complete"

mkdir -p "$STATE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== SQL Server HA Bootstrap starting (Node: sql$NODE_ID) ==="

# Set the SA password from environment variable
log "Configuring SA password..."
/opt/mssql/bin/mssql-conf -n set-sa-password 2>/dev/null || true

# Enable HADR
log "Enabling HADR..."
if [ -f /var/opt/mssql/mssql.conf ]; then
    echo "" >> /var/opt/mssql/mssql.conf
fi
echo "[hadr]" >> /var/opt/mssql/mssql.conf
echo "hadrenabled = true" >> /var/opt/mssql/mssql.conf
log "mssql.conf content:"
cat /var/opt/mssql/mssql.conf | tee -a "$LOG_FILE"

# ============================================================
# Start SQL Server
# ============================================================
log "Starting SQL Server..."
/opt/mssql/bin/sqlservr &
SQL_PID=$!

/scripts/wait-for-sql.sh
log "SQL Server is ready (PID: $SQL_PID)."

# ============================================================
# Phase 3: Node initialization (certs, endpoints, database)
# ============================================================
if [ ! -f "$BOOTSTRAP_MARKER" ]; then
    log "Phase 3: Running node-specific initialization for sql$NODE_ID..."

    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -v MASTER_KEY_PASSWORD="$MASTER_KEY_PASSWORD" \
        -v CERT_PASSWORD="$CERT_PASSWORD" \
        -i "/bootstrap/init-sql${NODE_ID}.sql" || true

    log "Node sql$NODE_ID initialization complete."

    # ============================================================
    # Phase 4: Create databases and tables
    # ============================================================
    log "Phase 4: Creating databases and tables..."

    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -i "/bootstrap/init-databases.sql" || true

    log "Databases and tables created."

    # Create test users for load testing
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -i "/bootstrap/create_users.sql" || true
    log "Test users created."

    # ============================================================
    # Phase 5: Enable SQL Agent
    # ============================================================
    log "Phase 5: Enabling SQL Server Agent..."

    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -Q "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'Agent XPs', 1; RECONFIGURE;" || true

    /opt/mssql/bin/mssql-conf set sqlagent.enabled true || true

    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -Q "EXEC xp_servicecontrol N'START', N'SQLSERVERAGENT';" || true

    sleep 5

    log "SQL Server Agent enabled and started."

    # ============================================================
    # Phase 6: Configure backup directory
    # ============================================================
    log "Phase 6: Configuring backup directory..."

    if [ -d "/var/opt/mssql/external_backup" ]; then
        /opt/mssql/bin/mssql-conf set filelocation.defaultbackupdir /var/opt/mssql/external_backup || true
        log "Backup directory set to /var/opt/mssql/external_backup (F:\\sql_server\\backups on host)."
    else
        /opt/mssql/bin/mssql-conf set filelocation.defaultbackupdir /var/opt/mssql/backup || true
        log "Backup directory set to /var/opt/mssql/backup."
    fi

    # ============================================================
    # Phase 7: Setup replication (sql1 only)
    # ============================================================
    if [ "$NODE_ID" = "1" ]; then
        log "Phase 7: Setting up transactional replication (Publisher+Distributor)..."
        log "Waiting for subscribers (sql2, sql3) to be ready..."

        for i in $(seq 1 30); do
            if /opt/mssql-tools18/bin/sqlcmd -S sql2 -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" -b > /dev/null 2>&1 && \
               /opt/mssql-tools18/bin/sqlcmd -S sql3 -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" -b > /dev/null 2>&1; then
                log "All subscribers ready."
                break
            fi
            sleep 5
        done

        /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
            -i "/bootstrap/setup-replication.sql" || true

        log "Replication setup completed."

        # Add push subscriptions with retry
        log "Adding push subscriptions..."
        for i in $(seq 1 12); do
            /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "
                USE hotel_booking;
                EXEC sp_addsubscription @publication=N'pub_hotel_booking', @subscriber=N'sql2', @destination_db=N'hotel_booking', @subscription_type=N'push', @sync_type=N'automatic', @article=N'all', @update_mode=N'read only';
            " > /dev/null 2>&1 && \
            /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "
                USE e_commerce;
                EXEC sp_addsubscription @publication=N'pub_e_commerce', @subscriber=N'sql2', @destination_db=N'e_commerce', @subscription_type=N'push', @sync_type=N'automatic', @article=N'all', @update_mode=N'read only';
            " > /dev/null 2>&1 && \
            /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "
                USE erp_system;
                EXEC sp_addsubscription @publication=N'pub_erp_system', @subscriber=N'sql3', @destination_db=N'erp_system', @subscription_type=N'push', @sync_type=N'automatic', @article=N'all', @update_mode=N'read only';
            " > /dev/null 2>&1 && \
            log "Push subscriptions added successfully." && break
            sleep 10
        done
    fi

    if [ "$NODE_ID" = "2" ] || [ "$NODE_ID" = "3" ]; then
        log "Phase 7: Node sql$NODE_ID ready as replication subscriber."
    fi

    # ============================================================
    # Phase 8: Create monitoring user and enable extended events
    # ============================================================
    log "Phase 8: Setting up monitoring user and deadlock XE session..."

    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -v DBMONITOR_PASSWORD="$DBMONITOR_PASSWORD" \
        -i "/mssql-setup/sqlserver_init.sql" || true

    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -i "/mssql-setup/sqlserver_deadlock_xe.sql" || true

    log "Monitoring user and deadlock XE session setup complete."

    # ============================================================
    # Phase 9: Configure log shipping (hrm_tool: sql1 -> sql2)
    # ============================================================
    if [ "$NODE_ID" = "1" ]; then
        log "Phase 9: Configuring log shipping for hrm_tool (sql1 -> sql2)..."

        /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
            -i "/mssql-setup/bootstrap/setup-logshipping-primary.sql" || true

        log "Log shipping primary configured. Waiting for sql2 to be ready..."

        for i in $(seq 1 30); do
            if /opt/mssql-tools18/bin/sqlcmd -S sql2 -U sa -P "$MSSQL_SA_PASSWORD" -C \
                -Q "SELECT 1" -b > /dev/null 2>&1; then
                log "sql2 is ready."
                break
            fi
            sleep 5
        done

        /opt/mssql-tools18/bin/sqlcmd -S sql2 -U sa -P "$MSSQL_SA_PASSWORD" -C \
            -i "/mssql-setup/bootstrap/setup-logshipping-secondary.sql" || true

        log "Log shipping setup complete for hrm_tool (sql1 -> sql2)."
    else
        log "Phase 9: Skipping log shipping setup (primary only)."
    fi

    # Set memory limits based on container cgroup limit
    log "Configuring SQL Server memory limits..."
    CGROUP_MEM_KB=0
    if [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        CGROUP_MEM_KB=$(($(cat /sys/fs/cgroup/memory/memory.limit_in_bytes) / 1024))
    elif [ -f /sys/fs/cgroup/memory.max ]; then
        CGROUP_MEM_KB=$(($(cat /sys/fs/cgroup/memory.max) / 1024))
    fi

    if [ "$CGROUP_MEM_KB" -gt 0 ] 2>/dev/null; then
        MAX_MEM_MB=$(( CGROUP_MEM_KB / 1024 * 80 / 100 ))
    else
        # Fallback: detect via free
        TOTAL_KB=$(free -m | awk '/^Mem:/{print $2}')
        MAX_MEM_MB=$(( TOTAL_KB * 80 / 100 ))
    fi

    if [ "$MAX_MEM_MB" -gt 4096 ]; then
        MAX_MEM_MB=4096
    elif [ "$MAX_MEM_MB" -lt 512 ]; then
        MAX_MEM_MB=512
    fi
    MIN_MEM_MB=$(( MAX_MEM_MB / 2 ))

    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
        -Q "EXEC sp_configure 'min server memory (MB)', $MIN_MEM_MB; RECONFIGURE; EXEC sp_configure 'max server memory (MB)', $MAX_MEM_MB; RECONFIGURE;" || true

    log "Memory configured: min=${MIN_MEM_MB}MB, max=${MAX_MEM_MB}MB (container limit: ${CGROUP_MEM_KB}KB)"

    touch "$BOOTSTRAP_MARKER"
    log "=== Bootstrap complete for sql$NODE_ID ==="
fi

# Keep container alive
wait $SQL_PID
