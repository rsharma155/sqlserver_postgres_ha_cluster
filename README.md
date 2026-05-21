# DB HA Cluster CRUD Load Generator

A cross-platform automation tool that starts two Docker-based HA database clusters (PostgreSQL Patroni and SQL Server Always On Availability Group) and provides a web UI to generate realistic CRUD traffic across all databases, plus scheduled backups.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│      start_all.ps1 (Windows) / start_servers.sh (Linux/macOS)│
│                (Self-contained launchers)                    │
└──────────────┬──────────────────────────────┬────────────────┘
               │                              │
     ┌─────────▼──────────┐        ┌──────────▼─────────┐
     │ PostgreSQL HA       │        │ SQL Server HA       │
     │ (Patroni + etcd +   │        │ (3-node AG +        │
     │  HAProxy + Seaweed) │        │  bootstrap scripts) │
     │ Ports: 5043,5000    │        │ Ports: 14331-14333  │
     └─────────┬───────────┘        └──────────┬──────────┘
               │                               │
               └───────────┬───────────────────┘
                           │
              ┌────────────▼────────────┐
              │    Flask Web App         │
               │    http://localhost:5002 │
              │                          │
              │  ┌──────────────────┐    │
              │  │ Environment      │    │
              │  │ Selection Page   │    │
              │  └────────┬─────────┘    │
              │           │              │
              │  ┌────────▼─────────┐    │
              │  │ CRUD Config Page │    │
              │  │ • Duration       │    │
              │  │ • Threads        │    │
              │  │ • Concurrent     │    │
              │  │   Users          │    │
              │  └────────┬─────────┘    │
              │           │              │
              │  ┌────────▼─────────┐    │
              │  │ Runner Threads   │    │
              │  │ (pg_runner.py /  │    │
              │  │  sql_runner.py)  │    │
              │  └────────┬─────────┘    │
              │           │              │
              │  ┌────────▼─────────┐    │
              │  │ Backup Manager   │    │
              │  │ • PG WAL Archive │    │
              │  │ • SQL TLOG Bkup  │    │
              │  └──────────────────┘    │
              └──────────────────────────┘
```

### Directory Structure

```
Postgres_SQLServer_Test_Servers/
├── start_all.ps1             # Self-contained launcher (Windows PowerShell)
├── stop_all.ps1              # Self-contained stopper (Windows PowerShell)
├── start_servers.sh          # Self-contained launcher (Linux / macOS)
├── stop_servers.sh           # Self-contained stopper (Linux / macOS)
├── start_all.ps1             # PowerShell launcher (Windows)
├── stop_all.ps1              # PowerShell stopper (Windows)
├── README.md
│
├── Postgres_HA_docker/       # PostgreSQL Patroni HA cluster
│   ├── docker-compose.yml    # 3 Patroni nodes + etcd + HAProxy + backups
│   ├── haproxy.cfg
│   └── docker/
│       ├── Dockerfile
│       ├── init_databases.sql    # Schema + seed data for 5 databases
│       ├── pg_crud_load.py       # Standalone load generator (CLI)
│       └── backup.sh
│
├── SQL_Server_HA_Docker/     # SQL Server Always On AG cluster
│   ├── docker-compose.yml    # 3 SQL Server nodes + bootstrap
│   ├── .env                  # Passwords and secrets
│   └── mssql-setup/
│       ├── bootstrap/        # AG setup scripts
│       ├── scripts/          # Healthcheck, failover scripts
│       ├── init_databases.sql     # Schema + seed data for 5 databases
│       └── load_test_app/         # Standalone load generator (CLI)
│
└── web_app/                  # Flask web application
    ├── __init__.py
    ├── app.py                # Flask routes, job orchestration, report generation
    ├── config.py             # DB config + cross-platform ODBC detection
    ├── pg_runner.py          # PostgreSQL CRUD generator (multi-threaded)
    ├── sql_runner.py         # SQL Server CRUD generator (multi-threaded)
    ├── backup_manager.py     # Scheduled backup service
    ├── resource_advisor.py   # System RAM detection + recommended resource limits
    ├── reports/              # Auto-generated CRUD run reports (text files)
    ├── requirements.txt      # Python dependencies
    ├── templates/
    │   ├── index.html        # Environment selection page
    │   ├── crud_config.html  # CRUD config + live log + results
    │   └── backup.html       # Backup management page
    └── static/
        └── style.css         # Dark theme styling
