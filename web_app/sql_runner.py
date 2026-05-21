"""
SQL Server CRUD load generator.

Simulates realistic application traffic across 5 databases
on a 3-node Always On Availability Group.

Each worker thread:
  - Uses pyodbc with the auto-detected ODBC driver.
  - Randomly selects a database, node, CRUD type, then a specific operation.
  - Calls pre-deployed stored procedures (crud_*) instead of inline SQL.
  - Each type (C/R/U) has 2+ operations; some use complex JOINs.
  - Read-heavy distribution (R=60%, C/U=~20% each).
  - Reports per-operation success/failure via callback.
  - Logs every command to the in-memory command log for the UI.

Entry point: run_sql_crud(seconds, threads, users_per_thread, ...)
"""

import random
import threading
import time
from collections import defaultdict
from datetime import datetime
from config import MSSQL_CONFIG, DATABASES
from command_log import command_log
from app_logger import logger

try:
    import pyodbc
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyodbc", "--quiet"])
    import pyodbc


_LOGIN_ERROR_CODES = ("28000", "08001", "08004", "08007", "4060", "927", "08S01", "10054", "258")

# Global health cache to avoid spamming broken nodes
# Format: {(node, database): {"status": "ok", "last_check": timestamp}}
node_health = {}
health_lock = threading.Lock()

def _is_login_error(err_msg):
    return any(code in err_msg for code in _LOGIN_ERROR_CODES) or "restore" in err_msg.lower() or "broken" in err_msg.lower() or "timeout" in err_msg.lower()


def build_conn_str(database, node="sql1"):
    info = MSSQL_CONFIG["nodes"][node]
    return (
        f"DRIVER={{{MSSQL_CONFIG['driver']}}};"
        f"SERVER={info['host']},{info['port']};"
        f"UID={MSSQL_CONFIG['sa_user']};PWD={MSSQL_CONFIG['sa_password']};"
        f"Database={database};TrustServerCertificate=yes;"
        f"ConnectRetryCount=3;ConnectRetryInterval=5;"
    )


