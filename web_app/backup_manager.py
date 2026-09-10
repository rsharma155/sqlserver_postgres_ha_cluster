"""
Scheduled backup manager for both database platforms.

PostgreSQL WAL archiving:
  - Prefers a mounted /wal_archive volume (used when the web app runs in Docker).
  - Falls back to `docker exec` on patroni1 when running on the host.

SQL Server transaction log backups:
  - Runs BACKUP LOG over pyodbc against each node.
  - Falls back to `docker exec` + sqlcmd if pyodbc is unavailable.

Both run on independent configurable intervals in daemon threads.
Every command is logged to the in-memory command log for the live UI.
"""

import os
import tarfile
import threading
from datetime import datetime
from config import BACKUP_DIR, DATABASES, MSSQL_CONFIG, PG_CONFIG
from command_log import command_log
from app_logger import logger

PG_BACKUP_DIR = os.path.join(BACKUP_DIR, "postgres")
MSSQL_BACKUP_DIR = os.path.join(BACKUP_DIR, "mssql")
os.makedirs(PG_BACKUP_DIR, exist_ok=True)
os.makedirs(MSSQL_BACKUP_DIR, exist_ok=True)

WAL_ARCHIVE_DIR = os.getenv("WAL_ARCHIVE_DIR", "/wal_archive")


def _run_cmd(cmd, timeout=120, capture=True):
    """Run a shell command cross-platform."""
    import subprocess
    kwargs = {"timeout": timeout}
    if capture:
        kwargs["capture_output"] = True
    return subprocess.run(cmd, **kwargs)


