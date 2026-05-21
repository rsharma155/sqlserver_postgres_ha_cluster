import os
import psycopg2

PG_PASSWORD = os.environ.get("PG_PASSWORD", "postgres123")
MSSQL_SA_PASSWORD = os.environ.get("MSSQL_SA_PASSWORD", "")
if not MSSQL_SA_PASSWORD:
    raise SystemExit("Set MSSQL_SA_PASSWORD env var before running check_seed.py")

pg_dbs = {
    'erp_system': ['companies', 'departments', 'employees', 'projects'],
    'department_store': ['stores', 'departments_store', 'categories_store', 'products_store', 'employees_store', 'inventory_store', 'promotions'],
    'hotel_booking': ['guests', 'reservations', 'reviews'],
    'e_commerce': ['customers', 'orders', 'products'],
    'hrm_tool': ['employees_hrm', 'attendance_logs_hrm', 'payroll_hrm'],
}

print('=== PostgreSQL ===')
for dbname, tables in pg_dbs.items():
    try:
        conn = psycopg2.connect(host='localhost', port=5000, user='postgres', password=PG_PASSWORD, dbname=dbname, connect_timeout=5)
        cur = conn.cursor()
        parts = []
        for t in tables:
            cur.execute(f'SELECT COUNT(*) FROM {t}')
            cnt = cur.fetchone()[0]
            parts.append(f'{t}={cnt}')
        print(f'{dbname}: {", ".join(parts)}')
        cur.close()
        conn.close()
    except Exception as e:
        print(f'{dbname}: ERROR {e}')

import pyodbc
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import detect_odbc_driver
mssql_cfg = {'driver': detect_odbc_driver(), 'sa_user': 'sa', 'sa_password': MSSQL_SA_PASSWORD}
mssql_dbs = {
    'hotel_booking': ['guests', 'reservations'],
    'e_commerce': ['customers', 'orders'],
    'hrm_tool': ['employees_hrm', 'attendance_logs_hrm'],
    'erp_system': ['companies', 'employees'],
    'department_store': ['stores', 'products_store'],
}

print()
print('=== MSSQL ===')
for port in [14331, 14332, 14333]:
    print(f'--- Node localhost:{port} ---')
    for dbname, tables in mssql_dbs.items():
        try:
            conn_str = (f'DRIVER={{{mssql_cfg["driver"]}}};SERVER=localhost,{port};'
                        f'UID={mssql_cfg["sa_user"]};PWD={mssql_cfg["sa_password"]};'
                        f'Database={dbname};TrustServerCertificate=yes;')
            conn = pyodbc.connect(conn_str, timeout=5, autocommit=True)
            cur = conn.cursor()
            parts = []
            for t in tables:
                try:
                    cur.execute(f'SELECT COUNT(*) FROM {t}')
                    parts.append(f'{t}={cur.fetchone()[0]}')
                except Exception as ex:
                    parts.append(f'{t}=ERR({str(ex)[:20]})')
            print(f'  {dbname}: {", ".join(parts)}')
            cur.close()
            conn.close()
        except Exception as e:
            print(f'  {dbname}: CONN ERROR {str(e)[:80]}')