OPS = {
    "hotel_booking": {
        "R": [
            ("crud_hotel_read_guest",
             lambda c: c.execute("EXEC crud_hotel_read_guest @guest_id=?", random.randint(1, 50000))),
            ("crud_hotel_read_invoice (JOIN)",
             lambda c: c.execute("EXEC crud_hotel_read_invoice @invoice_id=?", random.randint(1, 100000))),
            ("crud_hotel_read_room (JOIN)",
             lambda c: c.execute("EXEC crud_hotel_read_room @room_id=?", random.randint(1, 100))),
        ],
        "C": [
            ("crud_hotel_create_reservation",
             lambda c: c.execute("EXEC crud_hotel_create_reservation")),
            ("crud_hotel_create_review",
             lambda c: c.execute("EXEC crud_hotel_create_review @rating=?, @comment=?",
                                 random.randint(1, 5),
                                 random.choice(["Great stay!","Needs improvement","Wonderful","Average","Excellent"]))),
        ],
        "U": [
            ("crud_hotel_update_housekeeping",
             lambda c: c.execute("EXEC crud_hotel_update_housekeeping @task_id=?, @status=?",
                                 random.randint(1, 30000),
                                 random.choice(["pending","in_progress","completed"]))),
            ("crud_hotel_update_reservation",
             lambda c: c.execute("EXEC crud_hotel_update_reservation @res_id=?, @status=?",
                                 random.randint(1, 100000),
                                 random.choice(["checked_in","checked_out","cancelled"]))),
        ],
    },
    "e_commerce": {
        "R": [
            ("crud_ecom_read_product (JOIN)",
             lambda c: c.execute("EXEC crud_ecom_read_product @product_id=?", random.randint(1, 50000))),
            ("crud_ecom_read_order (JOIN+agg)",
             lambda c: c.execute("EXEC crud_ecom_read_order @order_id=?", random.randint(1, 100000))),
            ("crud_ecom_read_customer (JOIN+agg)",
             lambda c: c.execute("EXEC crud_ecom_read_customer @customer_id=?", random.randint(1, 50000))),
        ],
        "C": [
            ("crud_ecom_create_product",
             lambda c: c.execute("EXEC crud_ecom_create_product @sku=?, @name=?, @price=?, @cost=?",
                                 f"SKU-LOAD-{random.randint(100000, 999999)}",
                                 f"Load Product {random.randint(1, 9999)}",
                                 round(random.uniform(10, 500), 2),
                                 round(random.uniform(5, 250), 2))),
            ("crud_ecom_create_order (complex)",
             lambda c: c.execute("EXEC crud_ecom_create_order")),
        ],
        "U": [
            ("crud_ecom_update_review",
             lambda c: c.execute("EXEC crud_ecom_update_review @review_id=?", random.randint(1, 50000))),
            ("crud_ecom_update_order",
             lambda c: c.execute("EXEC crud_ecom_update_order @order_id=?, @status=?",
                                 random.randint(1, 100000),
                                 random.choice(["processing","shipped","delivered","cancelled"]))),
        ],
    },
    "erp_system": {
        "R": [
            ("crud_erp_read_employee",
             lambda c: c.execute("EXEC crud_erp_read_employee @employee_id=?", random.randint(1, 10000))),
            ("crud_erp_read_employee_detail (3-table JOIN)",
             lambda c: c.execute("EXEC crud_erp_read_employee_detail @employee_id=?", random.randint(1, 10000))),
            ("crud_erp_read_project (JOIN+agg)",
             lambda c: c.execute("EXEC crud_erp_read_project @project_id=?", random.randint(1, 5000))),
        ],
        "C": [
            ("crud_erp_create_timesheet",
             lambda c: c.execute("EXEC crud_erp_create_timesheet @employee_id=?, @task_id=?, @hours=?",
                                 random.randint(1, 10000), random.randint(1, 200000),
                                 round(random.uniform(1, 12), 2))),
            ("crud_erp_create_project (complex)",
             lambda c: c.execute("EXEC crud_erp_create_project @name=?, @budget=?",
                                 f"Load Project {random.randint(1, 999)}",
                                 round(random.uniform(10000, 500000), 2))),
        ],
        "U": [
            ("crud_erp_update_timesheet",
             lambda c: c.execute("EXEC crud_erp_update_timesheet @timesheet_id=?", random.randint(1, 200000))),
            ("crud_erp_update_employee",
             lambda c: c.execute("EXEC crud_erp_update_employee @employee_id=?, @salary=?",
                                 random.randint(1, 10000),
                                 round(random.uniform(35000, 160000), 2))),
        ],
    },
    "hrm_tool": {
        "R": [
            ("crud_hrm_read_employee",
             lambda c: c.execute("EXEC crud_hrm_read_employee @employee_id=?", random.randint(1, 50000))),
            ("crud_hrm_read_enrollment (JOIN)",
             lambda c: c.execute("EXEC crud_hrm_read_enrollment @enrollment_id=?", random.randint(1, 10000))),
            ("crud_hrm_read_organization (JOIN+agg)",
             lambda c: c.execute("EXEC crud_hrm_read_organization @org_id=?", random.randint(1, 10))),
        ],
        "C": [
            ("crud_hrm_create_enrollment",
             lambda c: c.execute("EXEC crud_hrm_create_enrollment @program_id=?, @employee_id=?, @status=?",
                                 random.randint(1, 500), random.randint(1, 50000),
                                 random.choice(["enrolled","in_progress"]))),
            ("crud_hrm_create_attendance",
             lambda c: c.execute("EXEC crud_hrm_create_attendance @employee_id=?, @hours=?",
                                 random.randint(1, 50000), round(random.uniform(4, 12), 2))),
        ],
        "U": [
            ("crud_hrm_update_enrollment",
             lambda c: c.execute("EXEC crud_hrm_update_enrollment @enrollment_id=?, @status=?",
                                 random.randint(1, 10000),
                                 random.choice(["completed","dropped"]))),
            ("crud_hrm_update_employee",
             lambda c: c.execute("EXEC crud_hrm_update_employee @employee_id=?, @status=?",
                                 random.randint(1, 50000),
                                 random.choice(["active","inactive","terminated"]))),
        ],
    },
    "department_store": {
        "R": [
            ("crud_dept_read_product",
             lambda c: c.execute("EXEC crud_dept_read_product @product_id=?", random.randint(1, 50000))),
            ("crud_dept_read_inventory (JOIN)",
             lambda c: c.execute("EXEC crud_dept_read_inventory @inventory_id=?", random.randint(1, 100000))),
            ("crud_dept_read_promotion (JOIN)",
             lambda c: c.execute("EXEC crud_dept_read_promotion @promotion_id=?", random.randint(1, 5000))),
        ],
        "C": [
            ("crud_dept_create_movement",
             lambda c: c.execute("EXEC crud_dept_create_movement @inventory_id=?, @movement_type=?, @quantity=?, @ref_type=?",
                                 random.randint(1, 100000),
                                 random.choice(["inbound","outbound","adjustment","transfer"]),
                                 random.randint(1, 50),
                                 random.choice(["purchase","sale","return","stock_count"]))),
        ],
        "U": [
            ("crud_dept_update_movement",
             lambda c: c.execute("EXEC crud_dept_update_movement @movement_id=?", random.randint(1, 100000))),
            ("crud_dept_update_product",
             lambda c: c.execute("EXEC crud_dept_update_product @product_id=?, @price=?",
                                 random.randint(1, 50000),
                                 round(random.uniform(5, 500), 2))),
        ],
    },
}


