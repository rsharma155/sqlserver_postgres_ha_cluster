#!/usr/bin/env python3
"""
PostgreSQL CRUD Load Generator for Patroni HA Cluster
Performs random CRUD operations across 5 databases (hotel_booking, e_commerce,
erp_system, hrm_tool, department_store) with configurable threads and app names.

Usage:
    python pg_crud_load.py --seconds 60 --threads 4 --app-names 5
    python pg_crud_load.py -s 30 -t 8 -n 3

Dependencies:
    pip install psycopg2-binary
"""

import argparse
import random
import signal
import sys
import threading
import time
from collections import defaultdict
from datetime import datetime

try:
    import psycopg2
except ImportError:
    import subprocess
    print("[*] psycopg2 not found. Auto-installing psycopg2-binary...")
    try:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "psycopg2-binary", "--quiet"]
        )
        import psycopg2
        print("[+] psycopg2-binary installed successfully.")
    except Exception:
        print("[-] Auto-install failed. Try manually: pip install psycopg2-binary")
        sys.exit(1)

# ---------------------------------------------------------------------------
# Database Configuration
# ---------------------------------------------------------------------------
DB_CONFIG = {
    "host": "localhost",
    "port": 5000,
    "user": "postgres",
    "password": "postgres123",
}

# 10 CRUD load test users created by create_users.sql.
# Used when --users flag is passed to rotate across users.
CRUD_USERS = [
    {"user": "hotel_agent",   "password": "TestP@ss1!"},
    {"user": "ecom_manager",  "password": "TestP@ss2!"},
    {"user": "erp_operator",  "password": "TestP@ss3!"},
    {"user": "hr_manager",    "password": "TestP@ss4!"},
    {"user": "store_clerk",   "password": "TestP@ss5!"},
    {"user": "hotel_guest",   "password": "TestP@ss6!"},
    {"user": "ecom_shopper",  "password": "TestP@ss7!"},
    {"user": "erp_finance",   "password": "TestP@ss8!"},
    {"user": "hr_recruiter",  "password": "TestP@ss9!"},
    {"user": "store_manager", "password": "TestP@ss10!"},
]

DATABASES = [
    "hotel_booking",
    "e_commerce",
    "erp_system",
    "hrm_tool",
    "department_store",
]

