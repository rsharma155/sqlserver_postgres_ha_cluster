"""Tests for the schema deployment module."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from deploy_schema import _split_sql_batches


def test_split_sql_batches():
    sql = """CREATE PROC test1 AS BEGIN SELECT 1; END;
GO
CREATE PROC test2 AS BEGIN SELECT 2; END;
GO"""
    batches = _split_sql_batches(sql)
    assert len(batches) >= 2, f"Expected at least 2 batches, got {len(batches)}"


def test_split_no_go():
    sql = "SELECT 1; SELECT 2;"
    batches = _split_sql_batches(sql)
    assert len(batches) == 1


def test_split_empty():
    assert _split_sql_batches("") == [""]


def test_sql_files_exist():
    sql_dir = os.path.join(os.path.dirname(__file__), "..", "sql")
    pg_file = os.path.join(sql_dir, "pg_functions.sql")
    ms_file = os.path.join(sql_dir, "mssql_procedures.sql")
    assert os.path.exists(pg_file), f"Missing: {pg_file}"
    assert os.path.exists(ms_file), f"Missing: {ms_file}"


def test_pg_functions_have_no_syntax_errors():
    """Basic check — count CREATE OR REPLACE FUNCTION statements."""
    sql_dir = os.path.join(os.path.dirname(__file__), "..", "sql")
    pg_file = os.path.join(sql_dir, "pg_functions.sql")
    with open(pg_file) as f:
        content = f.read()
    func_count = content.count("CREATE OR REPLACE FUNCTION")
    assert func_count >= 40, f"Expected 40+ functions, found {func_count}"


def test_mssql_procedures_have_no_syntax_errors():
    """Basic check — count CREATE OR ALTER PROCEDURE statements."""
    sql_dir = os.path.join(os.path.dirname(__file__), "..", "sql")
    ms_file = os.path.join(sql_dir, "mssql_procedures.sql")
    with open(ms_file) as f:
        content = f.read()
    proc_count = content.count("CREATE OR ALTER PROCEDURE")
    assert proc_count >= 30, f"Expected 30+ procedures, found {proc_count}"
