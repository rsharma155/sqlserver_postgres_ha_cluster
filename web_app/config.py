"""
Central configuration module for the CRUD load generator.

Loads database connection parameters from environment variables
(with sensible defaults matching the Docker HA cluster setups).

Key features:
  - Cross-platform ODBC driver auto-detection for SQL Server.
  - Supports PostgreSQL Patroni HA cluster via HAProxy or direct node.
  - Supports SQL Server 3-node Availability Group via mapped ports.
  - All database names shared across both engines.

Environment variables (all optional):
  PG_HOST, PG_PORT, PG_USER, PG_PASSWORD
  MSSQL_SA_USER, MSSQL_SA_PASSWORD, MSSQL_DRIVER
  BACKUP_DIR
"""

import os
import sys
import subprocess

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

PG_CONFIG = {
    "host": os.getenv("PG_HOST", "localhost"),
    "port": int(os.getenv("PG_PORT", "5000")),
    "user": os.getenv("PG_USER", "postgres"),
    "password": os.getenv("PG_PASSWORD", "postgres123"),
    "haproxy_host": "localhost",
    "haproxy_port_write": 5000,
    "haproxy_port_read": 5001,
}

MSSQL_CONFIG = {
    "nodes": {
        "sql1": {"host": "localhost", "port": 14331},
        "sql2": {"host": "localhost", "port": 14332},
        "sql3": {"host": "localhost", "port": 14333},
    },
    "driver": os.getenv("MSSQL_DRIVER", None),
    "sa_user": os.getenv("MSSQL_SA_USER", "sa"),
    "sa_password": os.getenv("MSSQL_SA_PASSWORD", "S@L_2024_HADr_D0ck3r!"),
}

DATABASES = [
    "hotel_booking",
    "e_commerce",
    "erp_system",
    "hrm_tool",
    "department_store",
]

CRUD_LIMITS = {
    "max_duration": 3600,
    "max_duration_warn": 600,
    "default_duration": 30,
    "max_threads": 20,
    "default_threads": 2,
    "max_users": 10,
    "default_users": 3,
    "max_concurrency": 50,
}

# Which environments are active (set via ACTIVE_ENVS env var).
# Used by the home page to show only the relevant engine(s).
# Values: "postgres", "sqlserver", or "all" (default).
_ACTIVE_ENVS = os.getenv("ACTIVE_ENVS", "all").lower().strip()
if _ACTIVE_ENVS == "all":
    ACTIVE_ENVIRONMENTS = ["postgres", "sqlserver"]
else:
    ACTIVE_ENVIRONMENTS = [e.strip() for e in _ACTIVE_ENVS.split(",") if e.strip() in ("postgres", "sqlserver")]
    if not ACTIVE_ENVIRONMENTS:
        ACTIVE_ENVIRONMENTS = ["postgres", "sqlserver"]

BACKUP_DIR = os.getenv("BACKUP_DIR", os.path.join(BASE_DIR, "backups"))
os.makedirs(BACKUP_DIR, exist_ok=True)


def detect_odbc_driver():
    """Detect the best available ODBC driver for SQL Server on any platform."""
    if MSSQL_CONFIG["driver"]:
        return MSSQL_CONFIG["driver"]

    candidates = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "ODBC Driver 13.1 for SQL Server",
        "ODBC Driver 13 for SQL Server",
        "ODBC Driver 11 for SQL Server",
        "FreeTDS",
    ]

    try:
        if sys.platform == "win32":
            import winreg
            for candidate in candidates:
                key_path = (
                    r"SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers"
                )
                try:
                    with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key_path) as key:
                        i = 0
                        while True:
                            name, value, _ = winreg.EnumValue(key, i)
                            if name == candidate and value == "Installed":
                                MSSQL_CONFIG["driver"] = candidate
                                return candidate
                            i += 1
                except (OSError, WindowsError):
                    pass
            # Try pyodbc to list drivers directly
            import pyodbc
            installed = [d for d in pyodbc.drivers() if "SQL Server" in d or "FreeTDS" in d]
            if installed:
                MSSQL_CONFIG["driver"] = installed[0]
                return installed[0]
        else:
            # Linux / macOS: try pyodbc.drivers()
            try:
                import pyodbc
                installed = pyodbc.drivers()
                for c in candidates:
                    if c in installed:
                        MSSQL_CONFIG["driver"] = c
                        return c
            except ImportError:
                pass
            # Try running odbcinst -j to find drivers
            try:
                result = subprocess.run(
                    ["odbcinst", "-j"], capture_output=True, text=True, timeout=10
                )
                for c in candidates:
                    if c in result.stdout:
                        MSSQL_CONFIG["driver"] = c
                        return c
            except (FileNotFoundError, subprocess.TimeoutExpired):
                pass
    except Exception:
        pass

    MSSQL_CONFIG["driver"] = candidates[0]
    return candidates[0]


# Auto-detect on import if not already set
detect_odbc_driver()