class BackupManager:
    def __init__(self):
        self._pg_thread = None
        self._mssql_thread = None
        self._stop_pg = threading.Event()
        self._stop_mssql = threading.Event()
        self._pg_interval = 300
        self._mssql_interval = 300
        self._pg_running = False
        self._mssql_running = False
        self._pg_last = None
        self._mssql_last = None
        self._pg_log = []
        self._mssql_log = []
        self._pg_fake = False
        self._mssql_fake = False

    # ── PostgreSQL WAL Archive ──────────────────────────────────

    def _pg_loop(self):
        self._pg_running = True
        logger.info("PG WAL archive loop started (interval=%ds, fake=%s)", self._pg_interval, self._pg_fake)
        try:
            while not self._stop_pg.is_set():
                try:
                    if self._pg_fake:
                        result = self._run_pg_fake_backup()
                    else:
                        result = self._run_pg_archive()
                    self._pg_last = datetime.now()
                    self._pg_log.append(f"[{self._pg_last}] WAL archive: {result}")
                    logger.info("PG WAL archive completed: %s", result)
                except Exception as e:
                    logger.error("PG WAL archive failed: %s", e, exc_info=True)
                    self._pg_log.append(f"[{datetime.now()}] WAL archive ERROR: {e}")
                self._stop_pg.wait(self._pg_interval)
        finally:
            self._pg_running = False

    def _run_pg_archive(self):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        archive_file = os.path.join(PG_BACKUP_DIR, f"wal_archive_{ts}.tar.gz")

        if os.path.isdir(WAL_ARCHIVE_DIR):
            cmd_entry = command_log.add("Backup", f"tar {WAL_ARCHIVE_DIR} -> {archive_file}")
            try:
                with tarfile.open(archive_file, "w:gz") as tar:
                    tar.add(WAL_ARCHIVE_DIR, arcname=".")
                command_log.succeed(cmd_entry)
            except Exception as e:
                command_log.fail(cmd_entry, str(e)[:100])
                raise
            size = os.path.getsize(archive_file)
            return f"Archived to {archive_file} ({size} bytes)"

        import subprocess
        shell_cmd = "tar -czf - -C /wal_archive . 2>/dev/null"
        cmd = ["docker", "exec", "patroni1", "bash", "-c", shell_cmd]
        cmd_entry = command_log.add("Backup", f"docker exec patroni1 bash -c \"{shell_cmd}\" > {archive_file}")
        with open(archive_file, "wb") as f:
            result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, timeout=60)
            if result.returncode != 0:
                err = result.stderr.decode().strip()[:100]
                command_log.fail(cmd_entry, err)
                raise RuntimeError(f"docker exec failed: {err}")
            command_log.succeed(cmd_entry)
        size = os.path.getsize(archive_file)
        return f"Archived to {archive_file} ({size} bytes)"

    def _run_pg_fake_backup(self):
        """Simulate backup load by connecting to each database."""
        import psycopg2
        results = []
        for db in DATABASES:
            label = f"SELECT 1 on {db} via {PG_CONFIG['host']}:{PG_CONFIG['port']}"
            cmd_entry = command_log.add("Backup (Fake)", label)
            try:
                conn = psycopg2.connect(
                    host=PG_CONFIG["host"],
                    port=PG_CONFIG["port"],
                    user=PG_CONFIG["user"],
                    password=PG_CONFIG["password"],
                    dbname=db,
                    connect_timeout=10,
                )
                cur = conn.cursor()
                cur.execute("SELECT 1")
                cur.close()
                conn.close()
                results.append(f"{db}: OK")
                command_log.succeed(cmd_entry)
            except Exception as e:
                err = str(e)[:100]
                results.append(f"{db}: {err}")
                command_log.fail(cmd_entry, err)
        return "; ".join(results)

    def start_pg_archive(self, interval_seconds=300, fake=False):
        if self._pg_running:
            logger.warning("PG WAL archive already running; ignoring duplicate start")
            return False
        self._pg_interval = interval_seconds
        self._pg_fake = fake
        self._stop_pg.clear()
        self._pg_thread = threading.Thread(target=self._pg_loop, daemon=True)
        self._pg_thread.start()
        return True

    def stop_pg_archive(self):
        self._stop_pg.set()
        return True

    # ── SQL Server TLOG Backup ──────────────────────────────────

    def _mssql_loop(self):
        self._mssql_running = True
        logger.info("MSSQL TLOG backup loop started (interval=%ds, fake=%s)", self._mssql_interval, self._mssql_fake)
        try:
            while not self._stop_mssql.is_set():
                try:
                    result = self._run_mssql_tlog_backup()
                    self._mssql_last = datetime.now()
                    self._mssql_log.append(f"[{self._mssql_last}] TLOG backup: {result}")
                    logger.info("MSSQL TLOG backup completed: %s", result)
                except Exception as e:
                    logger.error("MSSQL TLOG backup failed: %s", e, exc_info=True)
                    self._mssql_log.append(f"[{datetime.now()}] TLOG backup ERROR: {e}")
                self._stop_mssql.wait(self._mssql_interval)
        finally:
            self._mssql_running = False

    def _run_mssql_tlog_backup(self):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        results = []
        try:
            import pyodbc
        except ImportError:
            pyodbc = None

        for node_id in [1, 2, 3]:
            node = f"sql{node_id}"
            info = MSSQL_CONFIG["nodes"][node]
            for db in DATABASES:
                if self._mssql_fake:
                    backup_dest = "N'/var/opt/mssql/external_backup/_discard.trn'"
                else:
                    backup_dest = f"N'/var/opt/mssql/external_backup/{db}_tlog_{ts}.trn'"

                sql = (
                    f"BACKUP LOG [{db}] TO DISK = {backup_dest} "
                    f"WITH NOFORMAT, NOINIT, NAME = N'{db}-TLOG Backup', "
                    f"SKIP, NOREWIND, NOUNLOAD, STATS = 10"
                )
                label = "Backup (Fake)" if self._mssql_fake else "Backup"

                if pyodbc is not None:
                    cmd_text = f"BACKUP LOG [{db}] on {node} ({info['host']},{info['port']})"
                    cmd_entry = command_log.add(label, cmd_text)
                    try:
                        conn_str = (
                            f"DRIVER={{{MSSQL_CONFIG['driver']}}};"
                            f"SERVER={info['host']},{info['port']};"
                            f"UID={MSSQL_CONFIG['sa_user']};PWD={MSSQL_CONFIG['sa_password']};"
                            f"Database=master;TrustServerCertificate=yes;Encrypt=no;LoginTimeout=15;"
                        )
                        conn = pyodbc.connect(conn_str, autocommit=True, timeout=30)
                        cur = conn.cursor()
                        cur.execute(sql)
                        cur.close()
                        conn.close()
                        results.append(f"{node}/{db}: OK")
                        command_log.succeed(cmd_entry)
                    except Exception as e:
                        err = str(e)[:100]
                        results.append(f"{node}/{db}: {err}")
                        command_log.fail(cmd_entry, err)
                    continue

                cmd = [
                    "docker", "exec", node,
                    "/opt/mssql-tools18/bin/sqlcmd",
                    "-S", "localhost",
                    "-U", MSSQL_CONFIG["sa_user"],
                    "-P", MSSQL_CONFIG["sa_password"],
                    "-C",
                    "-Q", sql,
                ]
                cmd_text = f"docker exec {node} sqlcmd -Q \"{sql[:100]}...\""
                cmd_entry = command_log.add(label, cmd_text)
                try:
                    _run_cmd(cmd, timeout=120)
                    results.append(f"{node}/{db}: OK")
                    command_log.succeed(cmd_entry)
                except Exception as e:
                    err = str(e)[:100]
                    results.append(f"{node}/{db}: {err}")
                    command_log.fail(cmd_entry, err)

        return "; ".join(results)

    def start_mssql_backup(self, interval_seconds=300, fake=False):
        if self._mssql_running:
            logger.warning("MSSQL TLOG backup already running; ignoring duplicate start")
            return False
        self._mssql_interval = interval_seconds
        self._mssql_fake = fake
        self._stop_mssql.clear()
        self._mssql_thread = threading.Thread(target=self._mssql_loop, daemon=True)
        self._mssql_thread.start()
        return True

    def stop_mssql_backup(self):
        self._stop_mssql.set()
        return True

    # ── Status ──────────────────────────────────────────────────

    def get_status(self):
        return {
            "pg_archive_running": self._pg_running and not self._stop_pg.is_set(),
            "pg_interval": self._pg_interval,
            "pg_fake": self._pg_fake,
            "pg_last": str(self._pg_last) if self._pg_last else None,
            "pg_log": self._pg_log[-10:],
            "mssql_backup_running": self._mssql_running and not self._stop_mssql.is_set(),
            "mssql_interval": self._mssql_interval,
            "mssql_fake": self._mssql_fake,
            "mssql_last": str(self._mssql_last) if self._mssql_last else None,
            "mssql_log": self._mssql_log[-10:],
        }


backup_manager = BackupManager()
