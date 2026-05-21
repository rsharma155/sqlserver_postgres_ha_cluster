import random
import time
import pyodbc
from config import build_conn_str
from operations import DATABASE_OPERATIONS

SHOW_SQL = True

USER_PROFILES = [
    {
        "username": "hotel_agent",
        "label": "Hotel Booking Agent",
        "db_ops": [("hotel_booking", DATABASE_OPERATIONS["hotel_booking"])],
        "rw_ratio": 0.6,
    },
    {
        "username": "ecom_manager",
        "label": "E-Commerce Manager",
        "db_ops": [("e_commerce", DATABASE_OPERATIONS["e_commerce"])],
        "rw_ratio": 0.5,
    },
    {
        "username": "erp_operator",
        "label": "ERP Operator",
        "db_ops": [("erp_system", DATABASE_OPERATIONS["erp_system"])],
        "rw_ratio": 0.5,
    },
    {
        "username": "hr_manager",
        "label": "HR Manager",
        "db_ops": [("hrm_tool", DATABASE_OPERATIONS["hrm_tool"])],
        "rw_ratio": 0.6,
    },
    {
        "username": "store_clerk",
        "label": "Store Clerk",
        "db_ops": [("department_store", DATABASE_OPERATIONS["department_store"])],
        "rw_ratio": 0.4,
    },
    {
        "username": "hotel_guest",
        "label": "Hotel Guest (read-only)",
        "db_ops": [("hotel_booking", DATABASE_OPERATIONS["hotel_booking"])],
        "rw_ratio": 1.0,
    },
    {
        "username": "ecom_shopper",
        "label": "E-Commerce Shopper",
        "db_ops": [("e_commerce", DATABASE_OPERATIONS["e_commerce"])],
        "rw_ratio": 0.3,
    },
    {
        "username": "erp_finance",
        "label": "ERP Finance",
        "db_ops": [("erp_system", DATABASE_OPERATIONS["erp_system"])],
        "rw_ratio": 0.7,
    },
    {
        "username": "hr_recruiter",
        "label": "HR Recruiter",
        "db_ops": [("hrm_tool", DATABASE_OPERATIONS["hrm_tool"])],
        "rw_ratio": 0.5,
    },
    {
        "username": "store_manager",
        "label": "Store Manager",
        "db_ops": [("department_store", DATABASE_OPERATIONS["department_store"])],
        "rw_ratio": 0.5,
    },
]


class LoggingCursor:
    def __init__(self, cursor, user, db_name, op_name, node):
        self._c = cursor
        self._user = user
        self._db = db_name
        self._op = op_name
        self._node = node

    def execute(self, sql, *params):
        if SHOW_SQL:
            sql_preview = sql[:200].replace('\n', ' ').replace('\r', '').strip()
            remaining = len(sql) - 200
            if remaining > 0:
                sql_preview += f" ...(+{remaining} chars)"
            print(f"  [{self._user}@{self._node}] [{self._db}] [{self._op}]")
            print(f"  >> {sql_preview}")
            if params:
                p = params[0] if len(params) == 1 else params
                print(f"     params: {p}")
        return self._c.execute(sql, *params)

    def __getattr__(self, name):
        return getattr(self._c, name)


def run_user_session(profile, duration_seconds, min_delay, max_delay, results, stop_event):
    username = profile["username"]
    label = profile["label"]
    password = profile.get("password")
    node = profile.get("node")
    rw_ratio = profile["rw_ratio"]
    db_ops = profile["db_ops"]

    conn_info = {"username": username, "password": password, "node": node}
    conn_str = build_conn_str(conn_info["username"], conn_info["password"], conn_info["node"])

    try:
        conn = pyodbc.connect(conn_str, autocommit=True, timeout=10)
        cursor = conn.cursor()

        start_time = time.time()
        op_count = 0
        error_count = 0
        row_count = 0

        while (time.time() - start_time < duration_seconds) and not stop_event.is_set():
            db_name, operations = random.choice(db_ops)
            cursor.execute(f"USE {db_name};")

            op_name, op_func = random.choice(operations)
            is_read = op_name.startswith("SELECT")

            if random.random() < rw_ratio and not is_read:
                op_name, op_func = random.choice([o for o in operations if o[0].startswith("SELECT")])
                is_read = True

            log_cursor = LoggingCursor(cursor, username, db_name, op_name, node)

            try:
                op_func(log_cursor)
                op_count += 1
                rc = log_cursor._c.rowcount
                row_count += max(0, rc) if rc != -1 else 0
                if rc != -1:
                    print(f"  OK ({rc} row(s))")
                else:
                    print(f"  OK")
            except Exception as ex:
                error_count += 1
                print(f"  ERROR: {ex}")

            delay = random.uniform(min_delay, max_delay)
            if stop_event.is_set():
                break
            time.sleep(delay)

        conn.close()
        results.append({"user": username, "label": label, "ops": op_count, "errors": error_count, "rows": row_count})

    except Exception as e:
        results.append({"user": username, "label": label, "ops": 0, "errors": 0, "error": str(e)})
