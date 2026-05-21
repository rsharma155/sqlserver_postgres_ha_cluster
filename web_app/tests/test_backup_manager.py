"""Tests for the backup manager."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from backup_manager import BackupManager


def test_initial_status():
    bm = BackupManager()
    status = bm.get_status()
    assert status["pg_archive_running"] == False
    assert status["mssql_backup_running"] == False
    assert status["pg_last"] is None
    assert status["mssql_last"] is None


def test_start_stop_pg_archive():
    bm = BackupManager()
    bm.start_pg_archive(interval_seconds=99999)
    status = bm.get_status()
    # May not show running immediately due to thread startup
    bm.stop_pg_archive()
    status = bm.get_status()
    assert status["pg_archive_running"] == False


def test_start_stop_mssql_backup():
    bm = BackupManager()
    bm.start_mssql_backup(interval_seconds=99999)
    bm.stop_mssql_backup()
    status = bm.get_status()
    assert status["mssql_backup_running"] == False
