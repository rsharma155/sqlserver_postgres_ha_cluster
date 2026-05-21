-- ============================================================================
-- Log Shipping Secondary Configuration for hrm_tool (sql1 -> sql2)
-- ============================================================================
-- Run on the secondary server (sql2) to restore the initial backup
-- and configure log shipping restore jobs.
-- Depends on: full backup and log backup from primary in shared volume
-- ============================================================================

USE master;
GO

PRINT '=== Starting Log Shipping Secondary Setup for hrm_tool ===';

-- 1. Drop existing hrm_tool database on secondary (if present)
IF DB_ID('hrm_tool') IS NOT NULL
BEGIN
    PRINT 'Dropping existing hrm_tool database on secondary...';
    ALTER DATABASE hrm_tool SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE hrm_tool;
    PRINT 'Existing hrm_tool database dropped.';
END
GO

-- 2. Restore full backup with NORECOVERY
-- (Backup files are guaranteed available since sql1 writes them before
--  this script is invoked on sql2 via the shared Docker volume)
PRINT 'Restoring full backup of hrm_tool with NORECOVERY...';
RESTORE DATABASE hrm_tool
FROM DISK = N'/var/opt/mssql/external_backup/hrm_tool_full.bak'
WITH NORECOVERY, REPLACE, STATS = 25;
GO

-- 3. Restore initial log backup with NORECOVERY
PRINT 'Restoring initial log backup of hrm_tool with NORECOVERY...';
RESTORE LOG hrm_tool
FROM DISK = N'/var/opt/mssql/external_backup/hrm_tool_log1.trn'
WITH NORECOVERY, STATS = 25;
GO

-- 5. Remove any existing secondary config for this DB
USE msdb;
GO
IF EXISTS (
    SELECT 1 FROM msdb.dbo.log_shipping_secondary_databases
    WHERE secondary_database = 'hrm_tool'
)
BEGIN
    EXEC sp_delete_log_shipping_secondary_database @secondary_database = N'hrm_tool';
    PRINT 'Removed existing log shipping secondary configuration.';
END
GO

-- 6. Configure secondary database for log shipping
EXEC sp_add_log_shipping_secondary_database
    @secondary_database = N'hrm_tool',
    @primary_server = N'sql1',
    @primary_database = N'hrm_tool',
    @restore_delay = 0,
    @restore_mode = 1,
    @disconnect_users = 1,
    @block_size = -1,
    @buffer_count = -1,
    @max_transfer_size = -1,
    @restore_threshold = 45,
    @threshold_alert_enabled = 1,
    @history_retention_period = 5760,
    @overwrite = 1;
GO

PRINT 'Log shipping secondary database configured.';

-- 7. Start the copy and restore jobs
EXEC sp_start_job @job_name = N'LSCopy_hrm_tool';
PRINT 'Log shipping copy job started.';

EXEC sp_start_job @job_name = N'LSRestore_hrm_tool';
PRINT 'Log shipping restore job started.';

PRINT '=== Log Shipping Secondary Setup Complete ===';
PRINT 'hrm_tool is now in STANDBY/RESTORING mode on sql2.';
GO
