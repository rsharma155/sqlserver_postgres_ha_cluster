-- =====================================================
-- Create 10 test users for load testing
-- =====================================================
USE master;
GO

-- Drop users if they exist
DROP USER IF EXISTS hotel_agent; DROP LOGIN IF EXISTS hotel_agent;
DROP USER IF EXISTS ecom_manager; DROP LOGIN IF EXISTS ecom_manager;
DROP USER IF EXISTS erp_operator; DROP LOGIN IF EXISTS erp_operator;
DROP USER IF EXISTS hr_manager; DROP LOGIN IF EXISTS hr_manager;
DROP USER IF EXISTS store_clerk; DROP LOGIN IF EXISTS store_clerk;
DROP USER IF EXISTS hotel_guest; DROP LOGIN IF EXISTS hotel_guest;
DROP USER IF EXISTS ecom_shopper; DROP LOGIN IF EXISTS ecom_shopper;
DROP USER IF EXISTS erp_finance; DROP LOGIN IF EXISTS erp_finance;
DROP USER IF EXISTS hr_recruiter; DROP LOGIN IF EXISTS hr_recruiter;
DROP USER IF EXISTS store_manager; DROP LOGIN IF EXISTS store_manager;
GO

-- Create logins
CREATE LOGIN hotel_agent WITH PASSWORD = 'TestP@ss1!';
CREATE LOGIN ecom_manager WITH PASSWORD = 'TestP@ss2!';
CREATE LOGIN erp_operator WITH PASSWORD = 'TestP@ss3!';
CREATE LOGIN hr_manager WITH PASSWORD = 'TestP@ss4!';
CREATE LOGIN store_clerk WITH PASSWORD = 'TestP@ss5!';
CREATE LOGIN hotel_guest WITH PASSWORD = 'TestP@ss6!';
CREATE LOGIN ecom_shopper WITH PASSWORD = 'TestP@ss7!';
CREATE LOGIN erp_finance WITH PASSWORD = 'TestP@ss8!';
CREATE LOGIN hr_recruiter WITH PASSWORD = 'TestP@ss9!';
CREATE LOGIN store_manager WITH PASSWORD = 'TestP@ss10!';
GO

-- Create users in each database and grant permissions
DECLARE @db NVARCHAR(100), @sql NVARCHAR(MAX)
DECLARE db_cursor CURSOR FOR
    SELECT name FROM sys.databases WHERE name IN ('hotel_booking','e_commerce','erp_system','hrm_tool','department_store')

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @db

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = '
        USE ' + QUOTENAME(@db) + ';
        CREATE USER hotel_agent FOR LOGIN hotel_agent;
        CREATE USER ecom_manager FOR LOGIN ecom_manager;
        CREATE USER erp_operator FOR LOGIN erp_operator;
        CREATE USER hr_manager FOR LOGIN hr_manager;
        CREATE USER store_clerk FOR LOGIN store_clerk;
        CREATE USER hotel_guest FOR LOGIN hotel_guest;
        CREATE USER ecom_shopper FOR LOGIN ecom_shopper;
        CREATE USER erp_finance FOR LOGIN erp_finance;
        CREATE USER hr_recruiter FOR LOGIN hr_recruiter;
        CREATE USER store_manager FOR LOGIN store_manager;
        GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO hotel_agent;
        GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO ecom_manager;
        GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO erp_operator;
        GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO hr_manager;
        GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO store_clerk;
        GRANT SELECT ON SCHEMA::dbo TO hotel_guest;
        GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO ecom_shopper;
        GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO erp_finance;
        GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO hr_recruiter;
        GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO store_manager;
    '
    EXEC sp_executesql @sql
    FETCH NEXT FROM db_cursor INTO @db
END

CLOSE db_cursor; DEALLOCATE db_cursor;
GO

PRINT '10 test users created with permissions on all databases.';
GO