# ---------------------------------------------------------------------------
# CRUD Operation Definitions
# Each entry has:
#   "sql"  - SQL template with %s placeholders
#   "gen"  - callable that returns a tuple of parameters
#
# The gen lambdas are evaluated at invocation time so they use module-level
# random and datetime correctly.
# ---------------------------------------------------------------------------
OPS = {
    "hotel_booking": {
        "C": {
            "sql": "INSERT INTO housekeeping_tasks (room_id, assigned_to, task_type, status) VALUES (%s, %s, %s, 'pending') RETURNING task_id",
            "gen": lambda: (
                random.randint(1, 100),
                random.choice(["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace"]),
                random.choice(["cleaning", "linen_change", "deep_clean", "turndown", "inspection"]),
            ),
        },
        "R": {
            "sql": "SELECT guest_id, first_name, last_name, email FROM guests WHERE guest_id = %s",
            "gen": lambda: (random.randint(1, 50000),),
        },
        "U": {
            "sql": "UPDATE housekeeping_tasks SET status = %s, notes = CONCAT(COALESCE(notes, ''), ' | auto-updated at ', %s::text) WHERE task_id = %s",
            "gen": lambda: (
                random.choice(["pending", "in_progress", "completed"]),
                datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                random.randint(1, 30000),
            ),
        },
        "D": {
            "sql": "DELETE FROM housekeeping_tasks WHERE task_id = %s RETURNING task_id",
            "gen": lambda: (random.randint(1, 30000),),
        },
    },
    "e_commerce": {
        "C": {
            "sql": "INSERT INTO product_reviews (product_id, customer_id, rating, title, review_text) VALUES (%s, %s, %s, %s, %s) RETURNING review_id",
            "gen": lambda: (
                random.randint(1, 50000),
                random.randint(1, 50000),
                random.randint(1, 5),
                random.choice(["Great!", "OK", "Bad", "Excellent", "Poor", "Amazing", "Terrible", "Good value"]),
                random.choice(["Nice product", "Could be better", "Love it", "Not bad", "Highly recommended", "Does the job", "Perfect"]),
            ),
        },
        "R": {
            "sql": "SELECT product_id, name, unit_price FROM products WHERE product_id = %s",
            "gen": lambda: (random.randint(1, 50000),),
        },
        "U": {
            "sql": "UPDATE product_reviews SET helpful_count = helpful_count + 1 WHERE review_id = %s",
            "gen": lambda: (random.randint(1, 50000),),
        },
        "D": {
            "sql": "DELETE FROM product_reviews WHERE review_id = %s RETURNING review_id",
            "gen": lambda: (random.randint(1, 50000),),
        },
    },
    "erp_system": {
        "C": {
            "sql": "INSERT INTO timesheets (employee_id, task_id, work_date, hours, description) VALUES (%s, %s, %s, %s, %s) RETURNING timesheet_id",
            "gen": lambda: (
                random.randint(1, 10000),
                random.randint(1, 100000),
                datetime.now().date(),
                round(random.uniform(1, 12), 2),
                "Load test entry",
            ),
        },
        "R": {
            "sql": "SELECT employee_id, first_name, last_name, email FROM employees WHERE employee_id = %s",
            "gen": lambda: (random.randint(1, 10000),),
        },
        "U": {
            "sql": "UPDATE timesheets SET approved = TRUE, description = CONCAT(description, ' | reviewed') WHERE timesheet_id = %s AND approved = FALSE",
            "gen": lambda: (random.randint(1, 200000),),
        },
        "D": {
            "sql": "DELETE FROM timesheets WHERE timesheet_id = %s RETURNING timesheet_id",
            "gen": lambda: (random.randint(1, 200000),),
        },
    },
    "hrm_tool": {
        "C": {
            "sql": "INSERT INTO training_enrollments (program_id, employee_id, status) VALUES (%s, %s, %s) RETURNING enrollment_id",
            "gen": lambda: (
                random.randint(1, 500),
                random.randint(1, 50000),
                random.choice(["enrolled", "in_progress"]),
            ),
        },
        "R": {
            "sql": "SELECT employee_id, first_name, last_name, email FROM employees_hrm WHERE employee_id = %s",
            "gen": lambda: (random.randint(1, 50000),),
        },
        "U": {
            "sql": "UPDATE training_enrollments SET status = %s WHERE enrollment_id = %s",
            "gen": lambda: (random.choice(["completed", "dropped"]), random.randint(1, 10000)),
        },
        "D": {
            "sql": "DELETE FROM training_enrollments WHERE enrollment_id = %s RETURNING enrollment_id",
            "gen": lambda: (random.randint(1, 10000),),
        },
    },
    "department_store": {
        "C": {
            "sql": "INSERT INTO inventory_movements (inventory_id, movement_type, quantity, reference_type, notes) VALUES (%s, %s, %s, %s, %s) RETURNING movement_id",
            "gen": lambda: (
                random.randint(1, 100000),
                random.choice(["inbound", "outbound", "adjustment", "transfer"]),
                random.randint(1, 50),
                random.choice(["purchase", "sale", "return", "stock_count"]),
                "Load test movement",
            ),
        },
        "R": {
            "sql": "SELECT product_id, name, unit_price FROM products_store WHERE product_id = %s",
            "gen": lambda: (random.randint(1, 50000),),
        },
        "U": {
            "sql": "UPDATE inventory_movements SET notes = CONCAT(notes, ' | updated ', %s::text) WHERE movement_id = %s",
            "gen": lambda: (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), random.randint(1, 100000)),
        },
        "D": {
            "sql": "DELETE FROM inventory_movements WHERE movement_id = %s RETURNING movement_id",
            "gen": lambda: (random.randint(1, 100000),),
        },
    },
}

