#!/bin/bash
set -e

MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -Q "SELECT 1" -b > /dev/null 2>&1; then
        exit 0
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

echo "ERROR: SQL Server did not become ready within $((MAX_ATTEMPTS * 2)) seconds."
exit 1