```

## Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| Docker | 24+ | Run the HA cluster containers |
| Docker Compose | v2+ | Orchestrate multi-container services |
| Python | 3.8+ | Run the web app |
| pip | 21+ | Install Python dependencies |

### ODBC Driver for SQL Server

The launcher scripts **auto-detect and auto-install** the ODBC driver on all platforms. No manual installation is needed.

| Platform | Auto-install method |
|----------|-------------------|
| **Windows** | `winget install Microsoft.ODBCDriver18` → fallback: direct `.msi` download + silent `msiexec` |
| **Linux (Debian/Ubuntu)** | Adds Microsoft apt repo → `apt-get install -y msodbcsql18` (via `sudo`) |
| **Linux (RHEL/Fedora)** | Adds Microsoft yum/dnf repo → `yum/dnf install -y msodbcsql18` (via `sudo`) |
| **macOS** | `brew tap microsoft/mssql-release` → `brew install msodbcsql18` |

The app also auto-detects the best available driver at runtime, falling back through versions 18→17→13→11→FreeTDS.

If auto-install fails (e.g., no `sudo` access or `brew` not installed), the launcher prints a warning with manual download instructions. SQL Server CRUD will be unavailable until the driver is installed, but PostgreSQL and the web app still work.

## Quick Start

### 1. Start Everything

```bash
# Windows (bypass execution policy):
PowerShell -ExecutionPolicy Bypass -File .\start_all.ps1

# Or if execution policy is already set:
.\start_all.ps1

# Linux / macOS:
./start_servers.sh
```

The launcher will:
1. **Detect system resources** (total RAM) and compute optimal container memory limits
2. **Prompt you to choose** which engines to start: both, PostgreSQL only, SQL Server only, or exit
3. **Generate `docker-compose.override.yml`** files with scaled memory limits (cleaned up on `stop`)
4. **Check & auto-install the SQL Server ODBC driver** if missing (requires `sudo` on Linux, `brew` on macOS, admin on Windows)
5. Start selected engine(s) via `docker-compose up -d`
6. Wait 60 seconds for containers to initialize
7. Install Python dependencies
8. Launch the Flask web app on `http://localhost:5002`

**Foreground mode (default):** The launcher stays in the console after starting, showing live Flask logs. Press **Ctrl+C** to stop the web app (containers keep running — stop them with `stop_all.ps1` / `stop_servers.sh`).

**Background mode:** Pass `-Background` (Windows) or `--detach` (Linux/macOS) to launch the web app as a detached background process. The script exits after starting. Use the stop scripts to shut everything down.

> **Tip:** To skip the interactive prompt, pass flags directly: `.\start_all.ps1 -SkipPostgres` or `./start_servers.sh --skip-sql-server`.

### 2. Open the Web App

Navigate to **http://localhost:5002** in your browser.

### 3. Select Environment

Click either **PostgreSQL** or **SQL Server** to configure a CRUD load test.

### 4. Configure and Run

| Parameter | Default | Description |
|-----------|---------|-------------|
| Duration (seconds) | 30 | How long the test runs |
| Worker Threads | 2 | Number of concurrent threads |
| Concurrent Users | 3 | Distinct application names (PG) / users (SQL) |

Click **Start CRUD Load** to begin. Watch live per-operation logs stream in real time. When complete:

- A **summary table** shows per-database success rates and throughput.
- A **Download Report** button lets you download a detailed text report with per-operation stats, top errors, and failure breakdown by database/operation.
- If any operations failed, a **Failed Task Analysis** section shows the total failure count, top error types, and a scrollable list of recent failures.

### 5. Manage Backups

Navigate to **Backup Manager** to start/stop scheduled backups:

