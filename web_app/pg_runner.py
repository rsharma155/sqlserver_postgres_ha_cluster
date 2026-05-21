"""
PostgreSQL CRUD load generator.

Simulates realistic application traffic across 5 databases
on a Patroni HA cluster behind HAProxy.

Each worker thread:
  - Opens a new connection per operation.
  - Randomly selects a database, CRUD type, then a specific operation.
  - Calls pre-deployed stored functions (crud_*) instead of inline SQL.
  - Each type (C/R/U/D) has 2+ operations; some use complex JOINs.
  - Read-heavy distribution (R=60%, C/U/D=~13% each).
  - Reports per-operation success/failure via callback.
  - Logs every command to the in-memory command log for the UI.

Entry point: run_pg_crud(seconds, threads, app_names, ...)
"""

import random
import threading
import time
from collections import defaultdict
from datetime import datetime
from config import PG_CONFIG, DATABASES
from command_log import command_log
from app_logger import logger

try:
    import psycopg2
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary", "--quiet"])
    import psycopg2

OPS = {
    "hotel_booking": {
        "C": [
            {"fn": "SELECT crud_hotel_create_reservation(%s, %s)",
             "gen": lambda: (random.randint(1, 4), "load_test"),
             "label": "CREATE reservation"},
            {"fn": "SELECT crud_hotel_create_review(%s, %s)",
             "gen": lambda: (random.randint(1, 5), random.choice(["Great stay!","Needs improvement","Wonderful","Average","Excellent"])),
             "label": "CREATE review"},
        ],
        "R": [
            {"fn": "SELECT crud_hotel_read_guest(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "READ guest"},
            {"fn": "SELECT crud_hotel_read_invoice(%s)",
             "gen": lambda: (random.randint(1, 100000),),
             "label": "READ invoice (JOIN)"},
            {"fn": "SELECT crud_hotel_read_room(%s)",
             "gen": lambda: (random.randint(1, 100),),
             "label": "READ room (JOIN)"},
        ],
        "U": [
            {"fn": "SELECT crud_hotel_update_housekeeping(%s, %s)",
             "gen": lambda: (random.randint(1, 30000), random.choice(["pending","in_progress","completed"])),
             "label": "UPDATE housekeeping"},
            {"fn": "SELECT crud_hotel_update_reservation(%s, %s)",
             "gen": lambda: (random.randint(1, 100000), random.choice(["checked_in","checked_out","cancelled"])),
             "label": "UPDATE reservation"},
        ],
        "D": [
            {"fn": "SELECT crud_hotel_delete_housekeeping(%s)",
             "gen": lambda: (random.randint(1, 30000),),
             "label": "DELETE housekeeping"},
            {"fn": "SELECT crud_hotel_delete_review(%s)",
             "gen": lambda: (random.randint(1, 30000),),
             "label": "DELETE review"},
        ],
    },
    "e_commerce": {
        "C": [
            {"fn": "SELECT crud_ecom_create_product(%s, %s, %s, %s)",
             "gen": lambda: (f"SKU-LOAD-{random.randint(100000, 999999)}",
                             f"Load Product {random.randint(1, 9999)}",
                             round(random.uniform(10, 500), 2),
                             round(random.uniform(5, 250), 2)),
             "label": "CREATE product"},
            {"fn": "SELECT crud_ecom_create_order()",
             "gen": lambda: (),
             "label": "CREATE order (complex)"},
        ],
        "R": [
            {"fn": "SELECT crud_ecom_read_product(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "READ product (JOIN)"},
            {"fn": "SELECT crud_ecom_read_order(%s)",
             "gen": lambda: (random.randint(1, 100000),),
             "label": "READ order (JOIN+agg)"},
            {"fn": "SELECT crud_ecom_read_customer(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "READ customer (JOIN+agg)"},
        ],
        "U": [
            {"fn": "SELECT crud_ecom_update_review(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "UPDATE review"},
            {"fn": "SELECT crud_ecom_update_order(%s, %s)",
             "gen": lambda: (random.randint(1, 100000), random.choice(["processing","shipped","delivered","cancelled"])),
             "label": "UPDATE order"},
        ],
        "D": [
            {"fn": "SELECT crud_ecom_delete_review(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "DELETE review"},
            {"fn": "SELECT crud_ecom_delete_cart(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "DELETE cart"},
        ],
    },
    "erp_system": {
        "C": [
            {"fn": "SELECT crud_erp_create_timesheet(%s, %s, %s)",
             "gen": lambda: (random.randint(1, 10000), random.randint(1, 200000), round(random.uniform(1, 12), 2)),
             "label": "CREATE timesheet"},
            {"fn": "SELECT crud_erp_create_project(%s, %s)",
             "gen": lambda: (f"Load Project {random.randint(1, 999)}", round(random.uniform(10000, 500000), 2)),
             "label": "CREATE project (complex)"},
        ],
        "R": [
            {"fn": "SELECT crud_erp_read_employee(%s)",
             "gen": lambda: (random.randint(1, 10000),),
             "label": "READ employee"},
            {"fn": "SELECT crud_erp_read_employee_detail(%s)",
             "gen": lambda: (random.randint(1, 10000),),
             "label": "READ employee (3-table JOIN)"},
            {"fn": "SELECT crud_erp_read_project(%s)",
             "gen": lambda: (random.randint(1, 5000),),
             "label": "READ project (JOIN+agg)"},
        ],
        "U": [
            {"fn": "SELECT crud_erp_update_timesheet(%s)",
             "gen": lambda: (random.randint(1, 200000),),
             "label": "UPDATE timesheet"},
            {"fn": "SELECT crud_erp_update_employee(%s, %s)",
             "gen": lambda: (random.randint(1, 10000), round(random.uniform(35000, 160000), 2)),
             "label": "UPDATE employee salary"},
        ],
        "D": [
            {"fn": "SELECT crud_erp_delete_timesheet(%s)",
             "gen": lambda: (random.randint(1, 200000),),
             "label": "DELETE timesheet"},
            {"fn": "SELECT crud_erp_delete_leave(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "DELETE leave request"},
        ],
    },
    "hrm_tool": {
        "C": [
            {"fn": "SELECT crud_hrm_create_enrollment(%s, %s, %s)",
             "gen": lambda: (random.randint(1, 500), random.randint(1, 50000), random.choice(["enrolled","in_progress"])),
             "label": "CREATE enrollment"},
            {"fn": "SELECT crud_hrm_create_attendance(%s, %s)",
             "gen": lambda: (random.randint(1, 50000), round(random.uniform(4, 12), 2)),
             "label": "CREATE attendance"},
        ],
        "R": [
            {"fn": "SELECT crud_hrm_read_employee(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "READ employee"},
            {"fn": "SELECT crud_hrm_read_enrollment(%s)",
             "gen": lambda: (random.randint(1, 10000),),
             "label": "READ enrollment (JOIN)"},
            {"fn": "SELECT crud_hrm_read_organization(%s)",
             "gen": lambda: (random.randint(1, 10),),
             "label": "READ organization (JOIN+agg)"},
        ],
        "U": [
            {"fn": "SELECT crud_hrm_update_enrollment(%s, %s)",
             "gen": lambda: (random.randint(1, 10000), random.choice(["completed","dropped"])),
             "label": "UPDATE enrollment"},
            {"fn": "SELECT crud_hrm_update_employee(%s, %s)",
             "gen": lambda: (random.randint(1, 50000), random.choice(["active","inactive","terminated"])),
             "label": "UPDATE employee status"},
        ],
        "D": [
            {"fn": "SELECT crud_hrm_delete_enrollment(%s)",
             "gen": lambda: (random.randint(1, 10000),),
             "label": "DELETE enrollment"},
            {"fn": "SELECT crud_hrm_delete_attendance(%s)",
             "gen": lambda: (random.randint(1, 100000),),
             "label": "DELETE attendance"},
        ],
    },
    "department_store": {
        "C": [
            {"fn": "SELECT crud_dept_create_movement(%s, %s, %s, %s)",
             "gen": lambda: (random.randint(1, 100000), random.choice(["inbound","outbound","adjustment","transfer"]),
                             random.randint(1, 50), random.choice(["purchase","sale","return","stock_count"])),
             "label": "CREATE movement"},
        ],
        "R": [
            {"fn": "SELECT crud_dept_read_product(%s)",
             "gen": lambda: (random.randint(1, 50000),),
             "label": "READ product"},
            {"fn": "SELECT crud_dept_read_inventory(%s)",
             "gen": lambda: (random.randint(1, 100000),),
             "label": "READ inventory (JOIN)"},
            {"fn": "SELECT crud_dept_read_promotion(%s)",
             "gen": lambda: (random.randint(1, 5000),),
             "label": "READ promotion (JOIN)"},
        ],
        "U": [
            {"fn": "SELECT crud_dept_update_movement(%s)",
             "gen": lambda: (random.randint(1, 100000),),
             "label": "UPDATE movement"},
            {"fn": "SELECT crud_dept_update_product(%s, %s)",
             "gen": lambda: (random.randint(1, 50000), round(random.uniform(5, 500), 2)),
             "label": "UPDATE product price"},
        ],
        "D": [
            {"fn": "SELECT crud_dept_delete_movement(%s)",
             "gen": lambda: (random.randint(1, 100000),),
             "label": "DELETE movement"},
            {"fn": "SELECT crud_dept_delete_promotion(%s)",
             "gen": lambda: (random.randint(1, 5000),),
             "label": "DELETE promotion"},
        ],
    },
}

CRUD_TYPES = ["C", "R", "U", "D"]
CRUD_WEIGHTS = [1, 3, 1, 1]


def run_pg_crud(seconds, threads, app_names, host=None, port=None, user=None, password=None, status_callback=None, stop_event=None):
    if stop_event is None:
        stop_event = threading.Event()

    cfg = {
        "host": host or PG_CONFIG["host"],
        "port": port or PG_CONFIG["port"],
        "user": user or PG_CONFIG["user"],
        "password": password or PG_CONFIG["password"],
    }

    names = [f"crud-loader-{i}" for i in range(1, app_names + 1)]
    stats_lock = threading.Lock()
    global_stats = defaultdict(lambda: {"attempted": 0, "succeeded": 0, "failed": 0})
    failed_ops = []
    failed_ops_lock = threading.Lock()

    def build_connection(app_name, database):
        conn = psycopg2.connect(
            host=cfg["host"], port=cfg["port"], user=cfg["user"],
            password=cfg["password"], dbname=database,
            application_name=app_name, connect_timeout=5,
            options="-c statement_timeout=30000",
        )
        conn.autocommit = True
        return conn

    def worker(thread_id, app_name, duration):
        deadline = time.time() + duration
        local_stats = defaultdict(lambda: {"attempted": 0, "succeeded": 0, "failed": 0})

        while not stop_event.is_set() and time.time() < deadline:
            database = random.choice(DATABASES)
            ops = OPS[database]
            crud_type = random.choices(CRUD_TYPES, weights=CRUD_WEIGHTS, k=1)[0]
            op_list = ops.get(crud_type, [])
            if not op_list:
                continue
            op = random.choice(op_list)
            key = f"{database}.{crud_type}"
            local_stats[key]["attempted"] += 1
            conn = None
            success = False
            err_msg = ""

            params = op["gen"]()
            try:
                fn_preview = op["fn"]
                if len(params) > 0:
                    fn_preview = op["fn"] % tuple(
                        str(p) if not isinstance(p, int) else str(p) for p in params
                    )
            except Exception:
                fn_preview = op["fn"]
            cmd_entry = command_log.add("PG CRUD", f"[{database}] {op['label']} | {fn_preview[:120]}")

            try:
                conn = build_connection(app_name, database)
                cursor = conn.cursor()
                cursor.execute(op["fn"], params)
                try:
                    cursor.fetchone()
                except Exception:
                    pass
                cursor.close()
                local_stats[key]["succeeded"] += 1
                success = True
                command_log.succeed(cmd_entry)
            except Exception as e:
                err_msg = str(e)
                local_stats[key]["failed"] += 1
                command_log.fail(cmd_entry, err_msg)
                logger.warning("PG CRUD fail [%s] %s: %s", database, op["label"], err_msg)
                with failed_ops_lock:
                    failed_ops.append({
                        "db": database, "op": op["label"], "error": err_msg,
                        "thread": thread_id, "time": datetime.now().strftime("%H:%M:%S"),
                    })
            finally:
                if conn:
                    try:
                        conn.close()
                    except Exception:
                        pass

            if status_callback:
                status_callback({
                    "db": database, "op": op["label"],
                    "success": success, "thread": thread_id, "app": app_name,
                })
            time.sleep(random.uniform(0.01, 0.05))

        with stats_lock:
            for key, v in local_stats.items():
                global_stats[key]["attempted"] += v["attempted"]
                global_stats[key]["succeeded"] += v["succeeded"]
                global_stats[key]["failed"] += v["failed"]

    thread_list = []
    for i in range(threads):
        t = threading.Thread(target=worker, args=(i, random.choice(names), seconds), daemon=True)
        thread_list.append(t)
        t.start()

    start = time.time()
    try:
        for t in thread_list:
            remaining = max(0, seconds - (time.time() - start))
            t.join(timeout=remaining)
    except KeyboardInterrupt:
        stop_event.set()

    stop_event.set()
    elapsed = time.time() - start

    total_attempted = total_succeeded = total_failed = 0
    for key, s in global_stats.items():
        total_attempted += s["attempted"]
        total_succeeded += s["succeeded"]
        total_failed += s["failed"]

    return {
        "elapsed": round(elapsed, 1),
        "stats": dict(global_stats),
        "total_attempted": total_attempted,
        "total_succeeded": total_succeeded,
        "total_failed": total_failed,
        "throughput": round(total_attempted / elapsed, 1) if elapsed else 0,
        "failed_ops": failed_ops[:500],
    }
