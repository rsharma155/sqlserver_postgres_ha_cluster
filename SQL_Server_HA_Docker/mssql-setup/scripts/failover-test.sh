#!/bin/bash
set -e

LOG_FILE="/var/opt/mssql/log/failover-test.log"
SA_PASS="$MSSQL_SA_PASSWORD"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

run_sql() {
    local host=$1
    local query=$2
    /opt/mssql-tools/bin/sqlcmd -S "$host" -U sa -P "$SA_PASS" -Q "$query" -h -1 -W 2>/dev/null
}

log "=== Failover Test Starting ==="

# Step 1: Insert test row on primary
log "Step 1: Inserting test row on primary (sql1)..."
run_sql "sql1" "
    USE HADemoDB;
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'HA_Test')
        CREATE TABLE HA_Test (ID INT IDENTITY PRIMARY KEY, TestValue NVARCHAR(100), InsertedAt DATETIME2 DEFAULT GETDATE());
    INSERT INTO HA_Test (TestValue) VALUES ('Failover test $(date)');
    DECLARE @id INT = SCOPE_IDENTITY();
    SELECT 'Inserted row with ID: ' + CAST(@id AS NVARCHAR) AS Result;
"

# Step 2: Verify row replicated to sql2
log "Step 2: Verifying row on sql2..."
sleep 5
ROW_COUNT=$(run_sql "sql2" "SET NOCOUNT ON; USE HADemoDB; SELECT COUNT(*) FROM HA_Test;" | tr -d ' ')
log "sql2 row count: $ROW_COUNT"

# Step 3: Failover from sql1 to sql2
log "Step 3: Performing manual failover to sql2..."
run_sql "sql1" "
    ALTER AVAILABILITY GROUP [AG_HA_LAB] SET (ROLE = SECONDARY);
"
run_sql "sql2" "
    ALTER AVAILABILITY GROUP [AG_HA_LAB] FAILOVER;
"
log "Failover initiated. Waiting 15 seconds..."
sleep 15

# Step 4: Verify sql2 is now primary
log "Step 4: Verifying sql2 is primary..."
ROLE=$(run_sql "sql2" "
    SET NOCOUNT ON;
    SELECT role_desc FROM sys.dm_hadr_availability_replica_states
    WHERE replica_id = (SELECT group_id FROM sys.availability_groups WHERE name = 'AG_HA_LAB');
" | tr -d ' ')
log "sql2 role: $ROLE"

# Step 5: Verify data consistency on new primary
log "Step 5: Verifying data consistency..."
run_sql "sql2" "
    USE HADemoDB;
    SELECT 'Test data present, count=' + CAST(COUNT(*) AS NVARCHAR) AS Result FROM HA_Test;
"

# Step 6: Fail back to sql1
log "Step 6: Failing back to sql1..."
run_sql "sql2" "
    ALTER AVAILABILITY GROUP [AG_HA_LAB] SET (ROLE = SECONDARY);
"
run_sql "sql1" "
    ALTER AVAILABILITY GROUP [AG_HA_LAB] FAILOVER;
"
sleep 15

# Step 7: Final verification on sql1
log "Step 7: Final verification on sql1..."
ROLE=$(run_sql "sql1" "
    SET NOCOUNT ON;
    SELECT role_desc FROM sys.dm_hadr_availability_replica_states
    WHERE replica_id = (SELECT group_id FROM sys.availability_groups WHERE name = 'AG_HA_LAB');
" | tr -d ' ')
log "sql1 role after failback: $ROLE"
run_sql "sql1" "
    USE HADemoDB;
    SELECT 'Final count=' + CAST(COUNT(*) AS NVARCHAR) AS Result FROM HA_Test;
"

log "=== Failover Test Complete ==="
