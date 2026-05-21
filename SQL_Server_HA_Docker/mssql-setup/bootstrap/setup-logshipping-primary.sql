-- ============================================================================
-- Log Shipping Primary Configuration for hrm_tool (sql1 -> sql2)
-- ============================================================================
-- Run on the primary server (sql1) to configure log shipping backup jobs
-- and register the secondary (sql2).
-- Depends on: hrm_tool database created, shared backup volume available
-- ============================================================================

USE master;
GO

PRINT '=== Starting Log Shipping Primary Setup for hrm_tool ===';

-- 1. Set recovery model to FULL (required for log shipping)
IF DATABASEPROPERTYEX('hrm_tool', 'Recovery') != 'FULL'
BEGIN
    ALTER DATABASE hrm_tool SET RECOVERY FULL;
    PRINT 'hrm_tool recovery set to FULL.';
END
ELSE
    PRINT 'hrm_tool already in FULL recovery model.';
GO

-- 2. Take a full backup of hrm_tool
PRINT 'Taking full backup of hrm_tool...';
BACKUP DATABASE hrm_tool
TO DISK = N'/var/opt/mssql/external_backup/hrm_tool_full.bak'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 25;
GO

-- 3. Take a transaction log backup
PRINT 'Taking initial log backup of hrm_tool...';
BACKUP LOG hrm_tool
TO DISK = N'/var/opt/mssql/external_backup/hrm_tool_log1.trn'
WITH INIT, COMPRESSION, CHECKSUM, STATS = 25;
GO

-- 4. Delete any existing log shipping primary config for this DB
USE msdb;
GO
IF EXISTS (SELECT 1 FROM msdb.dbo.log_shipping_primary_databases WHERE primary_database = 'hrm_tool')
BEGIN
    EXEC sp_delete_log_shipping_primary_database @database = N'hrm_tool';
    PRINT 'Removed existing log shipping primary configuration for hrm_tool.';
END
GO

-- 5. Configure primary database for log shipping
DECLARE @ls_job_id UNIQUEIDENTIFIER;

EXEC sp_add_log_shipping_primary_database
    @database = N'hrm_tool',
    @backup_directory = N'/var/opt/mssql/external_backup',
    @backup_share = N'/var/opt/mssql/external_backup',
    @backup_job_name = N'LSBackup_hrm_tool',
    @backup_retention_period = 4320,
    @backup_compression = 2,
    @backup_threshold = 60,
    @threshold_alert_enabled = 1,
    @history_retention_period = 5760,
    @monitor_server = N'',
    @monitor_server_security_mode = 1;
GO

PRINT 'Log shipping primary database configured.';

-- 6. Register the secondary (sql2) on the primary
IF EXISTS (
    SELECT 1 FROM msdb.dbo.log_shipping_secondary_primaries
    WHERE primary_server = N'sql1' AND primary_database = N'hrm_tool'
)
BEGIN
    PRINT 'Secondary mapping for sql2 already exists, removing...';
    EXEC sp_delete_log_shipping_secondary_primary
        @primary_server = N'sql1',
        @primary_database = N'hrm_tool';
END
GO

EXEC sp_add_log_shipping_secondary_primary
    @primary_server = N'sql1',
    @primary_database = N'hrm_tool',
    @backup_source_directory = N'/var/opt/mssql/external_backup',
    @backup_destination_directory = N'/var/opt/mssql/external_backup',
    @copy_job_name = N'LSCopy_hrm_tool',
    @restore_job_name = N'LSRestore_hrm_tool',
    @file_retention_period = 4320,
    @overwrite = 1;
GO

PRINT 'Secondary server sql2 registered on primary for hrm_tool.';

-- 7. Start the backup job
EXEC sp_start_job @job_name = N'LSBackup_hrm_tool';
PRINT 'Log shipping backup job started.';

PRINT '=== Log Shipping Primary Setup Complete ===';
GO
