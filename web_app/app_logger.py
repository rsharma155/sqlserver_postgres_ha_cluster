"""
Centralised application logger.

Writes to *web_app/app.log* (with 5 MB rotation, 3 backups) and keeps an
in-memory ring buffer of the last 1 000 records so the UI can display them.

Usage:
    from app_logger import logger
    logger.info("Container started")
    logger.error("Connection refused", exc_info=True)
    logger.debug("SQL: %s", sql)
"""

import logging
import logging.handlers
import os
from collections import deque

LOG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, "app.log")
ERROR_LOG_FILE = os.path.join(LOG_DIR, "error.log")


class RingBufferHandler(logging.Handler):
    """Keeps the last *capacity* log records in a deque for UI polling."""

    def __init__(self, capacity: int = 1000):
        super().__init__()
        self.buffer = deque(maxlen=capacity)

    def emit(self, record: logging.LogRecord):
        self.buffer.append(self.format(record))

    def tail(self, n: int = 50):
        return list(self.buffer)[-n:][::-1]


_ring = RingBufferHandler()

_formatter = logging.Formatter(
    "%(asctime)s [%(levelname)-5s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

_file_handler = logging.handlers.RotatingFileHandler(
    LOG_FILE, maxBytes=5 * 1024 * 1024, backupCount=3, encoding="utf-8"
)
_file_handler.setFormatter(_formatter)

_error_file_handler = logging.handlers.RotatingFileHandler(
    ERROR_LOG_FILE, maxBytes=5 * 1024 * 1024, backupCount=3, encoding="utf-8"
)
_error_file_handler.setFormatter(_formatter)
_error_file_handler.setLevel(logging.ERROR)

_ring.setFormatter(
    logging.Formatter("%(asctime)s [%(levelname)-5s] %(name)s: %(message)s",
                      datefmt="%H:%M:%S")
)

logger = logging.getLogger("db_crud")
logger.setLevel(logging.DEBUG)
logger.addHandler(_file_handler)
logger.addHandler(_error_file_handler)
logger.addHandler(_ring)
logger.propagate = False

# Convenience getter so the UI can fetch recent log lines.
def recent_logs(n: int = 50):
    return _ring.tail(n)
