"""Tests for the application logger."""

import sys, os, tempfile, logging
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


def test_logger_imports():
    from app_logger import logger, recent_logs
    assert logger is not None
    assert recent_logs is not None


def test_logger_writes_buffer():
    from app_logger import logger, recent_logs
    logger.info("Unit test message")
    logs = recent_logs(5)
    found = any("Unit test message" in l for l in logs)
    assert found, f"Expected message in logs, got: {logs}"
