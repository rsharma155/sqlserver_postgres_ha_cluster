-- ============================================================================
-- SQL Server Monitoring User Initialization Script
-- ============================================================================
-- Purpose: Creates a dedicated monitoring user with minimal required permissions
--          for the SQL Optima monitoring system.
--
-- Usage:   Execute this script on your SQL Server instance as a sysadmin or
--          user with privileges to create logins and grant permissions.
--
-- Note:    Replace __STRONG_PASSWORD_FROM_VAULT__ before running, or create the login
--          outside this script and skip the CREATE LOGIN block.
-- ============================================================================

USE master;
GO

-- Create login for monitoring user (if it doesn't exist)
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'dbmonitor_user')
BEGIN
    CREATE LOGIN [dbmonitor_user] WITH 
        PASSWORD = N'$(DBMONITOR_PASSWORD)',
        DEFAULT_DATABASE = [master],
        CHECK_POLICY = ON,
        CHECK_EXPIRATION = OFF;
    
    PRINT 'Login [dbmonitor_user] created successfully.';
END
ELSE
BEGIN
    PRINT 'Login [dbmonitor_user] already exists.';
END
GO

-- Grant server-level permissions for performance counters and DMVs
USE master;
GO
GRANT VIEW SERVER STATE TO [dbmonitor_user];
GRANT VIEW ANY DEFINITION TO [dbmonitor_user];
GRANT VIEW ANY DATABASE TO [dbmonitor_user]; -- Required to see all DBs in sys.databases
GRANT ALTER ANY EVENT SESSION TO [dbmonitor_user]; -- Required for managing Deadlock/Blocking XE sessions
GO

-- 1. MSDB Permissions (SQL Agent, Backup/Restore)
USE msdb;
GO
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'dbmonitor_user')
BEGIN
    CREATE USER [dbmonitor_user] FOR LOGIN [dbmonitor_user];
END
GO
GRANT SELECT ON dbo.sysjobs TO [dbmonitor_user];
GRANT SELECT ON dbo.sysjobschedules TO [dbmonitor_user];
GRANT SELECT ON dbo.sysjobactivity TO [dbmonitor_user];
GRANT SELECT ON dbo.sysjobhistory TO [dbmonitor_user];
GRANT SELECT ON dbo.sysschedules TO [dbmonitor_user];
GRANT SELECT ON dbo.syscategories TO [dbmonitor_user];
GRANT SELECT ON dbo.sysjobsteps TO [dbmonitor_user];
GRANT SELECT ON dbo.sysoperators TO [dbmonitor_user];
GRANT EXECUTE ON dbo.agent_datetime TO [dbmonitor_user];
EXEC sp_addrolemember 'SQLAgentReaderRole', 'dbmonitor_user';
GO

-- 2. Distribution Database Permissions (Replication)
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'distribution')
BEGIN
    EXEC('
    USE [distribution];
    IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = ''dbmonitor_user'')
    BEGIN
        CREATE USER [dbmonitor_user] FOR LOGIN [dbmonitor_user];
    END
    GRANT SELECT ON OBJECT::[dbo].[MSdistribution_agents] TO [dbmonitor_user];
    GRANT SELECT ON OBJECT::[dbo].[MSdistribution_history] TO [dbmonitor_user];
    GRANT SELECT ON OBJECT::[dbo].[MSdistribution_status] TO [dbmonitor_user];
    GRANT SELECT ON OBJECT::[dbo].[MSpublications] TO [dbmonitor_user];
    GRANT SELECT ON OBJECT::[dbo].[MSarticles] TO [dbmonitor_user];
    ');
    PRINT 'Granted permissions on [distribution] database.';
END
GO

-- 3. Master Permissions (Server-wide metadata)
USE master;
GO
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'dbmonitor_user')
BEGIN
    CREATE USER [dbmonitor_user] FOR LOGIN [dbmonitor_user];
END
GO
-- Additional grants for specialized features
GRANT SELECT ON sys.databases TO [dbmonitor_user];
GRANT SELECT ON sys.master_files TO [dbmonitor_user];
GRANT SELECT ON sys.availability_groups TO [dbmonitor_user];
GRANT SELECT ON sys.availability_replicas TO [dbmonitor_user];
GO

-- Create user in each monitored database
DECLARE @dbname NVARCHAR(128);
DECLARE db_cursor CURSOR FOR
    SELECT name FROM sys.databases
    WHERE name IN ('HADemoDB', 'hotel_booking', 'e_commerce', 'erp_system', 'hrm_tool', 'department_store');
OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @dbname;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @sql NVARCHAR(MAX) = '
        USE [' + @dbname + '];
        IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = ''dbmonitor_user'')
        BEGIN
            CREATE USER [dbmonitor_user] FOR LOGIN [dbmonitor_user];
        END
        GRANT SELECT ON SCHEMA::dbo TO [dbmonitor_user];
    ';
    EXEC sp_executesql @sql;
    PRINT '' + @dbname + ': user created and granted SELECT ON SCHEMA::dbo.';
    FETCH NEXT FROM db_cursor INTO @dbname;
END
CLOSE db_cursor;
DEALLOCATE db_cursor;
GO

-- 5. Add user to model database so future databases auto-inherit it
USE [model];
GO
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'dbmonitor_user')
BEGIN
    CREATE USER [dbmonitor_user] FOR LOGIN [dbmonitor_user];
    PRINT 'model: user created.';
END
ELSE
    PRINT 'model: user already exists.';
GO
GRANT SELECT ON SCHEMA::dbo TO [dbmonitor_user];
PRINT 'model: granted SELECT ON SCHEMA::dbo.';
GO

PRINT '';
PRINT '========================================';
PRINT 'SQL Server monitoring user setup complete.';
PRINT '========================================';
PRINT 'Login: dbmonitor_user';
PRINT 'Required grants applied:';
PRINT '  - VIEW SERVER STATE, VIEW ANY DEFINITION, VIEW ANY DATABASE';
PRINT '  - msdb: SQL Agent & Backup metadata';
PRINT '  - distribution: Replication metadata (if exists)';
PRINT '  - master: DB & HA/AG metadata';
PRINT '  - HADemoDB, hotel_booking, e_commerce, erp_system, hrm_tool, department_store: user + SELECT ON SCHEMA::dbo';
PRINT '========================================';
GO
