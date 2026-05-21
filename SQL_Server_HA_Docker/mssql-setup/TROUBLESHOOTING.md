# Troubleshooting Guide

## Endpoint Connection Issues

**Symptom:** Replicas cannot connect to each other; AG create/join fails with endpoint connection errors.

**Checks:**
```bash
# Verify endpoints exist and are started
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "<password>" -Q "
SELECT name, state_desc, port, type_desc FROM sys.database_mirroring_endpoints;
"

# Test TCP connectivity between nodes (from inside a container)
docker exec sql1 /opt/mssql-tools/bin/bash -c "cat < /dev/tcp/172.25.0.12/5022 && echo 'OK' || echo 'FAIL'"

# Check Docker network connectivity
docker exec sql1 ping sql2
docker exec sql1 ping sql3
```

**Fixes:**
- Ensure endpoint is `STATE = STARTED` (not `STOPPED`)
- Verify firewall is not blocking port 5022 (Docker bridge network is usually open)
- Confirm all containers are on the same `sql-ha-net` network
- Verify static IPs match the endpoint URLs in the AG definition

## Certificate Errors

**Symptom:** AG creation or replica join fails with certificate-related errors (error 15151, 15404, 15517).

**Checks:**
```bash
# List certificates on each node
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "<password>" -Q "SELECT name, subject FROM sys.certificates;"

# Check shared certificate files exist
docker exec sql1 ls -la /certs/
```

**Fixes:**
- Verify all certificates exist in `/certs/` shared volume
- Re-run certificate creation if missing
- Ensure CRITICAL: passwords match between init-sql scripts and the actual files
- Verify the certificate backup includes the private key (`.pvk` file must exist)
- Rebuild containers with `docker compose down -v && docker compose up -d` to force clean state
- Check that `GRANT AUTHENTICATE ENDPOINT` was executed for each remote login

## AG Join Failures

**Symptom:** Secondary replicas cannot join the availability group.

**Checks:**
```bash
# Check AG state on primary
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "<password>" -Q "
SELECT name, replica_server_name, join_state_desc, role_desc
FROM sys.dm_hadr_availability_replica_states;
"

# Check for AG-related errors in SQL Server log
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "<password>" -Q "
SELECT log_date, text FROM sys.fn_get_audit_file(NULL, NULL, DEFAULT) WHERE text LIKE '%AG%' OR text LIKE '%HADR%';
"
```

**Fixes:**
- Ensure primary already has `CREATE AVAILABILITY GROUP` executed before joining
- Verify endpoint URLs use correct IPs (172.25.0.x) or hostnames
- Check that SQL Server Agent is running (required for automatic seeding)
- Restart secondary SQL Server and retry join
- On persistent failure, run join manually:
  ```sql
  ALTER AVAILABILITY GROUP [AG_HA_LAB] JOIN;
  ALTER AVAILABILITY GROUP [AG_HA_LAB] GRANT CREATE ANY DATABASE;
  ```

## Seeding Failures

**Symptom:** Database shows `NOT_HEALTHY` or `SEEDING_FAILED` on secondary replicas.

**Checks:**
```bash
# Check database synchronization state
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "<password>" -Q "
SELECT db.name, rs.synchronization_state_desc, rs.synchronization_health_desc
FROM sys.dm_hadr_database_replica_states rs
JOIN sys.databases db ON rs.database_id = db.database_id
WHERE db.name = 'HADemoDB';
"
```

**Fixes:**
- Ensure the database is in `FULL` recovery model:
  ```sql
  ALTER DATABASE HADemoDB SET RECOVERY FULL;
  ```
- Take a full backup on the primary:
  ```sql
  BACKUP DATABASE HADemoDB TO DISK = '/var/opt/mssql/backup/HADemoDB.bak';
  ```
- Ensure disk space is available for automatic seeding
- Check SQL Server error log for seeding errors:
  ```bash
  docker exec sql2 cat /var/opt/mssql/log/errorlog | grep -i seed
  ```
- If automatic seeding fails, try manual backup/restore:
  ```sql
  -- On primary:
  BACKUP DATABASE HADemoDB TO DISK = '/var/opt/mssql/backup/HADemoDB_full.bak' WITH FORMAT;
  BACKUP LOG HADemoDB TO DISK = '/var/opt/mssql/backup/HADemoDB_log.bak';

  -- On secondary, then join:
  RESTORE DATABASE HADemoDB FROM DISK = '/var/opt/mssql/backup/HADemoDB_full.bak' WITH NORECOVERY;
  RESTORE LOG HADemoDB FROM DISK = '/var/opt/mssql/backup/HADemoDB_log.bak' WITH NORECOVERY;
  ALTER DATABASE HADemoDB SET HADR AVAILABILITY GROUP = AG_HA_LAB;
  ```

## Failover Validation Issues

**Symptom:** Failover fails or data is inconsistent after failover.

**Checks:**
```bash
# Check replica roles after failover attempt
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "<password>" -Q "
SELECT replica_server_name, role_desc, connected_state_desc, synchronization_health_desc
FROM sys.dm_hadr_availability_replica_states;
"
```

**Fixes:**
- Synchronous replicas must be synchronized for automatic failover:
  ```sql
  SELECT synchronization_state_desc FROM sys.dm_hadr_database_replica_states;
  -- Should show 'SYNCHRONIZED' for automatic failover targets
  ```
- For manual failover, secondary can fail over if synchronized regardless of commit type
- After unplanned failover, rejoin old primary as a secondary:
  ```sql
  ALTER AVAILABILITY GROUP [AG_HA_LAB] SET (ROLE = SECONDARY);
  -- Then wait for it to sync and rejoin
  ```
- If failover command fails, ensure target replica is in `SECONDARY` role and synchronized

## Container Startup Issues

**Symptom:** Containers keep restarting or never become healthy.

**Checks:**
```bash
# View container logs
docker compose logs sql1

# Check bootstrap log inside container
docker exec sql1 cat /var/opt/mssql/log/ha-bootstrap.log

# Verify SQL Server started
docker exec sql1 ps aux | grep sqlservr
```

**Fixes:**
- Ensure Docker has sufficient memory (16 GB+)
- Check port conflicts (14331, 14332, 14333):
  ```bash
  netstat -ano | findstr "14331"
  ```
- Verify .env file exists in project root with all required variables
- If containers restart repeatedly, run `docker compose down -v && docker compose up -d` for clean state
- On Windows, ensure Docker Desktop is running with Linux containers

## General Reset

To completely reset the lab environment:

```bash
docker compose down -v
docker compose up -d
docker compose logs -f sql1
```

Wait for bootstrap to complete (~5 minutes), then verify AG state.