CRUD_TYPES = ["C", "R", "U", "D"]
CRUD_WEIGHTS = [1, 3, 1, 1]  # Read-heavy distribution

# ---------------------------------------------------------------------------
# Shared State
# ---------------------------------------------------------------------------
stop_event = threading.Event()
stats_lock = threading.Lock()
print_lock = threading.Lock()
global_stats = defaultdict(lambda: {"attempted": 0, "succeeded": 0, "failed": 0})


# ---------------------------------------------------------------------------
# Connection Helper
# ---------------------------------------------------------------------------
def build_connection(app_name, database, crud_user=None):
    u = crud_user["user"] if crud_user else DB_CONFIG["user"]
    pwd = crud_user["password"] if crud_user else DB_CONFIG["password"]
    conn = psycopg2.connect(
        host=DB_CONFIG["host"],
        port=DB_CONFIG["port"],
        user=u,
        password=pwd,
        dbname=database,
        application_name=app_name,
        connect_timeout=5,
        options="-c statement_timeout=30000",
    )
    conn.autocommit = True
    return conn


# ---------------------------------------------------------------------------
# Worker Thread
# ---------------------------------------------------------------------------
CRUD_LABEL = {"C": "CREATE", "R": "READ", "U": "UPDATE", "D": "DELETE"}


def worker(thread_id, app_name, duration, crud_user=None):
    deadline = time.time() + duration
    local_stats = defaultdict(lambda: {"attempted": 0, "succeeded": 0, "failed": 0})
    my_user_label = crud_user["user"] if crud_user else DB_CONFIG["user"]

    while not stop_event.is_set() and time.time() < deadline:
        database = random.choice(DATABASES)
        ops = OPS[database]
        crud_type = random.choices(CRUD_TYPES, weights=CRUD_WEIGHTS, k=1)[0]
        op = ops[crud_type]

        key = f"{database}.{crud_type}"
        local_stats[key]["attempted"] += 1

        conn = None
        success = False
        try:
            conn = build_connection(app_name, database, crud_user)
            cursor = conn.cursor()
            params = op["gen"]()
            cursor.execute(op["sql"], params)
            cursor.fetchone()
            cursor.close()
            local_stats[key]["succeeded"] += 1
            success = True
        except Exception as e:
            local_stats[key]["failed"] += 1
            err_msg = str(e).strip().split("\n")[0][:80]
        finally:
            if conn is not None:
                try:
                    conn.close()
                except Exception:
                    pass

        result = "OK" if success else "FAIL"
        target_table = op["sql"].split(None, 2)[1]
        with print_lock:
            print(
                f"[{result}] DB={database:20s} OP={CRUD_LABEL[crud_type]:6s} "
                f"TABLE={target_table:25s} USER={my_user_label:20s} "
                f"APP={app_name:20s} THR={thread_id:2d}",
                flush=True,
            )

        time.sleep(random.uniform(0.01, 0.05))

    with stats_lock:
        for key, v in local_stats.items():
            global_stats[key]["attempted"] += v["attempted"]
            global_stats[key]["succeeded"] += v["succeeded"]
            global_stats[key]["failed"] += v["failed"]