| Backup Type | Default Interval | Description |
|-------------|-----------------|-------------|
| PostgreSQL WAL Archive | 300s (5 min) | Tars WAL files from Patroni leader to `backups/postgres/` |
| SQL Server TLOG Backup | 300s (5 min) | Runs `BACKUP LOG` on all 5 DBs across all 3 nodes |

### 6. Stop Everything

```bash
# Windows (bypass execution policy):
PowerShell -ExecutionPolicy Bypass -File .\stop_all.ps1

# Or via the start script:
.\start_all.ps1 -Stop

# Linux / macOS:
./stop_servers.sh

# Or via the start script:
./start_servers.sh --stop
```

> The stop scripts also clean up any generated `docker-compose.override.yml` files.

## Resource-Aware Memory Limits

When launched without skip-flags, both `start_all.ps1` and `start_servers.sh` detect your system's total physical RAM and scale container memory limits proportionally. This prevents overloading the host machine.

### Memory Scaling Tiers

| Total RAM  | Scale Factor | PostgreSQL (per Patroni node) | SQL Server (sql1/sql2) | SQL Server (sql3) | PG shared_buffers | PG effective_cache |
|------------|-------------|-------------------------------|----------------------|--------------------|--------------------|--------------------|
| ≥ 32 GB    | 100%        | 2.0g                          | 6.0g                 | 4.0g               | 512MB              | 1536MB             |
| 16–31 GB   | 50%         | 1.0g                          | 3.0g                 | 2.0g               | 256MB              | 768MB              |
| 8–15 GB    | 30%         | 0.6g                          | 1.8g                 | 1.2g               | 153MB              | 460MB              |
| < 8 GB     | 15%         | 0.5g                          | 1.0g                 | 1.0g               | 76MB               | 230MB              |

### How It Works

1. The launcher calls `web_app/resource_advisor.py` (or uses a WMI/`/proc/meminfo` fallback) to detect total RAM
2. A scale factor is selected from the tier table above
3. A `docker-compose.override.yml` file is generated in each Docker directory with scaled `mem_limit` values
4. For PostgreSQL, Patroni environment variables `PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS` and `PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE` are also set in the override to tune shared_buffers and effective_cache_size
5. For SQL Server, only `mem_limit` is overridden (SQL Server respects the container cgroup limit)
6. `docker-compose up -d` automatically merges the override file with the base `docker-compose.yml`
7. On `stop`, the override files are deleted

> Minimums: PostgreSQL Patroni nodes floor at 0.5g, SQL Server nodes floor at 1.0g.

## Launcher Command Reference

### Windows (start_all.ps1)

```powershell
PowerShell -ExecutionPolicy Bypass -File .\start_all.ps1 [-SkipPostgres] [-SkipSqlServer] [-NoWebApp] [-Background] [-Status] [-Stop]
```

| Flag | Description |
|------|-------------|
| *(no flags)* | **Interactive mode** — prompts you to choose which engines to start: both, PostgreSQL only, SQL Server only, or exit. Then launches the web app in **foreground** (console stays open with live logs, Ctrl+C to stop) |
| `-SkipPostgres` | Skip starting the PostgreSQL cluster (non-interactive start) |
| `-SkipSqlServer` | Skip starting the SQL Server cluster (also skips ODBC check) |
| `-NoWebApp` | Skip starting the Flask web app |
| `-Background` | Launch the web app as a **detached background process** (script exits after starting). Use `stop_all.ps1` to shut down |
| `-Status` | Show running/stopped status of all services |
| `-Stop` | Gracefully stop all services |

> **Interactive mode** is activated when no skip flags are provided. Run the script without arguments to see the engine selection menu.
>
> **Foreground vs Background:** By default the launcher runs the web app in the foreground so you can see live logs and press Ctrl+C to stop. Pass `-Background` for the previous behavior (detached process, script exits).

### Linux / macOS (start_servers.sh)

```bash
./start_servers.sh [--skip-postgres] [--skip-sql-server] [--no-web-app] [--detach] [--status] [--stop]
```

