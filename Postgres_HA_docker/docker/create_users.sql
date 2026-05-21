-- =====================================================
-- PostgreSQL create_users.sql
-- Creates 10 CRUD load test users with full DML
-- permissions on all 5 application databases.
-- Mirrors the SQL Server create_users.sql counterparts.
-- Run via: psql -U postgres -f create_users.sql
-- =====================================================

\c postgres

SELECT 'Creating 10 CRUD load test users...';

-- Drop users if they exist (idempotent for every-boot re-runs)
DROP ROLE IF EXISTS hotel_agent;
DROP ROLE IF EXISTS ecom_manager;
DROP ROLE IF EXISTS erp_operator;
DROP ROLE IF EXISTS hr_manager;
DROP ROLE IF EXISTS store_clerk;
DROP ROLE IF EXISTS hotel_guest;
DROP ROLE IF EXISTS ecom_shopper;
DROP ROLE IF EXISTS erp_finance;
DROP ROLE IF EXISTS hr_recruiter;
DROP ROLE IF EXISTS store_manager;

-- Create 10 users with passwords matching the SQL Server load test users
CREATE USER hotel_agent   WITH PASSWORD 'TestP@ss1!';
CREATE USER ecom_manager  WITH PASSWORD 'TestP@ss2!';
CREATE USER erp_operator  WITH PASSWORD 'TestP@ss3!';
CREATE USER hr_manager    WITH PASSWORD 'TestP@ss4!';
CREATE USER store_clerk   WITH PASSWORD 'TestP@ss5!';
CREATE USER hotel_guest   WITH PASSWORD 'TestP@ss6!';
CREATE USER ecom_shopper  WITH PASSWORD 'TestP@ss7!';
CREATE USER erp_finance   WITH PASSWORD 'TestP@ss8!';
CREATE USER hr_recruiter  WITH PASSWORD 'TestP@ss9!';
CREATE USER store_manager WITH PASSWORD 'TestP@ss10!';

-- =====================================================
-- Per-database grants
-- 9 read-write users get SELECT/INSERT/UPDATE/DELETE
-- hotel_guest is read-only (SELECT only)
-- =====================================================

\echo '--- Granting permissions: hotel_booking ---'
\c hotel_booking
GRANT CONNECT ON DATABASE hotel_booking TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
-- hotel_guest: read-only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hotel_guest;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO hotel_guest;

\echo '--- Granting permissions: e_commerce ---'
\c e_commerce
GRANT CONNECT ON DATABASE e_commerce TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hotel_guest;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO hotel_guest;

\echo '--- Granting permissions: erp_system ---'
\c erp_system
GRANT CONNECT ON DATABASE erp_system TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hotel_guest;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO hotel_guest;

\echo '--- Granting permissions: hrm_tool ---'
\c hrm_tool
GRANT CONNECT ON DATABASE hrm_tool TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hotel_guest;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO hotel_guest;

\echo '--- Granting permissions: department_store ---'
\c department_store
GRANT CONNECT ON DATABASE department_store TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, hotel_guest, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO hotel_agent, ecom_manager, erp_operator, hr_manager, store_clerk, ecom_shopper, erp_finance, hr_recruiter, store_manager;
-- hotel_guest: read-only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hotel_guest;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO hotel_guest;

\c postgres
SELECT '10 CRUD load test users created successfully.' AS status;
