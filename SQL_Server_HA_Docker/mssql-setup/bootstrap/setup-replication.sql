-- =====================================================
-- Replication Setup: Publisher + Distributor on sql1
-- Subscribers: sql2, sql3
-- =====================================================

-- Enable SQL Agent (required for replication agents)
EXEC sp_configure 'Agent XPs', 1;
RECONFIGURE;
GO

-- =====================================================
-- Distribution Configuration (run on sql1 only)
-- =====================================================

-- Configure sql1 as distributor
EXEC sp_adddistributor @distributor = N'sql1', @password = N'D1str1but0rP@ss!';
GO

-- Create distribution database
EXEC sp_adddistributiondb @database = N'distribution', 
    @data_folder = N'/var/opt/mssql/data',
    @log_folder = N'/var/opt/mssql/log',
    @log_file_size = 2,
    @min_distretention = 0,
    @max_distretention = 72,
    @history_retention = 48;
GO

-- Configure distribution database
USE distribution;
GO
EXEC sp_adddistpublisher @publisher = N'sql1', 
    @distribution_db = N'distribution',
    @security_mode = 1,
    @working_directory = N'/var/opt/mssql/backup',
    @trusted = N'false',
    @thirdparty_flag = 0,
    @publisher_type = N'MSSQLSERVER';
GO

-- =====================================================
-- Publications
-- =====================================================

-- Publication 1: hotel_booking tables
USE hotel_booking;
GO
EXEC sp_replicationdboption @dbname = N'hotel_booking', @optname = N'publish', @value = N'true';
GO

EXEC sp_addpublication 
    @publication = N'pub_hotel_booking',
    @description = N'Hotel Booking replication publication',
    @sync_method = N'native',
    @retention = 336,
    @allow_push = N'true',
    @allow_pull = N'true',
    @allow_anonymous = N'false',
    @enabled_for_internet = N'false',
    @snapshot_in_defaultfolder = N'true',
    @compress_snapshot = N'false',
    @ftp_port = 21,
    @allow_subscription_copy = N'false',
    @add_to_active_directory = N'false',
    @repl_freq = N'continuous',
    @status = N'active',
    @independent_agent = N'true',
    @immediate_sync = N'false',
    @allow_sync_tran = N'false',
    @autogen_sync_procs = N'false',
    @allow_queued_tran = N'false',
    @allow_dts = N'false',
    @replicate_ddl = 1,
    @allow_initialize_from_backup = N'false',
    @enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

-- Add articles to hotel_booking publication
EXEC sp_addarticle @publication = N'pub_hotel_booking', @article = N'guests', @source_object = N'guests', @source_owner = N'dbo';
EXEC sp_addarticle @publication = N'pub_hotel_booking', @article = N'reservations', @source_object = N'reservations', @source_owner = N'dbo';
EXEC sp_addarticle @publication = N'pub_hotel_booking', @article = N'payments', @source_object = N'payments', @source_owner = N'dbo';
GO

-- Publication 2: e_commerce tables
USE e_commerce;
GO
EXEC sp_replicationdboption @dbname = N'e_commerce', @optname = N'publish', @value = N'true';
GO

EXEC sp_addpublication 
    @publication = N'pub_e_commerce',
    @description = N'E-Commerce replication publication',
    @sync_method = N'native',
    @retention = 336,
    @allow_push = N'true',
    @allow_pull = N'true',
    @allow_anonymous = N'false',
    @enabled_for_internet = N'false',
    @snapshot_in_defaultfolder = N'true',
    @compress_snapshot = N'false',
    @repl_freq = N'continuous',
    @status = N'active',
    @independent_agent = N'true',
    @immediate_sync = N'false',
    @allow_sync_tran = N'false',
    @autogen_sync_procs = N'false',
    @allow_queued_tran = N'false',
    @allow_dts = N'false',
    @replicate_ddl = 1,
    @allow_initialize_from_backup = N'false',
    @enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

EXEC sp_addarticle @publication = N'pub_e_commerce', @article = N'customers', @source_object = N'customers', @source_owner = N'dbo';
EXEC sp_addarticle @publication = N'pub_e_commerce', @article = N'orders', @source_object = N'orders', @source_owner = N'dbo';
EXEC sp_addarticle @publication = N'pub_e_commerce', @article = N'products', @source_object = N'products', @source_owner = N'dbo';
GO

-- Publication 3: erp_system tables
USE erp_system;
GO
EXEC sp_replicationdboption @dbname = N'erp_system', @optname = N'publish', @value = N'true';
GO

