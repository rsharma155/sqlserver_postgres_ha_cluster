"""Validates the pg_runner.py OPS structure.

Ensures every database has C/R/U/D operations, that every function
name referenced matches what's in the SQL file, and that gen()
returns the correct number of params.
"""

import sys, os, re, inspect
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from pg_runner import OPS, DATABASES, CRUD_TYPES


def _count_sql_params(fn_sql: str) -> int:
    """Count %s placeholders in a SQL string."""
    # Ignore %% (escaped %)
    cleaned = re.sub(r'%%', '', fn_sql)
    return cleaned.count('%s') + cleaned.count('%s ')


def test_all_databases_present():
    for db in DATABASES:
        assert db in OPS, f"Missing {db} in OPS"


def test_all_crud_types_present():
    for db_name, ops in OPS.items():
        for t in CRUD_TYPES:
            assert t in ops, f"{db_name} missing CRUD type {t}"
            assert len(ops[t]) > 0, f"{db_name}.{t} has no operations"


def test_no_empty_op_lists():
    for db_name, ops in OPS.items():
        for t, items in ops.items():
            assert len(items) > 0, f"{db_name}.{t} is empty"
            for item in items:
                assert "fn" in item, f"{db_name}.{t} missing fn"
                assert "gen" in item, f"{db_name}.{t} missing gen"
                assert "label" in item, f"{db_name}.{t} missing label"


def test_param_counts_match():
    for db_name, ops in OPS.items():
        for t, items in ops.items():
            for item in items:
                fn = item["fn"]
                gen_fn = item["gen"]
                try:
                    params = gen_fn()
                except Exception as exc:
                    assert False, f"{db_name}.{t} gen() failed: {exc}"
                sql_count = _count_sql_params(fn)
                # Handle functions with no params like crud_ecom_create_order()
                is_no_param = fn.strip().rstrip(";").endswith("()")
                if is_no_param:
                    assert len(params) == 0, f"{db_name}.{t} has no params but gen returned {params}"
                else:
                    assert len(params) == sql_count, \
                        f"{db_name}.{t} '{item['label']}': fn has {sql_count} placeholders but gen returned {len(params)} params: {params}"


def test_gen_returns_same_type_shape():
    for db_name, ops in OPS.items():
        for t, items in ops.items():
            for item in items:
                gen_fn = item["gen"]
                for _ in range(3):
                    try:
                        params = gen_fn()
                        assert isinstance(params, tuple), f"gen() should return tuple, got {type(params)}"
                    except Exception as exc:
                        assert False, f"{db_name}.{t} gen() failed on iteration: {exc}"