| Flag | Description |
|------|-------------|
| *(no flags)* | **Interactive mode** — prompts you to choose which engines to start. Then launches the web app in **foreground** (console stays open with live logs, Ctrl+C to stop) |
| `--skip-postgres` | Skip starting the PostgreSQL cluster (non-interactive start) |
| `--skip-sql-server` | Skip starting the SQL Server cluster (also skips ODBC check) |
| `--no-web-app` | Skip starting the Flask web app |
| `--detach` | Launch the web app as a **detached background process** (script exits after starting). Use `stop_servers.sh` to shut down |
| `--status` | Show running/stopped status of all services |
| `--stop` | Gracefully stop all services |

> ODBC Driver is automatically detected and installed before the web app starts.
> Use `--skip-sql-server` / `-SkipSqlServer` to skip both the SQL Server cluster and the ODBC check.
>
> **Foreground vs Detached:** By default the launcher runs the web app in the foreground so you can see live logs and press Ctrl+C to stop. Pass `--detach` for the previous behavior (background process, script exits).

## Database Connections

### PostgreSQL (Patroni HA)

| Endpoint | Port | Purpose |
|----------|------|---------|
| Direct (patroni1) | 5043 | Direct node connection |
| HAProxy Write | 5000 | Automatic master routing |
| HAProxy Read | 5001 | Load-balanced replica routing |

Credentials: `postgres` / `postgres123`

### SQL Server (Always On AG)

| Node | Port |
|------|------|
| sql1 | 14331 |
| sql2 | 14332 |
| sql3 | 14333 |

Credentials: `sa` / `S@L_2024_HADr_D0ck3r!`

## Databases

Both clusters share the same 5 demo databases:

| Database | Tables | Purpose |
|----------|--------|---------|
| `hotel_booking` | 24 | Guests, reservations, rooms, bookings, payments, housekeeping |
| `e_commerce` | 30 | Products, customers, orders, inventory, reviews, coupons |
| `erp_system` | 29 | Companies, employees, projects, payroll, journal entries, assets |
| `hrm_tool` | 30 | Employees, leave, attendance, training, performance, recruitment |
| `department_store` | 31 | Products, sales, inventory, promotions, loyalty, suppliers |

Each database contains 50K–200K seed records for realistic query distribution.

## CRUD Operation Details

### PostgreSQL Operations

| Database | Create (C) | Read (R) | Update (U) | Delete (D) |
|----------|-----------|---------|-----------|-----------|
| hotel_booking | housekeeping_tasks | guests | housekeeping_tasks | housekeeping_tasks |
| e_commerce | product_reviews | products | product_reviews | product_reviews |
| erp_system | timesheets | employees | timesheets | timesheets |
| hrm_tool | training_enrollments | employees_hrm | training_enrollments | training_enrollments |
| department_store | inventory_movements | products_store | inventory_movements | inventory_movements |

Distribution: **R=60%, C=13%, U=13%, D=13%**

### SQL Server Operations

| Database | Operations |
|----------|-----------|
| hotel_booking | SELECT guests/reservations/rooms, INSERT reservation, UPDATE reservation status |
| e_commerce | SELECT products/orders/customers, INSERT product/order, UPDATE order status |
| erp_system | SELECT employees/projects/journal_entries, INSERT employee/project, UPDATE salary |
| hrm_tool | SELECT employees, INSERT training program/leave application |
| department_store | SELECT products/sales/inventory, INSERT sale/promotion |

Distribution: **R=60%, C=20%, U=20%**

## Web App Details

### Pages