# ---------------------------------------------------------------------------
# Signal Handler
# ---------------------------------------------------------------------------
def signal_handler(signum, frame):
    if not stop_event.is_set():
        print("\n[!] Shutdown requested. Stopping workers... (press Ctrl+C again to force)")
        stop_event.set()


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
def print_summary(elapsed):
    print("\n" + "=" * 74)
    print("  CRUD LOAD TEST SUMMARY")
    print("=" * 74)
    total_attempted = total_succeeded = total_failed = 0

    for key in sorted(global_stats.keys()):
        s = global_stats[key]
        total_attempted += s["attempted"]
        total_succeeded += s["succeeded"]
        total_failed += s["failed"]
        db, op = key.split(".")
        pct = (s["succeeded"] / s["attempted"] * 100) if s["attempted"] else 0
        print(f"  {db:20s} {op:1s}  |  Attempted: {s['attempted']:6d}  |  "
              f"Succeeded: {s['succeeded']:6d}  |  Failed: {s['failed']:4d}  |  "
              f"Success Rate: {pct:5.1f}%")

    print("=" * 74)
    pct = (total_succeeded / total_attempted * 100) if total_attempted else 0
    ops_sec = total_attempted / elapsed if elapsed else 0
    print(f"  TOTAL {'':20s} |  Attempted: {total_attempted:6d}  |  "
          f"Succeeded: {total_succeeded:6d}  |  Failed: {total_failed:4d}  |  "
          f"Success Rate: {pct:5.1f}%")
    print(f"  Duration: {elapsed:.1f}s  |  Throughput: {ops_sec:.1f} ops/sec")
    print("=" * 74)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="PostgreSQL CRUD Load Generator for Patroni HA Cluster",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python pg_crud_load.py --seconds 30 --threads 4 --app-names 3\n"
            "  python pg_crud_load.py -s 60 -t 8 -n 5\n"
        ),
    )
    parser.add_argument("-s", "--seconds", type=int, default=30,
                        help="Duration in seconds (default: 30)")
    parser.add_argument("-t", "--threads", type=int, default=2,
                        help="Number of worker threads (default: 2)")
    parser.add_argument("-n", "--app-names", type=int, default=3,
                        help="Number of random application names to simulate (default: 3)")
    parser.add_argument("--host", default=DB_CONFIG["host"],
                        help=f"Database host (default: {DB_CONFIG['host']})")
    parser.add_argument("--port", type=int, default=DB_CONFIG["port"],
                        help=f"Database port (default: {DB_CONFIG['port']})")
    parser.add_argument("--user", default=DB_CONFIG["user"],
                        help=f"Database user (default: {DB_CONFIG['user']})")
    parser.add_argument("--password", default=DB_CONFIG["password"],
                        help="Database password")
    parser.add_argument("--users", action="store_true",
                        help="Rotate across 10 CRUD test users instead of using --user")
    args = parser.parse_args()

    DB_CONFIG["host"] = args.host
    DB_CONFIG["port"] = args.port
    DB_CONFIG["user"] = args.user
    DB_CONFIG["password"] = args.password

    # When --users is set, each worker picks a random user from the
    # 10 CRUD test users instead of using the single --user credential.
    crud_user_pool = list(CRUD_USERS) if args.users else None

    seconds = max(1, args.seconds)
    num_threads = max(1, args.threads)
    num_app_names = max(1, args.app_names)

    app_names = [f"crud-loader-{i}" for i in range(1, num_app_names + 1)]

    print(f"[*] Starting CRUD load test:")
    print(f"    Duration: {seconds}s")
    print(f"    Threads : {num_threads}")
    print(f"    App Names ({num_app_names}): {', '.join(app_names)}")
    print(f"    Host    : {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    if crud_user_pool:
        print(f"    Users   : {len(crud_user_pool)} CRUD test users (rotated)")
    else:
        print(f"    User    : {DB_CONFIG['user']}")
    print(f"    Password: {'*' * len(DB_CONFIG['password'])}")
    print(f"    Databases ({len(DATABASES)}): {', '.join(DATABASES)}")
    print(f"    ── Live operation log ──")
    print()

    signal.signal(signal.SIGINT, signal_handler)

    threads = []
    for i in range(num_threads):
        t_app_name = random.choice(app_names)
        my_crud_user = random.choice(crud_user_pool) if crud_user_pool else None
        t = threading.Thread(
            target=worker, args=(i, t_app_name, seconds, my_crud_user), daemon=True
        )
        threads.append(t)
        t.start()

    start = time.time()
    try:
        remaining = seconds
        for t in threads:
            t.join(timeout=remaining)
            remaining = max(0, seconds - (time.time() - start))
    except KeyboardInterrupt:
        stop_event.set()

    stop_event.set()
    elapsed = time.time() - start
    print_summary(elapsed)


if __name__ == "__main__":
    main()
