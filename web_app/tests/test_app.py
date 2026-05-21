"""Tests for the Flask application routes and API.

Uses the Flask test client — no real database needed.
"""

import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest


@pytest.fixture
def client():
    """Create a Flask test client."""
    from app import app
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def test_index_page(client):
    rv = client.get("/")
    assert rv.status_code == 200
    assert b"PostgreSQL" in rv.data or b"postgres" in rv.data


def test_crud_page_postgres(client):
    rv = client.get("/crud/postgres")
    assert rv.status_code == 200


def test_crud_page_sqlserver(client):
    rv = client.get("/crud/sqlserver")
    assert rv.status_code == 200


def test_crud_page_invalid_env(client):
    rv = client.get("/crud/mongodb")
    assert rv.status_code == 400


def test_backup_page(client):
    rv = client.get("/backup")
    assert rv.status_code == 200


def test_activity_endpoint(client):
    rv = client.get("/activity")
    assert rv.status_code == 200
    data = json.loads(rv.data)
    assert isinstance(data, list)


def test_app_log_endpoint(client):
    rv = client.get("/app_log")
    assert rv.status_code == 200
    data = json.loads(rv.data)
    assert isinstance(data, list)


def test_backup_status_endpoint(client):
    rv = client.get("/backup/status")
    assert rv.status_code == 200
    data = json.loads(rv.data)
    assert "pg_archive_running" in data
    assert "mssql_backup_running" in data


def test_stop_job_not_found(client):
    rv = client.post("/stop_job/99999")
    assert rv.status_code == 404


def test_job_status_not_found(client):
    rv = client.get("/job_status/99999")
    assert rv.status_code == 404


def test_start_crud_missing_data(client):
    rv = client.post("/start_crud",
                     content_type="application/json",
                     data=json.dumps({}))
    # Should still work with defaults
    assert rv.status_code == 200


def test_start_crud_postgres(client):
    rv = client.post("/start_crud",
                     content_type="application/json",
                     data=json.dumps({
                         "environment": "postgres",
                         "seconds": 5,
                         "threads": 1,
                         "users": 1,
                     }))
    assert rv.status_code == 200
    data = json.loads(rv.data)
    assert "job_id" in data


def test_start_crud_sqlserver(client):
    rv = client.post("/start_crud",
                     content_type="application/json",
                     data=json.dumps({
                         "environment": "sqlserver",
                         "seconds": 5,
                         "threads": 1,
                         "users": 1,
                     }))
    assert rv.status_code == 200
    data = json.loads(rv.data)
    assert "job_id" in data


def test_404_handler(client):
    rv = client.get("/nonexistent-route")
    assert rv.status_code == 404


def test_backup_start_stop_pg(client):
    rv = client.post("/backup/start_pg",
                     content_type="application/json",
                     data=json.dumps({"interval": 300}))
    assert rv.status_code == 200
    rv = client.post("/backup/stop_pg")
    assert rv.status_code == 200


def test_backup_start_stop_mssql(client):
    rv = client.post("/backup/start_mssql",
                     content_type="application/json",
                     data=json.dumps({"interval": 300}))
    assert rv.status_code == 200
    rv = client.post("/backup/stop_mssql")
    assert rv.status_code == 200
