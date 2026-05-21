"""
web_app package initialiser.

On first import (when the Flask app starts), this deploys the PostgreSQL
functions and SQL Server stored procedures to all 5 databases so the CRUD
runners can call them by name instead of using inline ad-hoc queries.
"""

import threading
from app_logger import logger

def _deploy_background():
    try:
        from deploy_schema import deploy_all
        result = deploy_all(attempts=2, delay=5)
        pg_count = len(result.get("pg", []))
        ms_count = len(result.get("mssql", []))
        pg_ok = sum(1 for r in result.get("pg", []) if r.get("ok"))
        ms_ok = sum(1 for r in result.get("mssql", []) if r.get("ok"))
        logger.info("Schema deploy: PG %d/%d ok, MSSQL %d/%d ok",
                    pg_ok, pg_count, ms_ok, ms_count)
    except Exception as exc:
        logger.warning("Background schema deploy skipped: %s", exc)

# Deploy in background thread so the web app starts immediately
# even if containers aren't ready yet.
t = threading.Thread(target=_deploy_background, daemon=True)
t.start()