1. **Home** (`/`) — Environment selection (PostgreSQL in blue vs SQL Server in light skyblue)
2. **CRUD Config** (`/crud/<env>`) — Configure and run load tests
3. **Backup Manager** (`/backup`) — Start/stop scheduled backups

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/start_crud` | Start new CRUD load test |
| `GET` | `/job_status/<id>` | Poll job progress and results |
| `GET` | `/job_report/<id>` | Download detailed text report with failed-task analysis |
| `POST` | `/stop_job/<id>` | Stop a running job |
| `GET` | `/backup/status` | Get backup service status |
| `POST` | `/backup/start_pg` | Start PG WAL archiving |
| `POST` | `/backup/stop_pg` | Stop PG WAL archiving |
| `POST` | `/backup/start_mssql` | Start SQL Server TLOG backup |
| `POST` | `/backup/stop_mssql` | Stop SQL Server TLOG backup |

## Cross-Platform Support

| Component | Windows | Linux | macOS |
|-----------|---------|-------|-------|
| Docker Compose | ✅ | ✅ | ✅ |
| Flask Web App | ✅ | ✅ | ✅ |
| PostgreSQL CRUD | ✅ | ✅ | ✅ |
| SQL Server CRUD | ✅ (ODBC req.) | ✅ (ODBC req.) | ✅ (ODBC req.) |
| Launcher | `start_all.ps1` | `start_servers.sh` | `start_servers.sh` |
| Stopper | `stop_all.ps1` | `stop_servers.sh` | `stop_servers.sh` |
| ODBC Auto-Install | `winget` / `msiexec` | `apt` / `yum` / `dnf` (via sudo) | `brew` |
| ODBC Detection | Windows Registry + pyodbc | `odbcinst -j` + pyodbc | `odbcinst -j` + pyodbc |
| Process Management | `taskkill` | `os.kill(SIGTERM)` | `os.kill(SIGTERM)` |

## Environment Variables

All optional — defaults work with the provided Docker setups.

| Variable | Default | Description |
|----------|---------|-------------|
| `PG_HOST` | `localhost` | PostgreSQL host |
| `PG_PORT` | `5043` | PostgreSQL port (direct) |
| `PG_USER` | `postgres` | PostgreSQL user |
| `PG_PASSWORD` | `postgres123` | PostgreSQL password |
| `MSSQL_SA_USER` | `sa` | SQL Server SA user |
| `MSSQL_SA_PASSWORD` | `S@L_2024_HADr_D0ck3r!` | SQL Server SA password |
| `MSSQL_DRIVER` | auto-detect | Force a specific ODBC driver name |
| `BACKUP_DIR` | `web_app/backups/` | Local backup storage directory |

## PowerShell Execution Policy

On Windows, PowerShell may block `.ps1` scripts due to the system's execution policy. You have two options:

### Option A: Bypass per session (recommended)
Run the script with the `Bypass` flag — no permanent changes needed:
```powershell
PowerShell -ExecutionPolicy Bypass -File .\start_all.ps1
```

### Option B: Change policy permanently
```powershell
# Run as Administrator, then:
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# Now you can run:
.\start_all.ps1
```

> On Linux/macOS, `start_servers.sh` and `stop_servers.sh` do not involve PowerShell at all and avoid this issue entirely.

## Troubleshooting

### Containers not starting
```bash
# Check status (Windows)
PowerShell -ExecutionPolicy Bypass -File .\start_all.ps1 -Status

# Check status (Linux / macOS)
./start_servers.sh --status

# View logs for a specific service
docker logs patroni1
docker logs sql1
```

### ODBC Driver not found / install failed
```bash
# The launcher tries auto-install first. If it fails:

# 1. Install manually (requires sudo/brew admin):

# Windows (admin prompt):
winget install Microsoft.ODBCDriver18

# Linux (Debian/Ubuntu):
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
sudo curl -sSL https://packages.microsoft.com/config/ubuntu/22.04/prod.list -o /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update && ACCEPT_EULA=Y sudo apt-get install -y msodbcsql18

# macOS:
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
ACCEPT_EULA=Y brew install msodbcsql18

# 2. List installed ODBC drivers
python -c "import pyodbc; print(pyodbc.drivers())"

# 3. Force a specific driver via env var (skip auto-detection)
set MSSQL_DRIVER="ODBC Driver 17 for SQL Server"
# then run:
./start_servers.sh

# 4. If you don't need SQL Server CRUD, skip it entirely:
./start_servers.sh --skip-sql-server
```

### Port conflicts
Edit the host port mappings in `docker-compose.yml` files if ports 14331-14333, 5000/5001 (HAProxy), 5002 (web app), or 5043-5045 are already in use.

### Web app not starting
```bash
# Try running directly
cd web_app
pip install -r requirements.txt
python app.py
```

## License

Internal tool — for testing and development purposes only.
