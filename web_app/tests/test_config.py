"""Tests for config module."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


def test_databases_list():
    from config import DATABASES
    expected = ["hotel_booking", "e_commerce", "erp_system", "hrm_tool", "department_store"]
    assert DATABASES == expected, f"Got {DATABASES}"


def test_pg_config_defaults():
    from config import PG_CONFIG
    assert PG_CONFIG["host"] == "localhost"
    assert PG_CONFIG["port"] == 5043
    assert PG_CONFIG["user"] == "postgres"
    assert PG_CONFIG["password"] == "postgres123"


def test_mssql_config_defaults():
    from config import MSSQL_CONFIG
    assert "sql1" in MSSQL_CONFIG["nodes"]
    assert "sql2" in MSSQL_CONFIG["nodes"]
    assert "sql3" in MSSQL_CONFIG["nodes"]
    assert MSSQL_CONFIG["nodes"]["sql1"]["port"] == 14331
    assert MSSQL_CONFIG["sa_user"] == "sa"


def test_backup_dir():
    from config import BACKUP_DIR
    assert "backups" in BACKUP_DIR
