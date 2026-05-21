# SQL Server 2022 Always On Availability Group Docker Lab

## Overview

Phase 1 lab environment with 3-node SQL Server 2022 Always On Availability Group running in Linux containers:

| Node | Role | Commit Type | Failover | IP | Memory |
|------|------|-------------|----------|----|--------|
| sql1 | Primary | Synchronous | Automatic | 172.25.0.11 | 6g (max 4096 MB SQL) |
| sql2 | Secondary | Synchronous | Automatic | 172.25.0.12 | 6g (max 3072 MB SQL) |
| sql3 | Secondary | Asynchronous | Manual | 172.25.0.13 | 4g (max 2048 MB SQL) |

## Prerequisites

- Docker Desktop (Windows) or Docker Engine (Linux) with Compose V2
- Minimum 16 GB RAM allocated to Docker
- At least 15 GB free disk space

## Quick Start

```bash
# Clone / navigate to project directory
cd sql-server-ha-docker

# Start all three SQL Server nodes
docker compose up -d

# Monitor bootstrap progress
docker compose logs -f

# Check health status
docker compose ps
```

Bootstrap takes 4-6 minutes and runs these phases on each node:

| Phase | Description |
|-------|-------------|
| 1-2 | HADR enablement, SQL Server start |
| 3 | Node init (certificates, endpoints) |
| 4 | Create 5 demo databases & seed data |
| 5 | Enable SQL Server Agent |
| 6 | Configure backup directory |
| 7 | Set up transactional replication (sql1 only) |
| 8 | Create `dbmonitor_user` & enable deadlock XE |
| 9 | Configure log shipping `hrm_tool` → sql2 (sql1 only) |

## Connecting to SQL Server

Use any SQL client (Azure Data Studio, SSMS, sqlcmd):

| Node | Host Port | Connection String |
|------|-----------|-------------------|
| sql1 | 14331 | `localhost,14331` |
| sql2 | 14332 | `localhost,14332` |
| sql3 | 14333 | `localhost,14333` |

**Credentials:** `sa` / `S@L_2024_HADr_D0ck3r!`

## Verification

```bash
# Check AG state on primary
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT replica_server_name, role_desc, availability_mode_desc, failover_mode_desc
FROM sys.dm_hadr_availability_replica_states rs
JOIN sys.availability_replicas r ON rs.replica_id = r.replica_id;
"

# Check joined replicas
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT name, replica_server_name, join_state_desc
FROM sys.dm_hadr_availability_replica_states;
"

# Check database on AG
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT name, database_id, synchronization_state_desc
FROM sys.dm_hadr_database_replica_states;
"
```

## Failover Testing

### Manual failover (sql1 -> sql2)

```bash
# On sql1, set to secondary
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
ALTER AVAILABILITY GROUP [AG_HA_LAB] SET (ROLE = SECONDARY);
"

# On sql2, fail over
docker exec sql2 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
ALTER AVAILABILITY GROUP [AG_HA_LAB] FAILOVER;
"

# Verify sql2 is now primary
docker exec sql2 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT role_desc FROM sys.dm_hadr_availability_replica_states
WHERE replica_id = (SELECT group_id FROM sys.availability_groups WHERE name = 'AG_HA_LAB');
"
```

### Fail back (sql2 -> sql1)

```bash
docker exec sql2 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
ALTER AVAILABILITY GROUP [AG_HA_LAB] SET (ROLE = SECONDARY);
"
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
ALTER AVAILABILITY GROUP [AG_HA_LAB] FAILOVER;
"
```

### Automated failover test

```bash
docker exec sql1 /bin/bash /scripts/failover-test.sh
docker exec sql1 cat /var/opt/mssql/log/failover-test.log
```

## Read-Only Secondary Testing

```bash
# Query secondary replica (sql2 or sql3)
docker exec sql2 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -d HADemoDB -Q "
SELECT TOP 5 * FROM HA_Test;
"
```

## Network Interruption Simulation

```bash
# Simulate network partition on sql3
docker network disconnect sql-ha-net sql3

# Wait, then reconnect
sleep 30
docker network connect sql-ha-net sql3 --ip 172.25.0.13

# Check AG state
docker exec sql1 /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT replica_server_name, connected_state_desc, synchronization_health_desc
FROM sys.dm_hadr_availability_replica_states;
"
```