def run_sql_crud(seconds, threads, users_per_thread, status_callback=None, stop_event=None):
    if stop_event is None:
        stop_event = threading.Event()

    stats_lock = threading.Lock()
    global_stats = defaultdict(lambda: {"attempted": 0, "succeeded": 0, "failed": 0})
    failed_ops = []
    failed_ops_lock = threading.Lock()

    def worker(thread_id, duration):
        deadline = time.time() + duration
        all_nodes = list(MSSQL_CONFIG["nodes"])

        while not stop_event.is_set() and time.time() < deadline:
            database = random.choice(DATABASES)
            ops = OPS[database]
            crud_type = random.choices(["C", "R", "U"], weights=[1, 3, 1], k=1)[0]
            op_list = ops.get(crud_type, [])
            if not op_list:
                continue
            op_name, op_func = random.choice(op_list)
            key = f"{database}.{crud_type}"
            
            success = False
            last_error = None
            nodes_tried = []

            # Shuffle nodes to balance load, but try all before giving up
            nodes_to_try = all_nodes.copy()
            random.shuffle(nodes_to_try)

            for node in nodes_to_try:
                # Check health registry first
                with health_lock:
                    health = node_health.get((node, database))
                    if health and health["status"] == "fail" and (time.time() - health["last_check"] < 15):
                        continue

                nodes_tried.append(node)
                cmd_entry = command_log.add("SQL CRUD", f"[{database}@{node}] {op_name}")
                conn = None
                
                try:
                    conn = pyodbc.connect(build_conn_str(database, node), autocommit=True, timeout=10)
                    cursor = conn.cursor()
                    op_func(cursor)
                    cursor.close()
                    
                    with stats_lock:
                        global_stats[key]["attempted"] += 1
                        global_stats[key]["succeeded"] += 1
                    
                    success = True
                    command_log.succeed(cmd_entry)
                    with health_lock:
                        node_health[(node, database)] = {"status": "ok", "last_check": time.time()}
                    break # Success! Exit node loop.
                
                except Exception as e:
                    err_msg = str(e)
                    last_error = err_msg
                    command_log.fail(cmd_entry, err_msg)
                    
                    is_node_issue = _is_login_error(err_msg) or "readonly" in err_msg.lower()
                    if is_node_issue:
                        logger.debug("SQL CRUD node/login fail [%s@%s] %s: %s", database, node, op_name, err_msg)
                        with health_lock:
                            node_health[(node, database)] = {"status": "fail", "last_check": time.time()}
                    else:
                        # Logic error (e.g. SQL syntax), don't bother retrying on other nodes
                        logger.warning("SQL CRUD logic fail [%s@%s] %s: %s", database, node, op_name, err_msg)
                        break
                finally:
                    if conn:
                        try:
                            conn.close()
                        except Exception:
                            pass

            if not success and last_error:
                with stats_lock:
                    # Only count as a single failure for the job stats if all nodes failed
                    global_stats[key]["attempted"] += 1
                    global_stats[key]["failed"] += 1
                with failed_ops_lock:
                    failed_ops.append({
                        "db": database, "op": op_name, "error": f"Tried {nodes_tried}: {last_error}",
                        "thread": thread_id, "node": "multi", "time": datetime.now().strftime("%H:%M:%S"),
                    })

            if status_callback:
                status_callback({
                    "db": database, "op": crud_type,
                    "success": success, "thread": thread_id, "app": nodes_tried[-1] if nodes_tried else "none",
                })
            time.sleep(random.uniform(0.05, 0.15))

    total_workers = threads * users_per_thread
    thread_list = []
    for i in range(total_workers):
        t = threading.Thread(target=worker, args=(i, seconds), daemon=True)
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
