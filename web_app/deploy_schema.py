"""
Deploys PostgreSQL functions and SQL Server stored procedures
to all 5 databases so the CRUD runners can call them by name
instead of using inline ad-hoc queries.

Called once at web-app startup (from __init__.py / config.py).
"""

import os
import sys
import time
from app_logger import logger
from command_log import command_log

SQL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql")

PG_FUNCTIONS_FILE = os.path.join(SQL_DIR, "pg_functions.sql")
MSSQL_PROCEDURES_FILE = os.path.join(SQL_DIR, "mssql_procedures.sql")

DATABASES = [
    "hotel_booking",
    "e_commerce",
    "erp_system",
    "hrm_tool",
    "department_store",
]


def _read_sql(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


# ── PostgreSQL ──────────────────────────────────────────────────

def deploy_pg_functions(config: dict) -> list:
    """Connect to each database and run pg_functions.sql.

    Returns a list of result dicts: {db, ok, error?}.
    """
    sql = _read_sql(PG_FUNCTIONS_FILE)
    results = []
    try:
        import psycopg2
    except ImportError:
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary", "--quiet"])
        import psycopg2

    for db in DATABASES:
        entry = command_log.add("System",
                                f"Deploy PG functions to {db}...")
        try:
            conn = psycopg2.connect(
                host=config["host"],
                port=config["port"],
                user=config["user"],
                password=config["password"],
                dbname=db,
                connect_timeout=10,
            )
            conn.autocommit = True
            cur = conn.cursor()
            # Split on semicolons to run each statement separately,
            # but preserve function bodies that contain semicolons.
            # Safer approach: run the whole script at once.
            cur.execute(sql)
            cur.close()
            conn.close()
            command_log.succeed(entry)
            results.append({"db": db, "ok": True})
            logger.info("PG functions deployed to %s", db)
        except Exception as exc:
            command_log.fail(entry, str(exc)[:100])
            results.append({"db": db, "ok": False, "error": str(exc)})
            logger.warning("PG functions deploy to %s failed: %s", db, exc)
    return results


# ── SQL Server ──────────────────────────────────────────────────

def deploy_mssql_procedures(config: dict) -> list:
    """Connect to each node and run mssql_procedures.sql once.
    The script contains USE statements to target the correct databases.

    Returns a list of result dicts: {node, ok, error?}.
    """
    sql = _read_sql(MSSQL_PROCEDURES_FILE)
    results = []
    try:
        import pyodbc
    except ImportError:
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyodbc", "--quiet"])
        import pyodbc

    for node in config["nodes"]:
        info = config["nodes"][node]
        # Connect to 'master' initially
        conn_str = (
            f"DRIVER={{{config['driver']}}};"
            f"SERVER={info['host']},{info['port']};"
            f"UID={config['sa_user']};PWD={config['sa_password']};"
            f"Database=master;TrustServerCertificate=yes;"
            f"ConnectRetryCount=3;ConnectRetryInterval=5;"
        )
        entry = command_log.add("System",
                                f"Deploy MSSQL procedures to {node} (all DBs)...")
        try:
            conn = pyodbc.connect(conn_str, autocommit=True, timeout=30)
            cur = conn.cursor()
            current_db = "master"
            
            for batch in _split_sql_batches(sql):
                clean_batch = batch.strip()
                if not clean_batch:
                    continue
                
                # Check for USE statement to update current_db
                import re
                use_match = re.match(r'^\s*USE\s+\[?(\w+)\]?', clean_batch, re.IGNORECASE)
                if use_match:
                    new_db = use_match.group(1)
                    try:
                        cur.execute(clean_batch)
                        current_db = new_db
                    except Exception as e:
                        err_msg = str(e).lower()
                        if any(p in err_msg for p in ["does not exist", "4060", "927", "middle of a restore"]):
                            logger.info("Skipping USE %s on %s: DB not found/accessible/restoring", new_db, node)
                            current_db = "master"
                        else:
                            raise
                    continue

                try:
                    cur.execute(clean_batch)
                except Exception as e:
                    # Ignore errors related to read-only databases (replicas),
                    # databases in restoring state, or those that don't exist.
                    err_msg = str(e)
                    skip_patterns = [
                        "is read-only", 
                        "does not exist", 
                        "cannot be opened", 
                        "in the middle of a restore",
                        "4060",
                        "208" # Invalid object name
                    ]
                    if any(p in err_msg.lower() for p in skip_patterns):
                        logger.info("Skipping batch on %s (DB: %s): %s", node, current_db, err_msg[:100])
                        continue
                    raise
            cur.close()
            conn.close()
            command_log.succeed(entry)
            results.append({"node": node, "ok": True})
            logger.info("MSSQL procedures deployed to %s", node)
        except Exception as exc:
            command_log.fail(entry, str(exc)[:100])
            results.append({"node": node, "ok": False, "error": str(exc)})
            logger.warning("MSSQL procedures deploy to %s failed: %s", node, exc)
    return results


def _split_sql_batches(sql: str):
    """Split SQL text on GO statements (case-insensitive, line-aware)."""
    import re
    return re.split(r'^\s*GO\s*$', sql, flags=re.IGNORECASE | re.MULTILINE)


# ── Entry point ─────────────────────────────────────────────────

def deploy_all(attempts: int = 2, delay: int = 5) -> dict:
    """Call from web-app startup.

    Retries *attempts* times with *delay* seconds between attempts
    to give containers time to finish initialising.
    """
    from config import PG_CONFIG, MSSQL_CONFIG

    result = {"pg": [], "mssql": []}

    for attempt in range(1, attempts + 1):
        if attempt > 1:
            logger.info("Schema deploy attempt %d/%d (waiting %ds)...",
                        attempt, attempts, delay)
            time.sleep(delay)

        if not result["pg"]:
            try:
                result["pg"] = deploy_pg_functions(PG_CONFIG)
            except Exception as exc:
                logger.warning("PG deploy attempt %d failed: %s", attempt, exc)

        if not result["mssql"]:
            try:
                result["mssql"] = deploy_mssql_procedures(MSSQL_CONFIG)
            except Exception as exc:
                logger.warning("MSSQL deploy attempt %d failed: %s", attempt, exc)

        pg_ok = all(r.get("ok") for r in result["pg"])
        ms_ok = all(r.get("ok") for r in result["mssql"])
        if pg_ok and ms_ok:
            break

    return result
