"""
In-memory ring buffer for live system commands being executed.

Each entry records an actual shell/SQL command, its source, its current
status, and any truncated output.  The UI polls /activity to display the
latest commands in a real-time panel.

Thread-safe via a single Lock.
"""

import threading
import time
from collections import deque


class CommandLog:
    def __init__(self, maxlen: int = 200):
        self._lock = threading.Lock()
        self._entries = deque(maxlen=maxlen)

    def add(self, source: str, command: str):
        """Record a new command in 'pending' state."""
        entry = {
            "id": int(time.time() * 1_000_000),
            "ts": time.strftime("%H:%M:%S"),
            "source": source,
            "command": command,
            "status": "running",
            "output": "",
        }
        with self._lock:
            self._entries.append(entry)
        return entry

    def succeed(self, entry: dict, output: str = ""):
        """Mark a previously added entry as successful."""
        with self._lock:
            entry["status"] = "success"
            entry["output"] = output[:200]

    def fail(self, entry: dict, error: str = ""):
        """Mark a previously added entry as failed."""
        with self._lock:
            entry["status"] = "failed"
            entry["output"] = error[:200]

    def recent(self, n: int = 50):
        """Return the *n* most recent entries (newest first)."""
        with self._lock:
            return list(self._entries)[-n:][::-1]


command_log = CommandLog()
