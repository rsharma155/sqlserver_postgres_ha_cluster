import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import MSSQL_CONFIG, detect_odbc_driver
import pyodbc

# Override password/driver from environment if provided (no hardcoded secrets)
if os.environ.get("MSSQL_SA_PASSWORD"):
    MSSQL_CONFIG['sa_password'] = os.environ["MSSQL_SA_PASSWORD"]
detect_odbc_driver()

sql_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sql', 'mssql_procedures.sql')
with open(sql_path, 'r', encoding='utf-8') as f:
    sql_content = f.read()

batches = [b.strip() for b in sql_content.replace('\r\n', '\n').split('\nGO\n')]
batches = [b for b in batches if b and not b.startswith('--')]
print(f'SQL file: {len(batches)} batches')

nodes = MSSQL_CONFIG['nodes']
dbs = ['hotel_booking', 'e_commerce', 'hrm_tool', 'erp_system', 'department_store']

for node_name, node_info in nodes.items():
    print(f'=== {node_name} ({node_info["host"]}:{node_info["port"]}) ===')
    for db in dbs:
        try:
            conn_str = (
                f'DRIVER={{{MSSQL_CONFIG["driver"]}}};'
                f'SERVER={node_info["host"]},{node_info["port"]};'
                f'UID={MSSQL_CONFIG["sa_user"]};PWD={MSSQL_CONFIG["sa_password"]};'
                f'Database={db};TrustServerCertificate=yes;'
            )
            conn = pyodbc.connect(conn_str, timeout=10, autocommit=True)
            cur = conn.cursor()
            ok, fail = 0, 0
            for i, batch in enumerate(batches):
                try:
                    cur.execute(batch)
                    ok += 1
                except Exception as e:
                    fail += 1
                    if fail <= 3:
                        print(f'  {db} batch {i}: {str(e)[:120]}')
            cur.close()
            conn.close()
            print(f'  {db}: {ok} OK, {fail} failed')
        except Exception as e:
            print(f'  {db}: CONN ERROR {str(e)[:120]}')

print('Done!')
