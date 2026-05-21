import os

# SQL Server connection template
# Uses ODBC Driver 18 with TrustServerCertificate for Docker SQL Server
DRIVER = "ODBC Driver 18 for SQL Server"
TRUST_CERT = "yes"

# Node connection details
NODES = {
    "sql1": {"host": "localhost", "port": 14331},
    "sql2": {"host": "localhost", "port": 14332},
    "sql3": {"host": "localhost", "port": 14333},
}

# User credentials (created by create_users.sql)
USERS = {
    "hotel_agent":  {"password": "TestP@ss1!",  "node": "sql1", "databases": ["hotel_booking"]},
    "ecom_manager": {"password": "TestP@ss2!",  "node": "sql1", "databases": ["e_commerce"]},
    "erp_operator": {"password": "TestP@ss3!",  "node": "sql1", "databases": ["erp_system"]},
    "hr_manager":   {"password": "TestP@ss4!",  "node": "sql1", "databases": ["hrm_tool"]},
    "store_clerk":  {"password": "TestP@ss5!",  "node": "sql1", "databases": ["department_store"]},
    "hotel_guest":  {"password": "TestP@ss6!",  "node": "sql1", "databases": ["hotel_booking"]},
    "ecom_shopper": {"password": "TestP@ss7!",  "node": "sql1", "databases": ["e_commerce"]},
    "erp_finance":  {"password": "TestP@ss8!",  "node": "sql1", "databases": ["erp_system"]},
    "hr_recruiter": {"password": "TestP@ss9!",  "node": "sql1", "databases": ["hrm_tool"]},
    "store_manager":{"password": "TestP@ss10!", "node": "sql1", "databases": ["department_store"]},
}

# Load test settings
DEFAULT_DURATION_SECONDS = int(os.getenv("LOAD_TEST_DURATION", "60"))
DEFAULT_MIN_DELAY = float(os.getenv("LOAD_TEST_MIN_DELAY", "0.5"))
DEFAULT_MAX_DELAY = float(os.getenv("LOAD_TEST_MAX_DELAY", "3.0"))

def build_conn_str(username: str, password: str, node: str) -> str:
    info = NODES[node]
    return (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={info['host']},{info['port']};"
        f"UID={username};PWD={password};"
        f"TrustServerCertificate={TRUST_CERT};"
    )
