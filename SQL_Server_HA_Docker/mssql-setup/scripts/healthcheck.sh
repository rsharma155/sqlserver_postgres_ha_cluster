#!/bin/bash

STATUS=$(/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
    -Q "SET NOCOUNT ON; SELECT @@SERVERNAME;" -h -1 -W 2>/dev/null | tr -d ' ')

if [ -z "$STATUS" ]; then
    exit 1
fi

# Check AG replica state (non-critical - just informational)
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C \
    -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.dm_hadr_availability_replica_states WHERE is_local = 1 AND connected_state = 1;" \
    -h -1 -W 2>/dev/null

exit 0
