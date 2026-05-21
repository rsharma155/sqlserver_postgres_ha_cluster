-- =====================================================
-- pgsql_init.sql
-- Creates a monitoring login user with the built-in
-- cluster-level observability roles (PostgreSQL 17+).
-- Run via: psql -U postgres -f pgsql_init.sql
-- =====================================================

\c postgres

SELECT 'Creating monitoring login user...';

-- pg_monitor is a built-in role in PG17 (reserved, cannot be created/altered).
-- Clean up old role name if it exists (leftover from previous versions)
DROP ROLE IF EXISTS monitor_user;

-- Drop + recreate to always reflect the exact username/password in this file
DROP ROLE IF EXISTS dbmonitor_user;
CREATE USER dbmonitor_user WITH PASSWORD 'Hello@123';

-- Grant the built-in monitoring roles (all exist by default in PG17)
GRANT pg_monitor           TO dbmonitor_user;
GRANT pg_read_all_stats    TO dbmonitor_user;
GRANT pg_read_all_settings TO dbmonitor_user;
GRANT pg_stat_scan_tables  TO dbmonitor_user;
GRANT pg_signal_backend    TO dbmonitor_user;

-- =====================================================
-- Per-database grants
-- =====================================================

\echo '--- Granting permissions: hotel_booking ---'
\c hotel_booking
GRANT CONNECT ON DATABASE hotel_booking TO dbmonitor_user;
GRANT USAGE ON SCHEMA public TO dbmonitor_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbmonitor_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbmonitor_user;

\echo '--- Granting permissions: e_commerce ---'
\c e_commerce
GRANT CONNECT ON DATABASE e_commerce TO dbmonitor_user;
GRANT USAGE ON SCHEMA public TO dbmonitor_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbmonitor_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbmonitor_user;

\echo '--- Granting permissions: erp_system ---'
\c erp_system
GRANT CONNECT ON DATABASE erp_system TO dbmonitor_user;
GRANT USAGE ON SCHEMA public TO dbmonitor_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbmonitor_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbmonitor_user;

\echo '--- Granting permissions: hrm_tool ---'
\c hrm_tool
GRANT CONNECT ON DATABASE hrm_tool TO dbmonitor_user;
GRANT USAGE ON SCHEMA public TO dbmonitor_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbmonitor_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbmonitor_user;

\echo '--- Granting permissions: department_store ---'
\c department_store
GRANT CONNECT ON DATABASE department_store TO dbmonitor_user;
GRANT USAGE ON SCHEMA public TO dbmonitor_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO dbmonitor_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO dbmonitor_user;

-- =====================================================
-- pg_stat_statements extension and function access
-- =====================================================
\c postgres
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
GRANT EXECUTE ON FUNCTION pg_stat_statements_reset(oid, oid, bigint, boolean) TO dbmonitor_user;
GRANT EXECUTE ON FUNCTION pg_stat_statements(boolean) TO dbmonitor_user;

SELECT 'Monitoring user created successfully.' AS status;
SELECT rolname FROM pg_roles WHERE rolname IN ('dbmonitor_user');