EXEC sp_addpublication 
    @publication = N'pub_erp_system',
    @description = N'ERP System replication publication',
    @sync_method = N'native',
    @retention = 336,
    @allow_push = N'true',
    @allow_pull = N'true',
    @allow_anonymous = N'false',
    @enabled_for_internet = N'false',
    @snapshot_in_defaultfolder = N'true',
    @compress_snapshot = N'false',
    @repl_freq = N'continuous',
    @status = N'active',
    @independent_agent = N'true',
    @immediate_sync = N'false',
    @allow_sync_tran = N'false',
    @autogen_sync_procs = N'false',
    @allow_queued_tran = N'false',
    @allow_dts = N'false',
    @replicate_ddl = 1,
    @allow_initialize_from_backup = N'false',
    @enabled_for_p2p = N'false',
    @enabled_for_het_sub = N'false';
GO

EXEC sp_addarticle @publication = N'pub_erp_system', @article = N'employees', @source_object = N'employees', @source_owner = N'dbo';
EXEC sp_addarticle @publication = N'pub_erp_system', @article = N'projects', @source_object = N'projects', @source_owner = N'dbo';
EXEC sp_addarticle @publication = N'pub_erp_system', @article = N'journal_entries', @source_object = N'journal_entries', @source_owner = N'dbo';
GO

-- =====================================================
-- Subscriber Configuration
-- sql2 subscriber for hotel_booking & e_commerce
-- sql3 subscriber for erp_system
-- =====================================================

-- Create linked server links for subscribers
EXEC sp_addlinkedserver @server = N'sql2', @srvproduct = N'SQL Server';
EXEC sp_addlinkedserver @server = N'sql3', @srvproduct = N'SQL Server';
GO

-- Add push subscriptions

-- Subscriber sql2 -> pub_hotel_booking
EXEC sp_addsubscription 
    @publication = N'pub_hotel_booking',
    @subscriber = N'sql2',
    @destination_db = N'hotel_booking',
    @subscription_type = N'push',
    @sync_type = N'automatic',
    @article = N'all',
    @update_mode = N'read only',
    @subscriber_type = 0;
GO

EXEC sp_addpushsubscription_agent 
    @publication = N'pub_hotel_booking',
    @subscriber = N'sql2',
    @subscriber_db = N'hotel_booking',
    @subscriber_security_mode = 1,
    @frequency_type = 64,
    @frequency_interval = 1,
    @frequency_relative_interval = 1,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 0,
    @frequency_subday_interval = 0,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 0,
    @active_end_date = 0,
    @enabled_for_syncmgr = N'false',
    @dts_package_location = N'Distributor';
GO

-- Subscriber sql2 -> pub_e_commerce
EXEC sp_addsubscription 
    @publication = N'pub_e_commerce',
    @subscriber = N'sql2',
    @destination_db = N'e_commerce',
    @subscription_type = N'push',
    @sync_type = N'automatic',
    @article = N'all',
    @update_mode = N'read only',
    @subscriber_type = 0;
GO

EXEC sp_addpushsubscription_agent 
    @publication = N'pub_e_commerce',
    @subscriber = N'sql2',
    @subscriber_db = N'e_commerce',
    @subscriber_security_mode = 1,
    @frequency_type = 64,
    @frequency_interval = 1,
    @frequency_relative_interval = 1,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 0,
    @frequency_subday_interval = 0,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 0,
    @active_end_date = 0,
    @enabled_for_syncmgr = N'false',
    @dts_package_location = N'Distributor';
GO

-- Subscriber sql3 -> pub_erp_system
EXEC sp_addsubscription 
    @publication = N'pub_erp_system',
    @subscriber = N'sql3',
    @destination_db = N'erp_system',
    @subscription_type = N'push',
    @sync_type = N'automatic',
    @article = N'all',
    @update_mode = N'read only',
    @subscriber_type = 0;
GO

EXEC sp_addpushsubscription_agent 
    @publication = N'pub_erp_system',
    @subscriber = N'sql3',
    @subscriber_db = N'erp_system',
    @subscriber_security_mode = 1,
    @frequency_type = 64,
    @frequency_interval = 1,
    @frequency_relative_interval = 1,
    @frequency_recurrence_factor = 0,
    @frequency_subday = 0,
    @frequency_subday_interval = 0,
    @active_start_time_of_day = 0,
    @active_end_time_of_day = 235959,
    @active_start_date = 0,
    @active_end_date = 0,
    @enabled_for_syncmgr = N'false',
    @dts_package_location = N'Distributor';
GO

-- Create distribution master key
USE distribution;
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'D1str1but0rK3y!';
GO

-- Add snapshot agents
USE hotel_booking;
EXEC sp_addpublication_snapshot @publication = N'pub_hotel_booking', @frequency_type = 4;
GO
USE e_commerce;
EXEC sp_addpublication_snapshot @publication = N'pub_e_commerce', @frequency_type = 4;
GO
USE erp_system;
EXEC sp_addpublication_snapshot @publication = N'pub_erp_system', @frequency_type = 4;
GO

-- Generate initial snapshots
USE hotel_booking;
EXEC sp_startpublication_snapshot @publication = N'pub_hotel_booking';
GO

PRINT 'Replication setup complete!';
GO
