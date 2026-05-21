"""Tests for the in-memory command log."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from command_log import CommandLog


def test_add_and_recent():
    cl = CommandLog(maxlen=10)
    cl.add("PG CRUD", "SELECT 1")
    cl.add("SQL CRUD", "EXEC test")
    recent = cl.recent(5)
    assert len(recent) == 2
    assert recent[0]["source"] == "SQL CRUD"
    assert recent[0]["status"] == "running"
    assert recent[1]["source"] == "PG CRUD"


def test_status_transitions():
    cl = CommandLog(maxlen=10)
    entry = cl.add("Backup", "docker exec pg")
    assert entry["status"] == "running"
    cl.succeed(entry)
    assert entry["status"] == "success"
    cl.fail(entry, "timeout")
    assert entry["status"] == "failed"
    assert "timeout" in entry["output"]


def test_ring_buffer():
    cl = CommandLog(maxlen=3)
    for i in range(5):
        cl.add("Test", f"cmd-{i}")
    recent = cl.recent(10)
    assert len(recent) == 3
    assert recent[0]["command"] == "cmd-4"
    assert recent[2]["command"] == "cmd-2"


def test_empty_log():
    cl = CommandLog()
    assert cl.recent() == []
    assert cl.recent(5) == []