## Cleanup

```bash
# Stop and remove containers
docker compose down

# Remove volumes (data will be lost)
docker compose down -v
```

## File Structure

```
├── docker-compose.yml           # Docker Compose configuration
├── .env                         # Environment variables
├── README.md
├── New Text Document.md
└── mssql-setup/                 # All setup files
    ├── bootstrap/               # SQL init scripts
    │   ├── init-sql1.sql
    │   ├── init-sql2.sql
    │   ├── init-sql3.sql
    │   ├── configure-hadr.sql
    │   ├── create-certificates.sql
    │   ├── create-endpoints.sql
    │   ├── create-ag.sql
    │   ├── join-replicas.sql
    │   ├── init-databases.sql
    │   ├── create_users.sql
    │   ├── seed-data.sql
    │   ├── setup-replication.sql
    │   ├── setup-logshipping-primary.sql   # Log shipping primary config
    │   ├── setup-logshipping-secondary.sql # Log shipping secondary config
    ├── scripts/                 # Shell scripts
    │   ├── bootstrap.sh
    │   ├── wait-for-sql.sh
    │   ├── healthcheck.sh
    │   └── failover-test.sh
    ├── sqlserver_init.sql       # Monitoring user creation
    ├── sqlserver_deadlock_xe.sql# Deadlock extended events
    ├── init_databases.sql       # PostgreSQL version (reference)
    ├── TROUBLESHOOTING.md
    └── load_test_app/           # Load testing application
```

## Monitoring User

Phase 8 creates a dedicated `dbmonitor_user` login with minimal required permissions for monitoring:

- `VIEW SERVER STATE`, `VIEW ANY DEFINITION`, `VIEW ANY DATABASE`
- `ALTER ANY EVENT SESSION` (for managing deadlock/blocking XE sessions)
- SQL Agent & backup metadata access (`msdb`)
- Replication metadata access (`distribution`, if present)
- Master database metadata access

Extended Events session `sqloptima_deadlocks` is created to capture deadlock reports and starts automatically.

**Credentials:** `dbmonitor_user` / `Hello@123` (configured via `DBMONITOR_PASSWORD` in `.env`).

## Log Shipping (hrm_tool: sql1 → sql2)

Phase 9 configures log shipping for the `hrm_tool` database from sql1 (primary) to sql2 (secondary):

- **Primary (sql1):** Sets `FULL` recovery, takes full + log backups, creates `LSBackup_hrm_tool` job
- **Secondary (sql2):** Restores with `NORECOVERY`, creates `LSCopy_hrm_tool` and `LSRestore_hrm_tool` jobs
- Backups stored in the shared volume (`F:\sql_server\backups`) accessible by both nodes

### Verify Log Shipping

```bash
# Check primary status
docker exec sql1 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT primary_database, backup_directory, backup_job_id, last_backup_file
FROM msdb.dbo.log_shipping_primary_databases;
"

# Check secondary status
docker exec sql1 /opt/mssql-tools18/bin/sqlcmd -S sql2 -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT secondary_database, primary_server, restore_mode_desc = CASE restore_mode WHEN 0 THEN 'NORECOVERY' ELSE 'STANDBY' END, last_restored_file
FROM msdb.dbo.log_shipping_secondary_databases;
"

# Check hrm_tool state on secondary (should show RESTORING)
docker exec sql2 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT name, state_desc FROM sys.databases WHERE name = 'hrm_tool';
"

# List log shipping jobs
docker exec sql1 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "S@L_2024_HADr_D0ck3r!" -Q "
SELECT name, enabled FROM msdb.dbo.sysjobs WHERE name LIKE '%hrm_tool%';
"
```

## Architecture Notes

- Uses SQL Server 2022 with `CLUSTER_TYPE = NONE` (no Windows Server Failover Cluster required)
- Certificate-based endpoint authentication with shared certs volume
- Automatic seeding for database replication
- All bootstrap steps logged to `/var/opt/mssql/log/ha-bootstrap.log`
- Persistent named volumes for data, logs, and backups per node
