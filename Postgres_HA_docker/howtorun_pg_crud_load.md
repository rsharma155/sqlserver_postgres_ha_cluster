# How to Run `pg_crud_load.py`

PostgreSQL CRUD load generator for the Patroni HA cluster (5 databases across 3 Patroni nodes behind HAProxy).

## 1. Install Dependencies

```bash
cd docker
pip install psycopg2-binary
```

## 2. Ensure the Cluster is Running

```bash
docker-compose ps
```

All services (`patroni1`, `patroni2`, `patroni3`, `haproxy`, `etcd`) should be `Up`.

## 3. Run the Script

Basic usage — 30 seconds, 4 threads, 3 app names:

```bash
cd docker
python pg_crud_load.py -s 30 -t 4 -n 3
```

### All Options

| Flag | Default | Description |
|------|---------|-------------|
| `-s`, `--seconds` | 30 | How long to run (seconds) |
| `-t`, `--threads` | 2 | Number of concurrent worker threads |
| `-n`, `--app-names` | 3 | Unique `application_name` values sent to PostgreSQL |
| `--host` | `localhost` | Database host (HAProxy or direct Patroni) |
| `--port` | `5000` | Database port (5000 = HAProxy write, 5001 = read) |
| `--user` | `postgres` | Database user |
| `--password` | `postgres123` | Database password |

### Examples

```bash
# Quick smoke test (5 seconds, 2 threads, 2 app names)
python pg_crud_load.py -s 5 -t 2 -n 2

# 5-minute stress test (300s, 8 threads, 10 app names)
python pg_crud_load.py -s 300 -t 8 -n 10

# Against read-only HAProxy port
python pg_crud_load.py -s 60 -t 4 -n 3 --port 5001
```

> **Note:** The script also auto-installs `psycopg2-binary` if missing, so `pip install` is optional.

## 4. Stopping

Press `Ctrl+C` at any time. The script will:
1. Set a stop flag that all worker threads check before their next iteration
2. Wait for running threads to finish their current query
3. Print a summary table with per-operation success/failure counts and throughput

Press `Ctrl+C` twice to force-kill.

## 5. Understanding the Output

```
====================================================================
  CRUD LOAD TEST SUMMARY
====================================================================
  department_store  D  |  Attempted:   1050  |  Succeeded:   1050  |  Failed:    0  |  Success Rate: 100.0%
  department_store  R  |  Attempted:   3150  |  Succeeded:   3150  |  Failed:    0  |  Success Rate: 100.0%
  ...
====================================================================
  TOTAL                    |  Attempted:  21000  |  Succeeded:  21000  |  Failed:    0  |  Success Rate: 100.0%
  Duration: 30.0s          |  Throughput: 700.0 ops/sec
====================================================================
```

- **C/R/U/D** — Create, Read, Update, Delete operations
- Failures are usually FK constraint violations or connectivity blips (expected during failover tests)

## 6. What CRUD Operations Run Per Database

| Database | Create (into) | Read (from) | Update (on) | Delete (from) |
|----------|--------------|-------------|-------------|---------------|
| `hotel_booking` | `housekeeping_tasks` | `guests` | `housekeeping_tasks` | `housekeeping_tasks` |
| `e_commerce` | `product_reviews` | `products` | `product_reviews` | `product_reviews` |
| `erp_system` | `timesheets` | `employees` | `timesheets` | `timesheets` |
| `hrm_tool` | `training_enrollments` | `employees_hrm` | `training_enrollments` | `training_enrollments` |
| `department_store` | `inventory_movements` | `products_store` | `inventory_movements` | `inventory_movements` |

All FK ranges match the seed data from `init_databases.sql`.

## 7. Verifying Activity in PostgreSQL

While the load test runs, check from another terminal:

```bash
# See active connections and their application names
docker exec patroni1 psql -U postgres -c "
  SELECT application_name, count(*), state
  FROM pg_stat_activity
  WHERE application_name LIKE 'crud-loader-%'
  GROUP BY application_name, state;
"

# See query throughput
docker exec patroni1 psql -U postgres -c "
  SELECT datname, xact_commit + xact_rollback AS xacts
  FROM pg_stat_database
  WHERE datname IN ('hotel_booking','e_commerce','erp_system','hrm_tool','department_store');
"
```
