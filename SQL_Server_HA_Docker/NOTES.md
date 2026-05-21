Build a production-like Phase 1 SQL Server HA lab using Docker Compose for local experimentation.

## Objective

Create a 3-node SQL Server 2022 Always On Availability Group lab running in Linux containers.

Topology:

* sql1 (Primary)
* sql2 (Synchronous Secondary)
* sql3 (Asynchronous Secondary)

The environment must support:

* Availability Group creation
* Manual failover
* Automatic seeding
* Read-only secondary testing
* Backup/restore validation
* Network interruption simulation
* Persistent data volumes
* Controlled SQL memory allocation

---

## Infrastructure Requirements

### Docker network

Create custom bridge network:

Name:
sql-ha-net

Subnet:
172.25.0.0/24

Static IPs:

sql1 → 172.25.0.11
sql2 → 172.25.0.12
sql3 → 172.25.0.13

---

## SQL Server Version

Use latest SQL Server 2022 Linux container image:

mcr.microsoft.com/mssql/server:2022-latest

Enable:

* SQL Agent
* HADR
* TCP/IP
* Always On endpoint communication

---

## Persistent Volumes

Create dedicated named volumes:

sql1-data
sql1-log
sql1-backup

sql2-data
sql2-log
sql2-backup

sql3-data
sql3-log
sql3-backup

---

## Container Resource Limits

sql1:

* cpus: 2
* memory: 6g

sql2:

* cpus: 2
* memory: 6g

sql3:

* cpus: 2
* memory: 4g

---

## Environment Variables

Set:

ACCEPT_EULA=Y
MSSQL_PID=Developer
MSSQL_SA_PASSWORD=<StrongPassword>

---

## SQL Memory Configuration

After startup execute:

### sql1

min server memory: 2048 MB
max server memory: 4096 MB

### sql2

min server memory: 1024 MB
max server memory: 3072 MB

### sql3

min server memory: 1024 MB
max server memory: 2048 MB

---

## File Layout

Generate:

docker-compose.yml

/bootstrap
init-sql1.sql
init-sql2.sql
init-sql3.sql
configure-hadr.sql
create-certificates.sql
create-endpoints.sql
create-ag.sql
join-replicas.sql

/scripts
wait-for-sql.sh
bootstrap.sh
failover-test.sh
healthcheck.sh

---

## Initialization Requirements

Each SQL instance must:

1. Enable HADR
2. Create database mirroring endpoint
3. Generate certificates
4. Exchange endpoint certificates
5. Configure endpoint permissions
6. Create sample database:
   HADemoDB
7. Seed sample data
8. Configure AG

---

## Availability Group

Name:
AG_HA_LAB

Replica configuration:

sql1:
PRIMARY
SYNCHRONOUS_COMMIT
AUTOMATIC_FAILOVER

sql2:
SECONDARY
SYNCHRONOUS_COMMIT
AUTOMATIC_FAILOVER

sql3:
SECONDARY
ASYNCHRONOUS_COMMIT
MANUAL_FAILOVER

---

## Health Checks

Docker health checks should validate:

SELECT @@SERVERNAME

and AG DMV state:

sys.dm_hadr_availability_replica_states

---

## Failover Testing Script

Create automated script that:

1. Inserts test row
2. Stops sql1
3. Validates failover to sql2
4. Verifies row consistency
5. Restarts sql1
6. Rejoins replica

---

## Logging

All bootstrap steps must write logs to:

/var/opt/mssql/log/ha-bootstrap.log

---

## Deliverables

Generate:

1. Complete docker-compose.yml
2. All SQL bootstrap scripts
3. Shell automation scripts
4. README with startup steps
5. Troubleshooting guide for:

   * endpoint connection issues
   * certificate errors
   * AG join failures
   * seeding failures
   * failover validation issues

Implementation should prioritize reliability and reproducibility over advanced clustering features.
