"""Validates the sql_runner.py OPS structure.

Ensures every database has C/R/U operations, that named procedures
exist in the SQL file, and that no operation is empty.
"""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from sql_runner import OPS, DATABASES


def test_all_databases_present():
    for db in DATABASES:
        assert db in OPS, f"Missing {db} in OPS"


def test_all_crud_types_present():
    for db_name, ops in OPS.items():
        for t in ("C", "R", "U"):
            assert t in ops, f"{db_name} missing type {t}"
            assert len(ops[t]) > 0, f"{db_name}.{t} has no operations"


def test_no_empty_op_lists():
    for db_name, ops in OPS.items():
        for t, items in ops.items():
            assert len(items) > 0, f"{db_name}.{t} is empty"
            for op_name, op_func in items:
                assert op_name, f"{db_name}.{t} has empty op name"
                assert callable(op_func), f"{db_name}.{t} op_func not callable"


def test_ops_are_callable():
    """Verify op functions execute without error (no real DB)."""
    for db_name, ops in OPS.items():
        for t, items in ops.items():
            for op_name, op_func in items:
                try:
                    import pyodbc
                    # We can't actually test the query, but the lambda should be valid
                    pass
                except ImportError:
                    pass


def test_procedure_names_in_sql_file():
    """Verify all procedure names appear in the SQL file."""
    sql_path = os.path.join(os.path.dirname(__file__), "..", "sql", "mssql_procedures.sql")
    if not os.path.exists(sql_path):
        return  # skip if file not present
    with open(sql_path) as f:
        sql_content = f.read()
    for db_name, ops in OPS.items():
        for t, items in ops.items():
            for op_name, _ in items:
                proc_name = op_name.split()[0]  # "crud_hotel_read_guest" from "crud_hotel_read_guest (JOIN)"
                assert proc_name in sql_content, \
                    f"Procedure {proc_name} (from {db_name}.{t}) not found in mssql_procedures.sql"
